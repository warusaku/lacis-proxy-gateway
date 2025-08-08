#!/bin/bash
# Phase 1: Orange Pi Zero 3 Initial Setup
# Based on 080LPG最終チェック.md

set -e

ORANGE_PI_IP="192.168.234.2"
DEFAULT_USER="orangepi"
DEFAULT_PASS="orangepi"

echo "======================================="
echo "  Phase 1: 初期設定"
echo "======================================="

# SSH接続して初期設定を実行
sshpass -p "${DEFAULT_PASS}" ssh -o StrictHostKeyChecking=no ${DEFAULT_USER}@${ORANGE_PI_IP} << 'PHASE1_EOF'

echo "Starting initial setup..."

# 1. rootパスワード設定
echo -e "orangepi\norangepi" | sudo passwd root

# 2. orangepiパスワード確認（変更不要）
echo "Keeping orangepi password as default for now"

# 3. ホスト名設定
sudo hostnamectl set-hostname lpg-proxy
echo "127.0.0.1 lpg-proxy" | sudo tee -a /etc/hosts

# 4. タイムゾーン設定
sudo timedatectl set-timezone Asia/Tokyo

# 5. ネットワーク設定
sudo tee /etc/netplan/01-network.yaml > /dev/null << 'NET_EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.234.2/24
      routes:
        - to: default
          via: 192.168.234.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
NET_EOF

# 6. ネットワーク設定適用
sudo netplan apply

# 7. 確認
echo "=== Network Configuration ==="
ip addr show eth0 | grep inet
echo ""
echo "=== Hostname ==="
hostname
echo ""
echo "=== Timezone ==="
timedatectl | grep "Time zone"
echo ""
echo "=== Gateway Connectivity ==="
ping -c 2 192.168.234.1

echo "Phase 1 completed successfully!"

PHASE1_EOF

echo "Phase 1: 初期設定完了"