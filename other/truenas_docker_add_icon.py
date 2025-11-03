#!/usr/bin/env python3
"""
功能：修改 TrueNAS 应用的 metadata.yaml 文件中的图标和 Web UI 地址，实现在TrueNAS WEB 页面展示 Docker 应用图标和添加 Web UI 按钮的目的。
使用方法：
1、将脚本传到数据集中，添加执行权限，
2、用root运行：python truenas_docker_add_icon.py
"""
import os
import yaml
import shutil

# 固定 TrueNAS 应用配置路径
TARGET_DIR = "/mnt/.ix-apps/app_configs"


# 图标映射表
icon_map = {
    "emby": "https://img.xxx.com/docker/emby.svg",
    "syncthing": "https://img.xxx.com/docker/syncthing.svg"
}

# Web UI 地址映射表
webui_map = {
    "emby": "http://10.10.10.100:8096/",
    "syncthing": "http://10.10.10.100:20910/"
}

print("\n图标映射表：")
for key, value in icon_map.items():
    print(f"{key}：{value}")

print("\nWeb UI映射表：")
for key, value in webui_map.items():
    print(f"{key}：{value}")

print("\n")
print("-" * 40)

# 检查路径
if not os.path.isdir(TARGET_DIR):
    print(f"错误: 指定的路径不是有效的目录: {TARGET_DIR}")
    exit(1)

for folder in os.listdir(TARGET_DIR):
    folder_path = os.path.join(TARGET_DIR, folder)
    if not os.path.isdir(folder_path):
        continue

    metadata_path = os.path.join(folder_path, "metadata.yaml")
    if not os.path.isfile(metadata_path):
        print(f"跳过: {folder} 没有 metadata.yaml 文件")
        continue

    try:
        # 读取原文件
        with open(metadata_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}

        modified = False

        # --- 1️⃣ 修改或添加 metadata.icon ---
        if folder in icon_map:
            if "metadata" not in data or not isinstance(data["metadata"], dict):
                data["metadata"] = {}
            old_icon = data["metadata"].get("icon")
            new_icon = icon_map[folder]
            if old_icon != new_icon:
                data["metadata"]["icon"] = new_icon
                modified = True

        # --- 2️⃣ 修改或添加 portals.Web UI ---
        if folder in webui_map:
            if "portals" not in data or not isinstance(data["portals"], dict):
                data["portals"] = {}
            portals = data["portals"]
            old_webui = portals.get("Web UI")
            new_webui = webui_map[folder]
            if old_webui != new_webui:
                portals["Web UI"] = new_webui
                modified = True

        # --- 写回文件 ---
        if modified:
            backup_path = metadata_path + ".bak"
            if not os.path.exists(backup_path):
                shutil.copy2(metadata_path, backup_path)

            with open(metadata_path, "w", encoding="utf-8") as f:
                yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)

            print(f"✅ 已更新 {folder} 的 metadata.yaml，原文件已备份为 {backup_path}")
        else:
            print(f"ℹ️ {folder} 无需修改")

    except Exception as e:
        print(f"⚠️ 处理 {folder} 时出错: {e}")

print("-" * 40)
print("\n🎯 修改应用图标和 Web UI地址任务已完成！\n")
print("-" * 40)
