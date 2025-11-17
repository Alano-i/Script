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
# ⑥ UI 资源下载
# ================================
UI_DIR="/etc/mihomo/ui"
META_DIR="$UI_DIR/meta"
ZASH_DIR="$UI_DIR/zash"

DOWNLOAD_URLS=(
  "meta|https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz"
  "zash|https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip"
)

# ----------------------------
# 工具函数
# ----------------------------
# 要检查的命令列表
TOOLS=("unzip" "curl")
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_if_needed() {
    local cmd=$1
    local pkg=${2:-$cmd}  # 包名默认为命令名

    if command_exists "$cmd"; then
        return 0
    fi

    echo "⚠ 未检测到 $cmd，正在尝试自动安装..."

    [ "$(id -u)" -ne 0 ] && SUDO=sudo || SUDO=""

    if command_exists apt-get; then
        $SUDO apt-get update && $SUDO apt-get install -y "$pkg"
    elif command_exists yum; then
        $SUDO yum install -y "$pkg"
    elif command_exists dnf; then
        $SUDO dnf install -y "$pkg"
    elif command_exists apk; then
        $SUDO apk add --no-cache "$pkg"
    elif command_exists pacman; then
        $SUDO pacman -Sy --noconfirm "$pkg"
    elif command_exists zypper; then
        $SUDO zypper --non-interactive install "$pkg"
    else
        echo "❌ 无法自动安装 $cmd，请手动安装后重试"
        exit 1
    fi

    if ! command_exists "$cmd"; then
        echo "❌ $cmd 安装失败，请手动安装后重试"
        exit 1
    fi
}
# 循环检查安装
for tool in "${TOOLS[@]}"; do
    install_if_needed "$tool"
done

echo "🌐 开始下载 UI 资源..."

mkdir -p "$UI_DIR"

for entry in "${DOWNLOAD_URLS[@]}"; do
    KEY="${entry%%|*}"
    URL="${entry#*|}"

    echo "➡ [$KEY] 下载：$URL"

    TMP_FILE="/tmp/${KEY}_ui.tmp"
    curl -L --progress-bar -o "$TMP_FILE" "$URL"

    echo "下载完成：$TMP_FILE"

    case "$KEY" in
        meta)
            TARGET="$META_DIR"
            echo "清理旧目录：$TARGET"
            rm -rf "$TARGET"
            mkdir -p "$TARGET"

            echo "解压 meta 到：$TARGET"
            tar -xzf "$TMP_FILE" -C "$TARGET"
            echo "✅ [meta] 解压完成：$TARGET"
            rm -f "$TMP_FILE"

        ;;
        zash)
            TARGET="$ZASH_DIR"
            echo "清理旧目录：$TARGET"
            rm -rf "$TARGET"
            mkdir -p "$TARGET"

            TMPDIR_ZASH="/tmp/zash_unzip"
            rm -rf "$TMPDIR_ZASH"
            mkdir -p "$TMPDIR_ZASH"

            unzip -q "$TMP_FILE" -d "$TMPDIR_ZASH"

            # 检测 dist 顶级目录
            if [ -d "$TMPDIR_ZASH/dist" ]; then
                mv "$TMPDIR_ZASH/dist/"* "$TARGET/"
            else
                mv "$TMPDIR_ZASH/"* "$TARGET/"
            fi
            rm -rf "$TMPDIR_ZASH"
            # 如果目录存在则删除
            if [ -d "$UI_DIR/zashboard" ]; then
                rm -rf "$UI_DIR/zashboard"
            fi
            rm -f "$TMP_FILE"

            echo "✅ [zash] 解压完成：$TARGET"
        ;;
    esac
done

echo "✅ WEB UI 全部安装完成"

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

if [ -d "$DOWNLOAD_DIR" ]; then
    rm -rf "$DOWNLOAD_DIR"
fi
if [ -d "$UI_DIR/zashboard" ]; then
    rm -rf "$UI_DIR/zashboard"
fi

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
