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
echo "3) 安装 ADGuardHome"
echo "0) 退出脚本"
echo "============================="
read -p "请输入选项: " choice

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
	3)
		echo "即将安装 ADGuardHome"
		curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v || { echo "ADGuardHome 安装失败"; exit 1; }
		;;
	0)
		echo "已退出安装"
		exit 0
		;;
	*)
		echo "ERROR: 无效的选项，请输入 0、1、2 或 3"  # 更新错误提示
		exit 1
		;;
esac

exit 0
