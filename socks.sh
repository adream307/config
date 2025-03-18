#!/bin/bash
nohup autossh -M 0 -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3"  -N -D 1080 huawei-cloud > socks.log 2>&1 &
