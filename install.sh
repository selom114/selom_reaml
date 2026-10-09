#!/usr/bin/env bash

set -e

RED="\031[31m"
GREEN="\031[32m"
YELLOW="\031[33m"
PLAIN="\033[0m"

echo -e "${GREEN}=== 开始安装与配置 Realm 端口转发 ===${PLAIN}"

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 权限运行此脚本！${PLAIN}"
    exit 1
fi

# 2. 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        REALM_ARCH="x86_64-unknown-linux-musl"
        ;;
    aarch64|arm64)
        REALM_ARCH="aarch64-unknown-linux-musl"
        ;;
    *)
        echo -e "${RED}暂不支持的系统架构: ${ARCH}${PLAIN}"
        exit 1
        ;;
esac

# 3. 创建目录并下载最新版本
mkdir -p /etc/realm && cd /etc/realm

echo -e "${YELLOW}正在获取 Realm 最新版本并下载 (${REALM_ARCH})...${PLAIN}"
DOWNLOAD_URL="https://github.com/zhboner/realm/releases/latest/download/realm-${REALM_ARCH}.tar.gz"

curl -sSL "$DOWNLOAD_URL" -o realm.tar.gz
tar -xvf realm.tar.gz
rm -f realm.tar.gz
chmod +x realm

# 4. 写入配置文件 /etc/realm/realm.toml
echo -e "${YELLOW}正在写入配置文件...${PLAIN}"
cat << 'EOF' > /etc/realm/realm.toml
[network]
no_tcp = false
use_udp = true

# TW (#654)
[[endpoints]]
listen = "0.0.0.0:25948"
remote = "188.253.7.72:25558"

# JP (#632)
[[endpoints]]
listen = "0.0.0.0:63058"
remote = "209.33.174.75:44355"

# SG (#627)
[[endpoints]]
listen = "0.0.0.0:23221"
remote = "85.149.212.44:23345"

# HK (#625)
[[endpoints]]
listen = "0.0.0.0:28577"
remote = "opt2.selom.xyz:16235"

# 美国 (#622)
[[endpoints]]
listen = "0.0.0.0:48259"
remote = "155.117.19.101:33037"
EOF

# 5. 配置 Systemd 开机自启
echo -e "${YELLOW}正在配置 Systemd 系统服务...${PLAIN}"
cat << 'EOF' > /etc/systemd/system/realm.service
[Unit]
Description=Realm Port Forwarding Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/etc/realm/realm -c /etc/realm/realm.toml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动并加载服务
systemctl daemon-reload
systemctl enable --now realm

echo -e "${GREEN}=== Realm 安装并启动完成！ ===${PLAIN}"
systemctl status realm --no-pager
