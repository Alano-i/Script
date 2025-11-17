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
# ⑤ 创建配置文件处理
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

# ================================
# ⑥ UI 资源下载
# ================================
UI_DIR="/etc/mihomo/ui"

# 下载列表：支持新增条目（格式：KEY|URL）
DOWNLOAD_URLS=(
  "metacubexd|https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz"
  "zashboard|https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip"
  # 新增示例："newui|https://example.com/newui-dist.tar.gz"
)

# 识别压缩格式（根据URL后缀）
get_compress_type() {
  local url="$1"
  if [[ "$url" =~ \.tar\.gz$|\.tgz$ ]]; then
    echo "tar.gz"
  elif [[ "$url" =~ \.zip$ ]]; then
    echo "zip"
  else
    echo "unknown"
  fi
}

echo "开始下载 UI 资源..."
mkdir -p "$UI_DIR" || { echo "❌ 创建UI根目录失败：$UI_DIR"; exit 1; }

for entry in "${DOWNLOAD_URLS[@]}"; do
  # 分割 KEY 和 URL（兼容URL中含|的极端情况，此处按第一个|分割）
  KEY="${entry%%|*}"
  URL="${entry#*|}"
  TARGET_DIR="$UI_DIR/$KEY"  # 自动生成目标目录
  TMP_FILE="/tmp/${KEY}_ui.tmp"

  echo -e "\n➡ [$KEY] 下载：$URL"
  
  # 下载文件
  if ! curl -L --progress-bar -o "$TMP_FILE" "$URL"; then
    echo "❌ [$KEY] 下载失败：$URL"
    rm -f "$TMP_FILE"
    continue
  fi
  echo "[$KEY] 下载完成：$TMP_FILE"

  # 清理旧目录
  echo "[$KEY] 清理旧目录：$TARGET_DIR"
  rm -rf "$TARGET_DIR"
  mkdir -p "$TARGET_DIR" || { echo "❌ 创建目标目录失败：$TARGET_DIR"; rm -f "$TMP_FILE"; continue; }

  # 识别压缩格式并解压
  COMPRESS_TYPE=$(get_compress_type "$URL")
  case "$COMPRESS_TYPE" in
    tar.gz)
      echo "[$KEY] 解压到：$TARGET_DIR"
      if tar -xzf "$TMP_FILE" -C "$TARGET_DIR" >/dev/null 2>&1; then
        echo "✅ [$KEY] 解压完成：$TARGET_DIR"
      else
        echo "❌ [$KEY] 解压失败（tar.gz格式）"
      fi
      rm -f "$TMP_FILE"
      ;;

    zip)
      TMP_UNZIP_DIR="/tmp/${KEY}_unzip"
      rm -rf "$TMP_UNZIP_DIR"
      mkdir -p "$TMP_UNZIP_DIR"

      echo "[$KEY] 解压到临时目录：$TMP_UNZIP_DIR"
      if unzip -q "$TMP_FILE" -d "$TMP_UNZIP_DIR" >/dev/null 2>&1; then
        # 兼容 zip 包是否包含 dist 顶级目录
        if [ -d "$TMP_UNZIP_DIR/dist" ]; then
          mv "$TMP_UNZIP_DIR/dist/"* "$TARGET_DIR/"
        else
          mv "$TMP_UNZIP_DIR/"* "$TARGET_DIR/"
        fi
        echo "✅ [$KEY] 解压完成：$TARGET_DIR"
      else
        echo "❌ [$KEY] 解压失败（zip格式）"
      fi

      # 清理临时文件
      rm -rf "$TMP_UNZIP_DIR"
      rm -f "$TMP_FILE"
      ;;

    unknown)
      echo "❌ [$KEY] 不支持的压缩格式：$URL"
      rm -f "$TMP_FILE"
      ;;
  esac
done

echo -e "\n✅ WEB UI 全部安装完成\n"

# ================================
# ⑦ 写入 systemd
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
