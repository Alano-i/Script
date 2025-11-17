#!/usr/bin/env bash
set -e

echo
echo "███╗   ███╗██╗██╗  ██╗ ██████╗ ███╗   ███╗ ██████╗     ███████╗███╗   ███╗██████╗  █████╗ ████████╗██████╗ ███╗   ██╗███████╗
████╗ ████║██║██║  ██║██╔═══██╗████╗ ████║██╔═══██╗    ██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██╔════╝
██╔████╔██║██║███████║██║   ██║██╔████╔██║██║   ██║    ███████╗██╔████╔██║██████╔╝███████║   ██║   ██║  ██║██╔██╗ ██║███████╗
██║╚██╔╝██║██║██╔══██║██║   ██║██║╚██╔╝██║██║   ██║    ╚════██║██║╚██╔╝██║██╔══██╗██╔══██║   ██║   ██║  ██║██║╚██╗██║╚════██║
██║ ╚═╝ ██║██║██║  ██║╚██████╔╝██║ ╚═╝ ██║╚██████╔╝    ███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║   ██████╔╝██║ ╚████║███████║
╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝     ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═══╝╚══════╝
                                                                                                                             "

echo "============================="
echo "  请选择要安装的组件"
echo "============================="
echo "1) 安装 Mihomo"
echo "2) 安装 SmartDNS"
echo "0) 退出脚本"
echo "============================="
read -p "请输入选项 (0, 1 或 2): " choice

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
case "$choice" in
	1)
		echo "即将安装 Mihomo"
		curl -sS -O https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/install_mihomo.sh || { echo "下载 install_mihomo.sh 失败"; exit 1; }
		chmod +x install_mihomo.sh
		./install_mihomo.sh
		;;
	2)
		echo "即将安装 SmartDNS"
		curl -sS -O https://raw.githubusercontent.com/Alano-i/Script/refs/heads/main/net/install_smartdns.sh || { echo "下载 install_smartdns.sh 失败"; exit 1; }
		chmod +x install_smartdns.sh
		./install_smartdns.sh
		;;
		0)
			echo "已退出安装"
			exit 0
			;;
		*)
			echo "ERROR: 无效的选项，请输入 0、1 或 2"
			exit 1
			;;
esac

exit 0
