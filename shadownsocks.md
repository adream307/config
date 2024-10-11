# ubuntu 22.04
```
apt-get install shadowsocks-libev
```

/etc/shadowsocks-libev/config.json
```json
{
    "server":["172.16.191.18"],
    "mode":"tcp_and_udp",
    "server_port":8388,
    "local_port":1080,
    "password":"@fuck2023",
    "timeout":86400,
    "method":"aes-256-gcm"
}
```

ssloca.sh
```bash
#!/bin/bash
ss-local -s 47.243.107.19 -p 8388 -l 1080 -k @fuck2023 -m aes-256-gcm
```
