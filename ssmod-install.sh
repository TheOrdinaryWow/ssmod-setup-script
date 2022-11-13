#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)
conf="/usr/local/shadowsocks-mod/userapiconfig.py"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat tzdata python3-pip supervisor -y
        yun groupinstall "Development Tools" -y
    else
        apt install wget curl tar cron socat tzdata build-essential python3-pip supervisor -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

############## ;) Start ;) ##############

libsodium_installation(){
  if [[ ! -e /usr/local/lib/libsodium.a ]]; then
    wget https://github.com/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz
    if [[ ! -f libsodium-1.0.18.tar.gz ]]; then
      echo -e "${red}libsodium 下载失败，请查看日志进行debug！${plain}"
      exit 1
    fi
    tar xf libsodium-1.0.18.tar.gz && mv libsodium-1.0.18 /etc/libsodium && rm -f libsodium-1.0.18.tar.gz && cd /etc/libsodium
    ./configure && make && make install
    if [[ $? -ne 0 ]]; then 
      echo -e "${red}libsodium 安装失败，请查看日志进行debug！${plain}"
      exit 1
    fi
    echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
    ldconfig
    cd && rm -rf /etc/libsodium
  fi
}

ssmod_installation(){
  mkdir -p /usr/local/shadowsocks-mod
  
  cd /usr/local/shadowsocks-mod && git clone https://github.com/Anankke/shadowsocks-mod .
  cp apiconfig.py userapiconfig.py && cp config.json user-config.json
  
  if [[ ${release} == "centos" ]]; then
    ${release} install python-devel libffi-devel openssl-devel -y
  fi
  pip install --upgrade pip
  pip install requests
  pip install -r requirements.txt
}

supervisor_conf_modify_debian(){
  cat>/etc/supervisor/conf.d/shadowsocks-mod.conf<<EOF
[program:shadowsocks-mod]
command = python /usr/local/shadowsocks-mod/shadowsocks/server.py
stdout_logfile = /var/log/ssmu.log
stderr_logfile = /var/log/ssmu.log
user = root
autostart = true
autorestart = true
EOF
  supervisorctl update
}


supervisor_conf_modify_ubuntu(){
  cat>/etc/supervisor/conf.d/shadowsocks-mod.conf<<EOF
[program:shadowsocks-mod]
command = python /usr/local/shadowsocks-mod/shadowsocks/server.py
stdout_logfile = /var/log/ssmu.log
stderr_logfile = /var/log/ssmu.log
user = root
autostart = true
autorestart = true
EOF
  supervisorctl update
}

supervisor_conf_modify_centos(){
  cat>>/etc/supervisord.conf<<EOF
[program:shadowsocks-mod]
command = python /usr/local/shadowsocks-mod/shadowsocks/server.py
stdout_logfile = /var/log/ssmu.log
stderr_logfile = /var/log/ssmu.log
user = root
autostart = true
autorestart = true
EOF
 supervisorctl update
}

common_set(){
  echo -e "${green}请填写节点基本信息${plain}"
  echo -e ""
  stty erase '^H' && read -p "API_UPDATE_TIME(默认值为60，单位为秒):" API_UPDATE_TIME
  [[ -z ${API_UPDATE_TIME} ]] && API_UPDATE_TIME="60"
  stty erase '^H' && read -p "GET_PORT_OFFSET_BY_NODE_NAME(可选值 True 或 False，默认值: True):" GET_PORT_OFFSET_BY_NODE_NAME
  [[ -z ${GET_PORT_OFFSET_BY_NODE_NAME} ]] && GET_PORT_OFFSET_BY_NODE_NAME="True"
  
  stty erase '^H' && read -p "MU_SUFFIX(默认值: suf):" MU_SUFFIX
  [[ -z ${MU_SUFFIX} ]] && MU_SUFFIX="suf"
  stty erase '^H' && read -p "MU_REGEX(default:%5m%id.%suffix):" MU_REGEX
  [[ -z ${MU_REGEX} ]] && MU_REGEX="%5m%id.%suffix"  
}

modwebapi_set(){
  echo -e "${green}请填写对接基本信息${plain}"
  echo -e ""
  stty erase '^H' && read -p "NODE_ID(仅限数字):" NODE_ID
  stty erase '^H' && read -p "WEBAPI_URL(示范值: https://panel.819200.xyz):" WEBAPI_URL
  stty erase '^H' && read -p "WEBAPI_TOKEN(示范值: 819200.pwd):" WEBAPI_TOKEN
}

modify_NODE_ID(){
  sed -i '/NODE_ID/c \NODE_ID = '${NODE_ID}'' ${conf}
}
modify_API_UPDATE_TIME(){
  sed -i '/API_UPDATE_TIME/c \API_UPDATE_TIME = '${API_UPDATE_TIME}'' ${conf}
}
modify_PORT_OFFSET_TOGGLE(){
  sed -i '/GET_PORT_OFFSET_BY_NODE_NAME/c \GET_PORT_OFFSET_BY_NODE_NAME = '${GET_PORT_OFFSET_BY_NODE_NAME}'' ${conf}
}
modify_MU_SUFFIX(){
  sed -i '/MU_SUFFIX/c \MU_SUFFIX = '\'${MU_SUFFIX}\''' ${conf}
}
modify_MU_REGEX(){
  sed -i '/MU_REGEX/c \MU_REGEX = '\'${MU_REGEX}\''' ${conf}
}
modify_WEBAPI_URL(){
  sed -i '/WEBAPI_URL/c \WEBAPI_URL = '\'${WEBAPI_URL}\''' ${conf}
}
modify_WEBAPI_TOKEN(){
  sed -i '/WEBAPI_TOKEN/c \WEBAPI_TOKEN = '\'${WEBAPI_TOKEN}\''' ${conf}
}

modify_key(){
  modify_API_UPDATE_TIME
  modify_PORT_OFFSET_TOGGLE
  modify_MU_REGEX
  modify_MU_SUFFIX
  modify_WEBAPI_TOKEN
  modify_WEBAPI_URL
  modify_NODE_ID
}

kill_firewalls(){
  systemctl disable firewalld &>/dev/null
  systemctl disable iptables &>/dev/null
  chkconfig iptables off &>/dev/null
  iptables -F  &>/dev/null
  ufw --force disable
}

remove_old(){
  echo -e "${yellow}正在卸载 shadowsocks-mod"
  supervisorctl stop shadowsocks-mod
  if [[ ${release} == "centos" ]]; then
    sed -i '/shadowsocks-mod/,+6d' /etc/supervisord.conf
  else
    rm /etc/supervisor/conf.d/shadowsocks-mod.conf
  fi
  supervisorctl update
  rm /usr/local/shadowsocks-mod -rf
  echo -e "${yellow}shadowsocks-mod 卸载完成${plain}"
}

############## ;) End ;) ##############

install_ssmod() {
  if [[ -e /usr/local/shadowsocks-mod ]]; then
      echo -e "${yellow}shadowsocks-mod 已安装，继续运行脚本则会删除重新安装！${plain}"
    read -n 1 -s -r -p "按任意键以继续，退出请输入Ctrl+C…"
    echo -e "${plain}"
    remove_old
  fi
  
  if [[ ! -e /usr/local/lib/libsodium.a ]]; then
    libsodium_installation
  fi
  
  ssmod_installation
  
  common_set
  modwebapi_set
  
  modify_key
  
  supervisor_conf_modify_${release}
  
  while true; do
    echo -e "${yellow}按任意键以关闭防火墙进行测试…${plain}"
    if read -n 1 -s -r -t 5; then
        kill_firewalls
    fi
    break
  done
  
  echo -e "${green}shadowsocks-mod 安装完成，已设置开机自启${plain}"
}

echo -e "${green}开始安装${plain}"
install_base
install_ssmod
supervisorctl status | grep shadowsocks-mod