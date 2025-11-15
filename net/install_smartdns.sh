#!/bin/bash
set -e

# 更新软件包列表
echo "1/5 更新软件源..."
apt update

# 安装 smartdns（如果官方仓库已有包）

echo "2/5 安装 SmartDNS..."
apt install -y smartdns

# 写入默认配置文件（替换为你自己的上游 DNS）
echo "3/5 写入 SmartDNS 默认配置..."
cat > /etc/smartdns/smartdns.conf << EOF
# 监听端口 (默认 53）
bind 0.0.0.0:53
# 上游服务器 示例：
server 1.1.1.1
server-tls 8.8.8.8:853
# 示例 domain‐rule／address 配置：
address /example.com/1.2.3.4
domain-rules /example.com/ -address 1.2.3.4
EOF

# 下载国内外域名列表
echo "4/5 下载海外域名列表..."
CONF_DIR="/etc/smartdns/domain-set"
LOG_DIR="/etc/smartdns/log"
OVERSEA_CONF="${CONF_DIR}/oversea_domainlist.conf"
DOMESTIC_CONF="${CONF_DIR}/domestic_domainlist.conf"
OVERSEA_URL="https://raw.githubusercontent.com/WPF0414/GFWList2AGH/refs/heads/main/gfwlist2smartdns/blacklist_full.conf"
DOMESTIC_URL="https://raw.githubusercontent.com/WPF0414/GFWList2AGH/refs/heads/main/gfwlist2smartdns/whitelist_full.conf"

# 错误处理函数
error_exit() {
    echo "ERROR: $1"
    exit 1
}

# 下载新配置文件
mkdir -p "${CONF_DIR}" || error_exit "无法创建目录 ${CONF_DIR}"
mkdir -p "${LOG_DIR}" || error_exit "无法创建目录 ${LOG_DIR}"
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
echo "============================="
echo "  ✅ SmartDNS 安装并启动完成   "
echo "============================="
echo
