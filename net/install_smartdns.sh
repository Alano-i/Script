#!/bin/bash
set -e

# 更新软件包列表
echo "1/4 更新软件源..."
apt update

# 安装 smartdns（如果官方仓库已有包）

echo "2/4 安装 SmartDNS..."
apt install -y smartdns

# 写入默认配置文件（替换为你自己的上游 DNS）
echo "3/4 写入 SmartDNS 默认配置..."
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

# 启用开机启动并立即启动服务
echo "4/4 设置开机启动并启动 SmartDNS..."
systemctl enable smartdns
systemctl restart smartdns

echo "✅ SmartDNS 安装并启动完成。"
