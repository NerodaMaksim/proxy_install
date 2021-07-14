# proxy_install
Bash script for installation proxy
## temporary file

#!/bin/bash
current_dir=$(pwd)

typeset -A config
config=(
        [net]='localhost'
        [net_pr]='localhost'
        [max_conn]='1000'
        [username]='username'
        [password]='pass'
        [ipv4]='localhost'
        [uid]='0'
        [guid]='0'
        [subnet]='localhost'
        [getaway]='127.0.0.1'
)

while read line
do
    if echo $line | grep -F = &>/dev/null
    then
        varname=$(echo "$line" | cut -d '=' -f 1)
        config[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
done <  "/root/proxy_install/proxy_install.conf"


apt-get install build-essential
cd ~
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy/
make -f Makefile.Linux

for i in `cat "/root/proxy_install/ip.list"`; do
        ip -6 addr add $i dev eth0
done
ip -6 addr add ${config[subnet]} dev eth0
ip -6 route add default via ${config[getaway]}
ip -6 route add local ${config[net]} dev lo
