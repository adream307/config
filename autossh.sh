#!/bin/bash
nohup autossh -M 0 -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3"  -N -R 10000:localhost:22 aliyun > autossh.log 2>&1 &
