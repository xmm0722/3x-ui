#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 默认安装版本（fork版本）
DEFAULT_VERSION="v2.5.0"

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用 root 权限运行此脚本 \n " && exit 1

if ! ip addr show lo | grep -q '127.0.0.1'; then
    echo "127.0.0.1 not found, adding it to loopback interface..."
    ip addr add 127.0.0.1/8 dev lo
else
    echo "127.0.0.1 is already configured."
fi

# 检查操作系统
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "无法检查系统操作系统，请联系作者！" >&2
    exit 1
fi

echo "操作系统版本为: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}不支持的 CPU 架构！ ${plain}" && exit 1 ;;
    esac
}

echo "架构: $(arch)"

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}

config_after_install() {

    local server_ip=$(curl -s --max-time 5 https://api.ipify.org)

    local config_webBasePath=$(gen_random_string 12)
    local config_username=$(gen_random_string 8)
    local config_password=$(gen_random_string 10)
    local config_port=$(shuf -i 10000-60000 -n 1)

    /usr/local/x-ui/x-ui setting \
    -username "${config_username}" \
    -password "${config_password}" \
    -port "${config_port}" \
    -webBasePath "${config_webBasePath}"

    echo ""
    echo "###############################################"
    echo -e "${green}用户名: ${config_username}${plain}"
    echo -e "${green}密码: ${config_password}${plain}"
    echo -e "${green}端口: ${config_port}${plain}"
    echo -e "${green}路径: ${config_webBasePath}${plain}"
    echo -e "${green}访问地址: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
    echo "###############################################"

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {

    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$DEFAULT_VERSION
        echo -e "安装 fork 固定版本: ${tag_version}"
    else
        tag_version=$1
    fi

    url="https://github.com/xmm0722/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"

    echo -e "下载地址: ${url}"

    wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 x-ui 失败，请检查 release 是否存在 ${plain}"
        exit 1
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm -rf /usr/local/x-ui/
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm -f x-ui-linux-$(arch).tar.gz

    cd x-ui
    chmod +x x-ui
    chmod +x bin/xray-linux-*

    cp -f x-ui.service /etc/systemd/system/

    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/xmm0722/3x-ui/main/x-ui.sh
    chmod +x /usr/bin/x-ui

    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "${green}x-ui ${tag_version}${plain} 安装完成，正在运行..."
}

echo -e "${green}正在运行...${plain}"

install_base
install_x-ui $1
