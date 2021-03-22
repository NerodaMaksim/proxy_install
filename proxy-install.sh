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
done < $current_dir"/proxy_install.conf"


echo ${config[@]}

apt-get install build-essential


cd ~
git clone https://github.com/DanielAdolfsson/ndppd.git
cd ~/ndppd
make all && make install


#making ndppd.conf
touch $curret_dir"ndppd.conf"
while read LINE
do
	line_to_change=$(echo $LINE | grep -o '${net_}')
	if [[ $line_to_change != "" ]]
	then
		echo "rule ${config[net]} {" >> $current_dir"/ndppd.conf"
	else 
		echo "$LINE" >> $current_dir"/ndppd.conf"
	fi
done < $current_dir"/ndppd_templ.conf"
#end

ndppd -d -c $current_dir"/ndppd.conf"

cd ~
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy/
make -f Makefile.Linux

adduser --system --disabled-login --no-create-home --group proxy3

mkdir -p /var/log/3proxy
mkdir /etc/3proxy
cp ~/3proxy/bin/3proxy /usr/bin

chown proxy3:proxy3 -R /etc/3proxy
chown proxy3:proxy3 /usr/bin/3proxy
chown proxy3:proxy3 /var/log/3proxy

config[uid]=$(id proxy3 | grep -Po 'uid=[0-9]+' | grep -Po '[0-9]+')
config[guid]=$(id proxy3 | grep -Po 'uid=[0-9]+' | grep -Po '[0-9]+')


#making random_ip.sh
touch $current_dir"/random_ip.sh"
while read LINE; do
	line_to_change=$(echo $LINE | grep -o '{$net_pr}')
        if [[ $line_to_change != "" ]]
        then
                echo "network="${config[net_pr]} >> $current_dir"/random_ip.sh"
        else
                echo "$LINE" >> $current_dir"/random_ip.sh"
        fi
done < $current_dir"/random_ip_templ.sh"
#end

chmod +x $current_dir"/random_ip.sh"

$current_dir"/random_ip.sh" > $current_dir"/ip.list"

#mv ./3proxy.sh ./3proxy_teml.sh
#making 3proxy.sh
touch 3proxy.cfg
echo daemon >> 3proxy.cfg
echo log /var/log/3proxy/3proxy.log >> 3proxy.cfg
echo maxconn ${config[max_conn]}  >> 3proxy.cfg
echo nserver 8.8.8.8 >> 3proxy.cfg
echo nserver 8.8.4.4 >> 3proxy.cfg
echo nserver 1.1.1.1 >> 3proxy.cfg
echo nscache6 65536 >> 3proxy.cfg
echo timeouts 1 5 30 60 180 1800 15 60 >> 3proxy.cfg
echo setgid ${config[guid]} >> 3proxy.cfg
echo setuid ${config[uid]} >> 3proxy.cfg
echo stacksize 6000 >> 3proxy.cfg
echo flush >> 3proxy.cfg
echo auth strong >> 3proxy.cfg
echo users ${config[username]}:CL:${config[password]} >> 3proxy.cfg
echo allow ${config[username]} >> 3proxy.cfg

port=30000
count=1
for i in `cat $current_dir"/ip.list"`; do
    echo "proxy -6 -s0 -n -a -p$port -i${config[ipv4]} -e$i" >> 3proxy.cfg
    ((port+=1))
    ((count+=1))
    if [ $count -eq 10001 ]; then
        exit
    fi
done

#end


cp 3proxy.cfg /etc/3proxy/3proxy.cfg

#editing /etc/sysctl.conf
echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
#end

sysctl -p



ip -6 addr add ${config[subnet]} dev eth0
ip -6 route add default via ${config[getaway]}
ip -6 route add local ${config[net_pref]}"::/32" dev lo

#creating service in /etc/systemd/system/3proxy.service
cp $current_dir"/3proxy.service" /etc/systemd/system
#end

systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy
