# 使用 autossh 建立反向 ssh 隧道穿墙

```
sudo apt-get install autossh
nohup autossh -M 0 -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3"  -N -R 10000:localhost:22 aliyun > autossh.log 2>&1 &
```

将 aliyun 的 10000 端口映射到本地的 22 端口
