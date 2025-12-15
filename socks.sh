#!/bin/bash
nohup autossh -M 0 -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3"  -N -D 1080 proxy-host > socks.log 2>&1 &
