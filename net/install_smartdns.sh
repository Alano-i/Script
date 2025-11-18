#!/bin/bash
set -e

# 用户选择提示
echo "============================="
echo "  SmartDNS 安装配置选择"
echo "============================="
echo "请选择要安装的配置版本："
echo "1) SmartDNS A 配置"
echo "2) SmartDNS B 配置"
echo "============================="
read -p "请输入选项 (1 或 2): " choice

case $choice in
    1)
        echo "您选择了 SmartDNS A 配置"
        SMARTDNS_URL="https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/smartdnsA.conf"
        SMARTDNS_VERSION="SmartDNS A"
        ;;
    2)
        echo "您选择了 SmartDNS B 配置"
        SMARTDNS_URL="https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/smartdnsB.conf"
        SMARTDNS_VERSION="SmartDNS B"
        ;;
    *)
        echo "ERROR: 无效的选项，请输入 1 或 2"
        exit 1
        ;;
esac

echo

# 安装 smartdns
echo "1/2 安装 SmartDNS..."
##########################
# 默认 GitHub 仓库
REPO="pymumu/smartdns"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# 获取系统架构
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) ARCH_TAG="x86_64-linux-all" ;;
  aarch64|arm64) ARCH_TAG="arm64-linux-all" ;;
  armv7l|armv7) ARCH_TAG="arm-linux-all" ;;
  i386|i686) ARCH_TAG="i386-linux-all" ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

echo "Detected architecture: ${ARCH} => tag part: ${ARCH_TAG}"

# 获取最新版本信息
echo "Fetching latest release info from GitHub..."
JSON=$(curl -sSL "${API_URL}")

LATEST_TAG=$(echo "$JSON" | grep -oP '"tag_name":\s*"\K(.*?)(?=")')
if [ -z "$LATEST_TAG" ]; then
  echo "Failed to get latest tag from GitHub API"; exit 1
fi
echo "Latest version tag: ${LATEST_TAG}"

# 从 assets 列表中获取对应架构的 tar.gz 包名
# 例如： smartdns.1.2025.11.09-1443.x86_64-linux-all.tar.gz
FILE_NAME=$(echo "$JSON" | grep -oP '"name":\s*"\Ksmartdns\.[^"]*'"${ARCH_TAG}"'\.tar\.gz(?=")')
if [ -z "$FILE_NAME" ]; then
  echo "Failed to find asset for architecture tag ${ARCH_TAG}"; exit 1
fi
echo "Selected file: ${FILE_NAME}"

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${FILE_NAME}"

echo "Downloading ${DOWNLOAD_URL} ..."
curl -L -o "${FILE_NAME}" "${DOWNLOAD_URL}"

echo "Extracting..."
tar zxf "${FILE_NAME}"

# echo "文件名：${FILE_NAME}"
DIR_NAME="smartdns"
echo "Change directory to ${DIR_NAME} 文件夹"
cd "smartdns"

echo "Making install script executable..."
chmod +x ./install

echo "开始安装 Smartdns ..."
./install -U

echo "Smartdns安装完成"

##########################
# 下载国内外域名列表
echo "2/2 下载海外域名列表..."
DOMAINLIST_CONF_DIR="/etc/smartdns/domain-set"
MAIN_CONF="/etc/smartdns/smartdns.conf"
LOG_DIR="/etc/smartdns/log"
OVERSEA_CONF="${DOMAINLIST_CONF_DIR}/oversea_domainlist.conf"
DOMESTIC_CONF="${DOMAINLIST_CONF_DIR}/domestic_domainlist.conf"
OVERSEA_URL="https://raw.githubusercontent.com/WPF0414/GFWList2AGH/refs/heads/main/gfwlist2smartdns/blacklist_full.conf"
DOMESTIC_URL="https://raw.githubusercontent.com/WPF0414/GFWList2AGH/refs/heads/main/gfwlist2smartdns/whitelist_full.conf"

# 错误处理函数
error_exit() {
    echo "ERROR: $1"
    exit 1
}

# 下载新配置文件

mkdir -p "${DOMAINLIST_CONF_DIR}" || error_exit "无法创建目录 ${DOMAINLIST_CONF_DIR}"
mkdir -p "${LOG_DIR}" || error_exit "无法创建目录 ${LOG_DIR}"

# 判断配置文件是否已存在
if [ -f "${MAIN_CONF}" ]; then
    echo -e "\033[33m检测到 smartdns 配置文件 ${MAIN_CONF} 已存在，是否覆盖？\033[0m"
    echo "1) 覆盖"
    echo "2) 不覆盖"
    read -p "请输入选项 (1 或 2): " cover_choice
    case $cover_choice in
        1)
            echo "正在覆盖配置文件..."
            curl -sSf "${SMARTDNS_URL}" -o "${MAIN_CONF}" || error_exit "下载 SmartDNS 配置文件失败"
            ;;
        2)
            echo "已选择不覆盖，跳过下载配置文件。"
            ;;
        *)
            echo "ERROR: 无效的选项，请输入 1 或 2"
            exit 1
            ;;
    esac
else
    curl -sSf "${SMARTDNS_URL}" -o "${MAIN_CONF}" || error_exit "下载 SmartDNS 配置文件失败"
fi


echo "开始下载海外域名列表..."
curl -sSf "${OVERSEA_URL}" -o "${OVERSEA_CONF}" || error_exit "下载海外域名列表失败"

echo "开始下载国内域名列表..."
curl -sSf "${DOMESTIC_URL}" -o "${DOMESTIC_CONF}" || error_exit "下载国内域名列表失败"

echo "国内外域名列表下载完成"

# 启动服务
systemctl restart smartdns

echo
echo "==============================="
echo "   ✅ ${SMARTDNS_VERSION} 安装并启动完成   "
echo "==============================="
echo

echo -e "\033[33m⚠️  请修改 ${MAIN_CONF} 文件中标注有《需要修改》字样的行，其他的不要改  ⚠️\033[0m"
echo
