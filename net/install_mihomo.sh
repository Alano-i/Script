#!/usr/bin/env bash
# ----------------------------------------------------------
# 一键安装 mihomo（二进制方式）脚本
# Usage: 将你下载好的 mihomo 二进制文件解压（例如 mihomoxxxx）放在当前目录，
#        然后执行本脚本：./install_mihomo.sh
# 注意：须以 root 身份运行
# ----------------------------------------------------------

set -e

BINARY_SRC=""
BIN_DEST="/usr/local/bin/mihomo"
CONFIG_DIR="/etc/mihomo"
SERVICE_FILE="/etc/systemd/system/mihomo.service"

MAIN_CONF="${CONFIG_DIR}/config.yaml"
CONF_URL="https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/mihomo.yml"

echo
echo "=============== 安装 Mihomo =================="

# 错误处理函数
error_exit() {
    echo "ERROR: $1"
    exit 1
}

# 检查 root
if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请以 root 用户身份运行此脚本"
  exit 1
fi

# 查找你下载的二进制文件（以 “mihomo” 开头但不是已经命名为 mihomo）
for f in ./mihomo*; do
  if [ -f "$f" ] && [ "$f" != "./mihomo" ]; then
    BINARY_SRC="$f"
    break
  fi
done

if [ -z "$BINARY_SRC" ]; then
  echo "未找到下载的 mihomo 二进制文件（例如 mihomo-linux-amd64-v3-v1.19.16）"
  echo "请从以下链接下载并解压放在和脚本同目录 (注意命名需要以 mihomo 开头)"
  echo
  echo -e "\033[33mMihomo下载地址：https://wiki.metacubex.one/startup/#__tabbed_2_2\033[0m"
  echo
  exit 1
fi

echo "找到二进制文件：$BINARY_SRC"
echo "复制到 $BIN_DEST …"

# 检查 mihomo 进程是否在运行，如果在运行则先停止
if pgrep -x "mihomo" > /dev/null; then
    echo -e "\033[33m检测到 mihomo 进程正在运行，正在停止...\033[0m"
    systemctl stop mihomo.service
    sleep 1
    echo "mihomo 已停止"
fi

cp "$BINARY_SRC" "$BIN_DEST"
chmod +x "$BIN_DEST"

# 创建配置目录
if [ ! -d "$CONFIG_DIR" ]; then
  echo "创建配置目录 $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
fi

echo "开始配下 Mihomo 载置文件..."
# 判断配置文件是否已存在
if [ -f "${MAIN_CONF}" ]; then
    echo -e "\033[33m检测到 mihomo 配置文件 ${MAIN_CONF} 已存在，是否覆盖？\033[0m"
    echo "1) 覆盖"
    echo "2) 不覆盖"
    read -p "请输入选项 (1 或 2): " cover_choice
    case $cover_choice in
        1)
            echo "正在覆盖配置文件..."
            curl -sSf "${CONF_URL}" -o "${MAIN_CONF}" || error_exit "下载 Mihomo 配置文件失败"
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
    curl -sSf "${CONF_URL}" -o "${MAIN_CONF}" || error_exit "下载 Mihomo 配置文件失败"
fi

# 创建 systemd 服务文件
echo "创建 systemd 服务文件：$SERVICE_FILE"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=mihomo Daemon, Another Clash Kernel.
After=network.target NetworkManager.service systemd-networkd.service iwd.service

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
Restart=always
ExecStartPre=/usr/bin/sleep 1s
ExecStart=${BIN_DEST} -d ${CONFIG_DIR}
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd，启用并启动服务
echo "重新加载 systemd …"
systemctl daemon-reload

echo "启用服务：mihomo"
systemctl enable mihomo.service

echo "启动服务：mihomo"
systemctl start mihomo.service

echo
echo "========================================="
echo "✅ Mihomo 安装完成"
echo "查看服务状态： systemctl status mihomo"
echo "查看日志： journalctl -u mihomo -o cat -f"
echo "========================================="
echo
exit 0
