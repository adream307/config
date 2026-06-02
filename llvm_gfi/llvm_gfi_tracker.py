#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
llvm_gfi_tracker.py —— 抓取 LLVM 仓库中「good first issue」且与后端相关、无人认领的 issue。

判定规则
--------
- 标签含 "good first issue"
- 标签里至少有一个以 "backend:" 开头（LLVM 用 backend:RISC-V / backend:AArch64 ... 标记后端）
  可用 --backend RISC-V 只看某个后端。
- 无人认领：GitHub assignee 为空（assignee=none）。
  注意：LLVM 很多认领是用评论 "/assign-me" 或留言完成的，未必体现在 assignee 字段。
  开 --check-claims 会额外读取评论，命中常见认领话术的会被剔除（更准但更耗 API 配额）。

增量存储
--------
- 状态文件（JSON）记录「上一次运行」命中的 issue 集合。
- 每次运行抓取当前命中集合，与上一次比较，把「新增」的 issue 追加写入文本输出文件。
- 然后用当前集合覆盖状态文件，作为下次比较基准。

用法
----
  python3 llvm_gfi_tracker.py                # 用默认设置跑一次
  python3 llvm_gfi_tracker.py --backend RISC-V
  GITHUB_TOKEN=xxxx python3 llvm_gfi_tracker.py   # 带 token，配额从 60/h 提到 5000/h

零第三方依赖，只用 Python 标准库。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

API_ROOT = "https://api.github.com"
DEFAULT_REPO = "llvm/llvm-project"
GFI_LABEL = "good first issue"
BACKEND_PREFIX = "backend:"

# 评论里常见的「我来认领」话术，用于 --check-claims
CLAIM_PATTERNS = [
    r"/assign\b",
    r"\bassign me\b",
    r"\bi('|’)?d like to (work|take)\b",
    r"\bi (will|'ll|am going to|wanna|want to) (work|take)\b",
    r"\bi can (take|work)\b",
    r"\bworking on (this|it)\b",
    r"\btaking this\b",
    r"\bcan i (work|take|be assigned)\b",
]
CLAIM_RE = re.compile("|".join(CLAIM_PATTERNS), re.IGNORECASE)


def http_get(url: str, token: str | None) -> tuple[bytes, dict]:
    """发一个 GET 请求，返回 (body, headers)。处理 403 限流。"""
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "llvm-gfi-tracker",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(), dict(resp.headers)
    except urllib.error.HTTPError as e:
        if e.code == 403 and e.headers.get("X-RateLimit-Remaining") == "0":
            reset = e.headers.get("X-RateLimit-Reset")
            hint = ""
            if reset:
                when = datetime.fromtimestamp(int(reset)).strftime("%H:%M:%S")
                hint = f"，配额将在 {when} 重置"
            sys.exit(f"[错误] GitHub API 限流{hint}。设置 GITHUB_TOKEN 环境变量可大幅提高配额。")
        body = e.read().decode("utf-8", "replace")
        sys.exit(f"[错误] HTTP {e.code} 请求 {url}\n{body}")
    except urllib.error.URLError as e:
        sys.exit(f"[错误] 网络请求失败: {e.reason}")


def parse_next_link(link_header: str | None) -> str | None:
    """从 Link 响应头里解析 rel=\"next\" 的 URL，用于翻页。"""
    if not link_header:
        return None
    for part in link_header.split(","):
        segs = part.split(";")
        if len(segs) < 2:
            continue
        url = segs[0].strip().lstrip("<").rstrip(">")
        for seg in segs[1:]:
            if seg.strip() == 'rel="next"':
                return url
    return None


def fetch_open_issues(repo: str, token: str | None) -> list[dict]:
    """拉取该仓库所有 open、带 good first issue 标签、无 assignee 的 issue（自动翻页）。"""
    params = {
        "labels": GFI_LABEL,
        "state": "open",
        "assignee": "none",      # 只要没有 assignee 的
        "per_page": "100",
        "sort": "created",
        "direction": "desc",
    }
    url = f"{API_ROOT}/repos/{repo}/issues?" + urllib.parse.urlencode(params)

    issues: list[dict] = []
    page = 0
    while url:
        page += 1
        body, headers = http_get(url, token)
        batch = json.loads(body)
        # /issues 端点会把 PR 也算作 issue，过滤掉
        issues.extend(it for it in batch if "pull_request" not in it)
        url = parse_next_link(headers.get("Link"))
        if url:
            time.sleep(0.3)  # 翻页之间轻微限速，对 API 友好
    return issues


def backend_labels(issue: dict) -> list[str]:
    return [
        lb["name"]
        for lb in issue.get("labels", [])
        if lb.get("name", "").lower().startswith(BACKEND_PREFIX)
    ]


def has_claim_in_comments(issue: dict, repo: str, token: str | None) -> bool:
    """读取评论，判断是否已有人以留言方式认领。"""
    if issue.get("comments", 0) == 0:
        return False
    url = issue["comments_url"] + "?per_page=100"
    while url:
        body, headers = http_get(url, token)
        for c in json.loads(body):
            if CLAIM_RE.search(c.get("body", "") or ""):
                return True
        url = parse_next_link(headers.get("Link"))
        if url:
            time.sleep(0.2)
    return False


def select_issues(repo: str, token: str | None, backend: str | None,
                  check_claims: bool) -> dict[str, dict]:
    """返回 {issue_number(str): 精简记录} 的命中集合。"""
    result: dict[str, dict] = {}
    want = (BACKEND_PREFIX + backend).lower() if backend else None

    for it in fetch_open_issues(repo, token):
        blabels = backend_labels(it)
        if not blabels:
            continue
        if want and not any(lb.lower() == want for lb in blabels):
            continue
        if check_claims and has_claim_in_comments(it, repo, token):
            continue
        num = str(it["number"])
        result[num] = {
            "number": it["number"],
            "title": it["title"],
            "url": it["html_url"],
            "backend": blabels,
            "labels": [lb["name"] for lb in it.get("labels", [])],
            "created_at": it.get("created_at", ""),
        }
    return result


def load_previous(state_file: str) -> dict[str, dict]:
    if not os.path.exists(state_file):
        return {}
    try:
        with open(state_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("issues", {})
    except (json.JSONDecodeError, OSError) as e:
        print(f"[警告] 读取状态文件失败，按首次运行处理: {e}", file=sys.stderr)
        return {}


def save_state(state_file: str, issues: dict[str, dict]) -> None:
    tmp = state_file + ".tmp"
    payload = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "count": len(issues),
        "issues": issues,
    }
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp, state_file)  # 原子替换，避免写一半损坏


def append_new_issues(output_file: str, new_issues: list[dict]) -> None:
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "=" * 72,
        f"运行时间: {stamp}    新增命中: {len(new_issues)} 个",
        "=" * 72,
    ]
    for it in sorted(new_issues, key=lambda x: x["number"]):
        lines.append(f"#{it['number']}  {it['title']}")
        lines.append(f"    链接  : {it['url']}")
        lines.append(f"    后端  : {', '.join(it['backend'])}")
        lines.append(f"    标签  : {', '.join(it['labels'])}")
        lines.append(f"    创建于: {it['created_at']}")
        lines.append("")
    lines.append("")
    with open(output_file, "a", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main() -> int:
    ap = argparse.ArgumentParser(
        description="增量抓取 LLVM 仓库中后端相关、无人认领的 good first issue。")
    ap.add_argument("--repo", default=DEFAULT_REPO, help=f"目标仓库，默认 {DEFAULT_REPO}")
    ap.add_argument("--backend", default=None,
                    help="只看某个后端，如 RISC-V / AArch64 / X86（对应 backend:<name> 标签）")
    ap.add_argument("--data-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                       "llvm_gfi_data"),
                    help="状态文件与输出文件存放目录")
    ap.add_argument("--state-file", default=None, help="状态文件路径（默认在 data-dir 内）")
    ap.add_argument("--output-file", default=None, help="新增 issue 的文本输出路径（默认在 data-dir 内）")
    ap.add_argument("--check-claims", action="store_true",
                    help="额外读取评论剔除已被留言认领的（更准，但更费 API 配额）")
    ap.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"),
                    help="GitHub token；也可用环境变量 GITHUB_TOKEN")
    args = ap.parse_args()

    os.makedirs(args.data_dir, exist_ok=True)
    suffix = f"_{args.backend}" if args.backend else ""
    state_file = args.state_file or os.path.join(args.data_dir, f"state{suffix}.json")
    output_file = args.output_file or os.path.join(args.data_dir, f"new_issues{suffix}.txt")

    scope = f"后端={args.backend}" if args.backend else "所有后端"
    print(f"抓取 {args.repo} 的 good first issue（{scope}，无人认领）...")
    current = select_issues(args.repo, args.token, args.backend, args.check_claims)
    print(f"本次命中 {len(current)} 个。")

    previous = load_previous(state_file)
    new_keys = sorted(set(current) - set(previous), key=int)
    new_issues = [current[k] for k in new_keys]

    if not os.path.exists(state_file):
        print(f"首次运行：把当前 {len(current)} 个全部记为新增。")
    if new_issues:
        append_new_issues(output_file, new_issues)
        print(f"发现 {len(new_issues)} 个新增，已追加到: {output_file}")
        for it in new_issues:
            print(f"  + #{it['number']} [{', '.join(it['backend'])}] {it['title']}")
    else:
        print("与上次相比没有新增。")

    save_state(state_file, current)
    print(f"状态已更新: {state_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
