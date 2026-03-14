#!/usr/bin/env bash

set -e

REPO="xmm0722/3x-ui"
VERSION="v2.5.0"
INSTALL_DIR="/usr/local/x-ui"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

echo -e "${green}3x-ui Installer (fork version)${plain}"
echo -e "Repo: ${REPO}"
echo -e "Version: ${VERSION}"
echo ""

# root check
if [[ $EUID -ne 0 ]]; then
 echo -e "${red}请使用 root 运行脚本${plain}"
 exit 1
fi

# detect architecture
detect_arch() {
 case "$(uname -m)" in
 x86_64) echo amd64 ;;
 aarch64) echo arm64 ;;
 armv7l) echo armv7 ;;
 armv6l) echo armv6 ;;
 *) 
  echo -e "${red}不支持的CPU架构: $(uname -m)${plain}"
  exit 1
 ;;
 esac
}

ARCH=$(detect_arch)
echo "检测到架构: $ARCH"

# detect OS
if [ -f /etc/os-release ]; then
 . /etc/os-release
 OS=$ID
else
 echo -e "${red}无法识别操作系统${plain}"
 exit 1
fi

echo "检测到系统: $OS"

install_base() {

 case "$OS" in
 ubuntu|debian)
  apt update
  apt install -y wget curl tar tzdata
 ;;
 centos|rocky|almalinux)
  yum install -y wget curl tar tzdata
 ;;
 fedora)
  dnf install -y wget curl tar tzdata
 ;;
 arch|manjaro)
  pacman -Syu --noconfirm wget curl tar tzdata
 ;;
 *)
  echo -e "${yellow}未知系统，尝试使用 apt${plain}"
  apt update
  apt install -y wget curl tar tzdata
 ;;
 esac

}

download_xui() {

FILE="x-ui-linux-${ARCH}.tar.gz"

URL1="https://github.com/${REPO}/releases/download/${VERSION}/${FILE}"
URL2="https://ghproxy.com/${URL1}"

echo "开始下载..."

if wget -O ${FILE} ${URL1}; then
 echo -e "${green}GitHub 下载成功${plain}"
else
 echo -e "${yellow}GitHub 下载失败，尝试加速镜像...${plain}"
 wget -O ${FILE} ${URL2}
fi

if [ ! -f ${FILE} ]; then
 echo -e "${red}下载失败${plain}"
 exit 1
fi

}

install_xui() {

cd /usr/local

if [ -d "$INSTALL_DIR" ]; then
 systemctl stop x-ui || true
 rm -rf $INSTALL_DIR
fi

tar zxvf x-ui-linux-${ARCH}.tar.gz
rm -f x-ui-linux-${ARCH}.tar.gz

cd x-ui

chmod +x x-ui
chmod +x bin/xray-linux-*

cp x-ui.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui

}

random_string() {
 tr -dc A-Za-z0-9 </dev/urandom | head -c $1
}

config_panel() {

USERNAME=$(random_string 8)
PASSWORD=$(random_string 12)
PORT=$(shuf -i 10000-60000 -n 1)
PATH_RANDOM=$(random_string 12)

$INSTALL_DIR/x-ui setting \
-username $USERNAME \
-password $PASSWORD \
-port $PORT \
-webBasePath $PATH_RANDOM

IP=$(curl -s --max-time 5 https://api.ipify.org || echo "SERVER_IP")

echo ""
echo "================================"
echo -e "${green}3x-ui 安装完成${plain}"
echo ""
echo "访问地址:"
echo "http://${IP}:${PORT}/${PATH_RANDOM}"
echo ""
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo "================================"

}

install_base
download_xui
install_xui
config_panel
