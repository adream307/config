#!/bin/bash
#hk
nohup ss-local -s <remote-ip> -p 8388 -l 1080 -k <password> -m aes-256-gcm > sslocal.log 2>&1 &
