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

# 更新软件包列表
echo "1/5 更新软件源..."
apt update

# 安装 smartdns（如果官方仓库已有包）

echo "2/5 安装 SmartDNS..."
apt install -y smartdns

# 下载国内外域名列表
echo "4/5 下载海外域名列表..."
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

# 根据用户选择下载对应的配置文件
curl -sSf "${SMARTDNS_URL}" -o "${MAIN_CONF}" || error_exit "下载 SmartDNS 配置文件失败"


echo "开始下载海外域名列表..."
curl -sSf "${OVERSEA_URL}" -o "${OVERSEA_CONF}" || error_exit "下载海外域名列表失败"

echo "开始下载国内域名列表..."
curl -sSf "${DOMESTIC_URL}" -o "${DOMESTIC_CONF}" || error_exit "下载国内域名列表失败"

echo "国内外域名列表下载完成"

# 启用开机启动并立即启动服务
echo "5/5 设置开机启动并启动 SmartDNS..."
systemctl enable smartdns
systemctl restart smartdns

echo
echo "==============================="
echo "   ✅ ${SMARTDNS_VERSION} 安装并启动完成   "
echo "==============================="
echo
