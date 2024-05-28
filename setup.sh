#!/bin/bash

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

wireguard_install(){
    version=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION="{print $2}')
    if [ $version == 18 ]; then
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
        sudo apt-get install -y openresolv
    #else
     #   sudo apt-get update -y
      #  sudo apt-get install -y software-properties-common
    fi
    sudo add-apt-repository -y ppa:wireguard/wireguard
    sudo apt-get update -y
    sudo apt-get install -y wireguard curl

    sudo echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p
    echo "1"> /proc/sys/net/ipv4/ip_forward
    
    mkdir /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net | awk '/^e/{print}')

sudo cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF


sudo cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

    sudo apt-get install -y qrencode

sudo cat > /etc/init.d/wgstart <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		wgstart
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	wgstart
### END INIT INFO
sudo wg-quick up wg0
EOF

    sudo chmod +x /etc/init.d/wgstart
    cd /etc/init.d
    if [ $version == 14 ]
    then
        sudo update-rc.d wgstart defaults 90
    else
        sudo update-rc.d wgstart defaults
    fi
    
    sudo wg-quick up wg0
    
    content=$(cat /etc/wireguard/client.conf)
    echo -e "\033[43;42m电脑端请下载/etc/wireguard/client.conf，手机端可直接使用软件扫码\033[0m"
    echo "${content}" | qrencode -o - -t UTF8
}

wireguard_remove(){

    sudo wg-quick down wg0
    sudo apt-get remove -y wireguard
    sudo rm -rf /etc/wireguard

}

add_user(){
    echo -e "\033[37;41m给新用户起个名字，不能和已有用户重复\033[0m"
    read -p "请输入用户名：" newname
    cd /etc/wireguard/
    cp client.conf $newname.conf
    wg genkey | tee temprikey | wg pubkey > tempubkey
    ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    newnum=$((10#${ipnum}+1))
    sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    sed -i 's%^Address.*$%'"Address = 10.0.0.$newnum\/24"'%' $newname.conf

cat >> /etc/wireguard/wg0.conf <<-EOF
[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.0.0.$newnum/32
EOF
    wg set wg0 peer $(cat tempubkey) allowed-ips 10.0.0.$newnum/32
    echo -e "\033[37;41m添加完成，文件：/etc/wireguard/$newname.conf\033[0m"
    rm -f temprikey tempubkey
}





change_port(){

post1=`/usr/bin/cat /etc/wireguard/wg0.conf | /usr/bin/grep ListenPort |/usr/bin/awk '{print $3}'`

random_number=$((1024 + $RANDOM % 54497)) 

/usr/bin/wg-quick down wg0
/usr/bin/sed -i "s/$post1/$random_number/g" /etc/wireguard/wg0.conf
/usr/bin/wg-quick up wg0

echo ++++++++++++++++++

echo $random_number

echo ++++++++++++++++++

}



web_change_port(){

sudo apt install  -y  nginx  php-fpm php-common php-xml php-mysql php-zip php-gd php-curl

phpver=`ls /etc/php`
echo $phpver

sed -i '56a location ~ \\.php$ {  \
      include snippets/fastcgi-php.conf;  \
     fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; \
     fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;  \
     include fastcgi_params; \
      }  \
'      /etc/nginx/sites-available/default

sudo systemctl restart nginx

sed -i "s/www-data/root/g" /etc/php/8.1/fpm/pool.d/www.conf

/etc/init.d/php-fpm8.1 stop   //关闭php-fpm  
  
nohup /usr/sbin/php-fpm8.1 -R >/dev/null 2>&1 &  
  
echo "nohup /usr/sbin/php-fpm8.1 -R >/dev/null 2>&1 &" >> /etc/rc.local  //加入开机启动


cat > /var/www/html/wg.sh <<-EOF
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

post1=`/usr/bin/cat /etc/wireguard/wg0.conf | /usr/bin/grep ListenPort |/usr/bin/awk '{print $3}'`



random_number=$((1024 + $RANDOM % 54497)) 

/usr/bin/wg-quick down wg0
/usr/bin/sed -i "s/$post1/$random_number/g" /etc/wireguard/wg0.conf
/usr/bin/wg-quick up wg0

echo ++++++++++++++++++

echo $random_number

echo ++++++++++++++++++
EOF

cat > /var/www/html/port.php <<-EOF
<?php
// 要执行的shell命令
 $command = 'bash wg.sh';
  
  // 执行shell命令并获取输出
  $output = shell_exec($command);
   
   // 输出命令结果
   echo "<pre>$output</pre>";
  ?>
EOF


chmod 777 /var/run/php/php8.1-fpm.sock

#开始菜单
start_menu(){
    clear
    echo -e "\033[43;42m ====================================\033[0m"
    echo -e "\033[43;42m 介绍：wireguard一键脚本              \033[0m"
    echo -e "\033[43;42m 系统：Ubuntu                        \033[0m"
    echo -e "\033[43;42m 作者：monov6                    \033[0m"
    echo -e "\033[43;42m ====================================\033[0m"
    echo
    echo -e "\033[0;33m 1. 安装wireguard\033[0m"
    echo -e "\033[0;33m 2. 查看客户端二维码\033[0m"
    echo -e "\033[0;31m 3. 删除wireguard\033[0m"
    echo -e "\033[0;33m 4. 增加用户\033[0m"
	echo -e "\033[0;33m 5. 更换端口\033[0m"
    echo -e "\033[0;33m 6. web刷新更换端口\033[0m"
    echo -e " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    wireguard_install
    ;;
    2)
    content=$(cat /etc/wireguard/client.conf)
    echo "${content}" | qrencode -o - -t UTF8
    ;;
    3)
    wireguard_remove
    ;;
    4)
    add_user
    ;;
	5)
    change_port
    ;;
	6)
    web_change_port
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    echo -e "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu





