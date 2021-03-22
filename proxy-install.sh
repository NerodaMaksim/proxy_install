#!/bin/bash

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
done < proxy_install.conf


#echo ${config[@]}

apt-get install build-essential


cd ~
git clone https://github.com/DanielAdolfsson/ndppd.git
cd ~/ndppd
make all && make install


#making ndppd.conf
touch ndppd.conf
while read LINE;
do;
	line_to_change=$(echo $LINE | grep -o '${net_}')
	if [[ $line_to_change != "" ]]
	then
		echo "rule ${config[net]} {" >> ndppd.conf
	else 
		echo "$LINE" >> ndppd.conf
	fi
done < ./ndppd_templ.conf
#end

ndppd -d -c /root/ndppd/ndppd.conf

cd ~
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy/
make -f Makefile.Linux

adduser --system --disabled-login --no-create-home --group proxy3

mkdir -p /var/log/3proxy
mkdir /etc/3proxy
cp ~/3proxy/bin/3proxy

chown proxy3:proxy3 -R /etc/3proxy
chown chown proxy3:proxy3 /usr/bin/3proxy
chown proxy3:proxy3 /var/log/3proxy

config[uid]=((id max | grep -Po 'uid=[0-9]+' | grep -Po '[0-9]+'))
config[guid]=((id max | grep -Po 'uid=[0-9]+' | grep -Po '[0-9]+'))

wget https://blog.vpsville.ru/uploads/random-ipv6_64-address-generator.sh

#making random_ip.sh
touch random_ip.sh
while read LINE; do
	line_to_change=$(echo $LINE | grep -o '${net_pr}')
        if [[ $line_to_change != "" ]]
        then
                echo "network=${config[net_pr]}" >> random_ip.sh
        else
                echo "$LINE" >> random_ip.sh
        fi
done < ./random_ip_templ.sh
#end

chmod +x random_ip.sh

./random_ip.sh > ip.list

mv ./3proxy.sh ./3proxy_teml.sh
#making 3proxy.sh
touch 3proxy.sh
echo daemon >> 3proxy.sh
echo log /var/log/3proxy/3proxy.log >> 3proxy.sh
echo maxconn ${config[max_conn]}  >> 3proxy.sh
echo nserver 8.8.8.8 >> 3proxy.sh
echo 8.8.4.4 >> 3proxy.sh
echo 1.1.1.1 >> 3proxy.sh
echo nscache 65536 >> 3proxy.sh
echo timeouts 1 5 30 60 180 1800 15 60 >> 3proxy.sh
echo setgid ${config[guid]} >> 3proxy.sh
echo setuid ${config[uid]} >> 3proxy.sh
echo stacksize 6000 >> 3proxy.sh
echo flush >> 3proxy.sh
echo auth strong >> 3proxy.sh
echo users ${config[username]}:CL:${config[password]} >> 3proxy.sh
echo allow ${config[username]} >> 3proxy.sh

port=30000
count=1
for i in `cat ip.list`; do
    echo "proxy -n -s0 -a  -6 -p$port -i${config[ipv4]} -e$i" >> 3proxy.sh
    ((port+=1))
    ((count+=1))
    if [ $count -eq 10001 ]; then
        exit
    fi
done

#end

chmod +x 3proxy.sh
./3proxy.sh > 3proxy.cfg

#editing /etc/sysctl.conf
echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
#end

sysctl -p

$this_net = $(sed -e '$net' '::')

ip -6 addr add ${config[subnet]} dev eth0
ip -6 route add default ${config[getaway]}
ip -6 route add local $this_net dev lo

#creating service in /etc/systemd/system/3proxy.service
cp ./3proxy.service /etc/systemd/system
#end

systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

