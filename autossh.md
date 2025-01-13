# 使用 autossh 建立反向 ssh 隧道穿墙

```
sudo apt-get install autossh
autossh -M 0 -N -R 10000:localhost:22 aliyun
```

将 aliyun 的 10000 端口映射到本地的 22 端口
