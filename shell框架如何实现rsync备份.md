# shell 框架如何实现 rsync 备份

作者：花宝宝
链接：https://www.zhihu.com/question/584036866/answer/1986395724724867287
来源：知乎
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。


Rsync这工具，我用了快五年了。最开始是公司服务器之间同步代码，后来家里NAS备份也用上了，再后来搞异地容灾，还是它。说实话，Linux下文件同步的工具不少，但Rsync真的是最稳的那个。增量传输、断点续传、压缩传输，该有的功能都有，而且几乎每个Linux系统都自带。这篇记录一下我这些年用Rsync的经验，从基础用法到异地容灾，希望能帮到有同样需求的朋友。


## 为什么选Rsync
我试过的其他方案

|工具|优点|缺点|为什么不用了|
|-----|-----|-------|-----|
| scp | 简单 | 每次都全量传输，慢 | 数据量大就废了|
| ftp | 图形界面友好| 不安全，不支持增量| 早就淘汰了|
| rclone | 支持云存储 | 对本地同步不够灵活| 云存储场景用|
| 各种GUI工具| 操作简单 | 不稳定，容易断 | 命令行更可靠|

__Rsync的优势：__
- 增量传输：只传变化的部分，大文件也能秒同步
- 断点续传：网络断了能接着传，不用从头来
- 保持属性：权限、时间戳、软链接都能保留
- 几乎零配置：系统自带，装完就能用


## 二、基础用法（这些我天天用）

### 本地同步
最常用的命令：
```bash
rsync -avP --delete /source/ /backup/
```
参数说明：
- -a：归档模式，保持所有属性（权限、时间、软链接等）
- -v：显示详细信息，能看到哪些文件在同步
- -P：显示进度 + 断点续传
- --delete：删除目标目录里多余的文件（让两边完全一致

### 注意末尾斜杠的区别：
```bash
# 有斜杠：同步source目录下的内容到target
rsync -av /source/ /target/
# 结果：/target/file1, /target/file2

# 无斜杠：同步source目录本身到target
rsync -av /source /target/
# 结果：/target/source/file1, /target/source/file2
```
这个坑我踩过好几次，现在每次都检查斜杠。

### 排除文件
有些文件不需要同步，比如日志、缓存：
```bash
rsync -avP \
  --exclude='*.log' \
  --exclude='cache/' \
  --exclude='node_modules/' \
  /source/ /backup/
```  
文件多了可以写到文件里：
```bash
# exclude.txt
*.log
*.tmp
cache/
node_modules/
.DS_Store

# 使用
rsync -avP --exclude-from='exclude.txt' /source/ /backup/
```
### 试运行
不确定命令对不对，先试运行看看：
```bash
rsync -avPn /source/ /backup/
```
`-n` 参数表示`dry-run`，只显示会做什么，不实际执行。


## 三、远程同步（SSH方式）

### 基本用法
```bash
# 推送到远程
rsync -avPz -e ssh /local/data/ user@remote:/remote/backup/

# 从远程拉取
rsync -avPz -e ssh user@remote:/remote/data/ /local/backup/
```
`-z` 是压缩传输，能省带宽，但会消耗CPU。内网可以不加，外网建议加上。

### SSH密钥配置
每次都输密码太麻烦，配置密钥免密登录：
```bash
# 生成密钥（如果还没有）
ssh-keygen -t ed25519 -f ~/.ssh/backup_key -N ""

# 复制公钥到远程服务器
ssh-copy-id -i ~/.ssh/backup_key.pub user@remote

# 测试
ssh -i ~/.ssh/backup_key user@remote "echo OK"
```
配置好后，rsync就能自动用密钥了：
```bash
rsync -avPz -e "ssh -i ~/.ssh/backup_key" /local/ user@remote:/backup/
```

### 指定SSH端口
如果远程SSH不是默认22端口：
```bash
rsync -avPz -e "ssh -p 22022" /local/ user@remote:/backup/
```

## 四、自动化备份脚本
### 基础备份脚本

我写了个简单的脚本，每天凌晨自动备份：
```bash
#!/bin/bash
# backup.sh

SOURCE="/data/important/"
DEST="/backup/daily/"
LOG="/var/log/backup.log"
DATE=$(date +%Y-%m-%d_%H%M)

mkdir -p "$DEST"

echo "[$DATE] 开始备份" >> "$LOG"

rsync -avP --delete \
  --exclude='*.tmp' \
  --exclude='cache/' \
  "$SOURCE" "$DEST" >> "$LOG" 2>&1

if [ $? -eq 0 ]; then
  echo "[$DATE] 备份成功" >> "$LOG"
else
  echo "[$DATE] 备份失败" >> "$LOG"
  # 这里可以加告警通知
fi
```

### 增量备份（硬链接）
如果每天全量备份，磁盘很快就满了。用硬链接做增量备份：
```bash
#!/bin/bash
# incremental_backup.sh

SOURCE="/data/important/"
BACKUP_BASE="/backup"
DATE=$(date +%Y-%m-%d)
LATEST="$BACKUP_BASE/latest"
DEST="$BACKUP_BASE/$DATE"

# 如果有上次备份，用硬链接（节省空间）
if [ -d "$LATEST" ]; then
  rsync -avP --delete \
    --link-dest="$LATEST" \
    "$SOURCE" "$DEST"
else
  rsync -avP --delete \
    "$SOURCE" "$DEST"
fi

# 更新latest链接
rm -f "$LATEST"
ln -s "$DEST" "$LATEST"

# 删除7天前的备份
find "$BACKUP_BASE" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
```
`--link-dest` 参数会让`rsync`对未变化的文件创建硬链接，而不是复制。这样多个备份版本占用的空间很小。

### 定时任务
```bash
crontab -e

# 每天凌晨2点备份
0 2 * * * /opt/scripts/backup.sh

# 每小时增量备份
0 * * * * /opt/scripts/incremental_backup.sh
```

## 五、远程备份
远程备份脚本
```bash
#!/bin/bash
# remote_backup.sh

SOURCE="/data/important/"
REMOTE_HOST="backup@192.168.1.200"
REMOTE_PATH="/backup/server1/"
SSH_KEY="/root/.ssh/backup_key"
LOG="/var/log/remote_backup.log"
DATE=$(date +%Y-%m-%d_%H%M)

echo "[$DATE] 开始远程备份" >> "$LOG"

rsync -avPz --delete \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$SOURCE" "$REMOTE_HOST:$REMOTE_PATH" >> "$LOG" 2>&1

if [ $? -eq 0 ]; then
  echo "[$DATE] 远程备份成功" >> "$LOG"
else
  echo "[$DATE] 远程备份失败" >> "$LOG"
  # 发送告警
fi
```

## 六、异地容灾方案
### 需求场景
公司在北京，灾备站点在上海。需要每天把关键数据同步过去。

### 网络打通
传统方案需要：
- 两地都有公网IP
- 配置VPN或专线
- 复杂的网络配置

我用的是`星空组网`工具，把两地服务器组到一个虚拟局域网。配置好后，北京服务器是 `10.26.0.1`，上海服务器是 `10.26.0.2`，直接用内网IP就能访问。

### 异地备份脚本
```bash
#!/bin/bash
# disaster_recovery_backup.sh

LOCAL_DATA="/data"
REMOTE_HOST="root@10.26.0.2"  # 异地服务器虚拟IP
REMOTE_PATH="/backup/beijing"
SSH_KEY="/root/.ssh/dr_key"
BANDWIDTH="5000"  # 限速5MB/s，避免影响业务
LOG="/var/log/dr_backup.log"

# 要备份的目录
BACKUP_DIRS=(
  "/data/mysql"
  "/data/uploads"
  "/etc/nginx"
  "/opt/app/config"
)

echo "[$(date)] 开始异地备份" >> "$LOG"

for dir in "${BACKUP_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    target="$REMOTE_PATH$(dirname $dir)"
    echo "备份 $dir -> $target" >> "$LOG"
    
    rsync -avPz --delete \
      --bwlimit="$BANDWIDTH" \
      -e "ssh -i $SSH_KEY" \
      "$dir" "$REMOTE_HOST:$target/" >> "$LOG" 2>&1
  fi
done

echo "[$(date)] 异地备份完成" >> "$LOG"
```
`--bwlimit` 限速很重要，不然会把带宽占满，影响正常业务。

## 七、数据库备份同步
### MySQL备份同步
```bash
#!/bin/bash
# mysql_backup_sync.sh

MYSQL_HOST="localhost"
MYSQL_USER="backup"
MYSQL_PASS="password"
BACKUP_DIR="/backup/mysql"
REMOTE_HOST="root@10.26.0.2"
REMOTE_PATH="/backup/mysql"

DATE=$(date +%Y-%m-%d)
DUMP_FILE="$BACKUP_DIR/all-databases-$DATE.sql.gz"

mkdir -p "$BACKUP_DIR"

# 导出数据库
mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" \
  --all-databases --single-transaction --routines --triggers \
  | gzip > "$DUMP_FILE"

# 同步到远程
rsync -avPz "$DUMP_FILE" "$REMOTE_HOST:$REMOTE_PATH/"

# 清理7天前的本地备份
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
```
### PostgreSQL备份同步
```bash
#!/bin/bash
# pg_backup_sync.sh

PGHOST="localhost"
PGUSER="postgres"
BACKUP_DIR="/backup/postgres"
DATE=$(date +%Y-%m-%d)

# 导出所有数据库
pg_dumpall -h "$PGHOST" -U "$PGUSER" | gzip > "$BACKUP_DIR/all-$DATE.sql.gz"

# 同步到远程
rsync -avPz "$BACKUP_DIR/" "root@10.26.0.2:/backup/postgres/"
```


## 八、监控与告警

### 备份状态检查
写个脚本检查备份是否正常：
```bash
#!/bin/bash
# check_backup.sh

BACKUP_DIR="/backup/daily"
MAX_AGE_HOURS=25

# 检查最新备份时间
latest=$(find "$BACKUP_DIR" -type f -mmin -$((MAX_AGE_HOURS * 60)) | head -1)

if [ -z "$latest" ]; then
  echo "警告：备份超过${MAX_AGE_HOURS}小时未更新"
  # 发送告警通知
fi
```
### 备份大小监控
```bash
#!/bin/bash
# monitor_backup_size.sh

BACKUP_DIR="/backup"
THRESHOLD_GB=100
CURRENT_GB=$(du -s "$BACKUP_DIR" | awk '{print int($1/1024/1024)}')

if [ "$CURRENT_GB" -gt "$THRESHOLD_GB" ]; then
  echo "备份目录已使用 ${CURRENT_GB}GB，超过阈值 ${THRESHOLD_GB}GB"
fi
```

## 九、踩过的坑
### 1. 权限问题
保持权限同步需要root或sudo：
```bash
sudo rsync -avP /source/ /target/
```
远程同步时也要用root：
```bash
rsync -avP -e "ssh" /source/ root@remote:/target/
```
### 2. 大文件同步
大文件同步到一半断了，用 `--partial` 支持断点续传：
```bash
rsync -avP --partial /source/bigfile.iso remote:/target/
```
### 3. 网络不稳定
网络不稳定的时候，设置超时和自动重试：
```bash
rsync -avPz --timeout=300 /source/ remote:/target/
```
或者写个循环自动重试：
```bash
while ! rsync -avPz /source/ remote:/target/; do
  echo "同步失败，5分钟后重试"
  sleep 300
done
```

## 十、总结
Rsync真的是文件同步的瑞士军刀，用了这么多年，从来没让我失望过。

### 常用命令总结：
|场景|命令|
|----|----|
|本地备份|rsync -avP --delete /source/ /backup/|
|远程推送|rsync -avPz -e ssh /local/ user@remote:/backup/|
|远程拉取|rsync -avPz -e ssh user@remote:/data/ /local/|
|增量备份|rsync -avP --link-dest=/prev /source/ /backup/$DATE/|
|限速同步|rsync -avPz --bwlimit=1000 /source/ /target/|

### 建议：
- 用SSH密钥免密登录
- 设置定时任务自动执行
- 配置限速避免影响业务
- 定期验证备份可恢复


