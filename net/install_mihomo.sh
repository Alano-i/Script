#!/usr/bin/env bash
# ----------------------------------------------------------
# 一键安装 mihomo（二进制自动下载最新版本）
# 自动识别系统架构，自动下载 GitHub Releases 最新版本
# ----------------------------------------------------------

set -e

BIN_DEST="/usr/local/bin/mihomo"
CONFIG_DIR="/etc/mihomo"
SERVICE_FILE="/etc/systemd/system/mihomo.service"

MAIN_CONF="${CONFIG_DIR}/config.yaml"
CONF_URL="https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/mihomo.yml"

GITHUB_REPO="MetaCubeX/mihomo"
DOWNLOAD_DIR="/tmp/mihomo_download"

echo
echo "=============== 自动安装 Mihomo ==============="

error_exit() {
    echo "ERROR: $1"
    exit 1
}

# 检查 root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请以 root 用户运行"
  exit 1
fi

# ================================
# ① 检测系统架构
# ================================
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_KEYWORD="linux-amd64"
        ;;
    aarch64|arm64)
        ARCH_KEYWORD="linux-arm64"
        ;;
    *)
        error_exit "不支持的架构: $ARCH（仅支持 amd64 / arm64）"
        ;;
esac

echo "检测到系统架构：$ARCH → 使用构建：$ARCH_KEYWORD"

# ================================
# ② 获取 GitHub 最新版本号
# ================================
echo "获取 GitHub 最新版本中…"

LATEST_TAG=$(curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep tag_name | cut -d '"' -f 4)

if [ -z "$LATEST_TAG" ]; then
    error_exit "无法从 GitHub 获取最新版本"
fi

echo "最新版本：$LATEST_TAG"

# ================================
# ③ 下载对应架构的二进制包
# ================================
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

ASSET_NAME="mihomo-${ARCH_KEYWORD}-v3-${LATEST_TAG}.gz"
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/${LATEST_TAG}/${ASSET_NAME}"

echo "下载文件：$ASSET_NAME"
echo "下载地址：$DOWNLOAD_URL"

curl -L -o "$ASSET_NAME" "$DOWNLOAD_URL" || error_exit "下载失败"

echo "解压中…"
gunzip -f "$ASSET_NAME"

BINARY_SRC="${ASSET_NAME%.gz}"

if [ ! -f "$BINARY_SRC" ]; then
    error_exit "解压失败：未找到解压后的二进制文件"
fi

chmod +x "$BINARY_SRC"
echo "成功下载并解压 mihomo → $BINARY_SRC"

# ================================
# ④ 覆盖旧版
# ================================
echo "安装到 $BIN_DEST …"

if pgrep -x "mihomo" >/dev/null; then
    echo "检测到运行中的 mihomo → 停止"
    systemctl stop mihomo || true
fi

cp "$BINARY_SRC" "$BIN_DEST"
chmod +x "$BIN_DEST"

# ================================
# ⑤ 配置文件处理
# ================================
mkdir -p "$CONFIG_DIR"

if [ -f "$MAIN_CONF" ]; then
    echo "检测到已有配置文件 ${MAIN_CONF}"
    echo "1) 覆盖"
    echo "2) 不覆盖"
    read -p "选择 (1/2): " choice
    if [ "$choice" = "1" ]; then
        curl -sSf "$CONF_URL" -o "$MAIN_CONF" || error_exit "下载配置失败"
        echo "已覆盖配置文件"
    else
        echo "跳过覆盖配置文件"
    fi
else
    curl -sSf "$CONF_URL" -o "$MAIN_CONF" || error_exit "下载配置失败"
fi

# ================================
# ⑥ 写入 systemd
# ================================
echo "写入 systemd 文件：$SERVICE_FILE"

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

systemctl daemon-reload
systemctl enable mihomo
systemctl restart mihomo

echo
echo "========================================="
echo "  ✅ Mihomo 已成功安装并启动！"
echo "  版本：$LATEST_TAG"
echo "-----------------------------------------"
echo "查看状态： systemctl status mihomo"
echo "查看日志： journalctl -u mihomo -o cat -f"
echo -e "\033[33m⚠️  请修改 ${MAIN_CONF} 文件中标注有《需要修改》字样的行，其他的按需修改  ⚠️\033[0m"

echo "========================================="
echo

exit 0
