#!/bin/bash
# ARP保護スクリプト - ARPポイゾニング/スプーフィング対策

echo "=== ARP保護設定 ==="

# 1. 現在のARP設定を確認
echo "1. 現在のARP設定:"
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
# ARPテーブルを表示
echo "現在のARPテーブル:"
arp -a

# sysctl設定を確認
echo -e "\nARP関連のカーネルパラメータ:"
sysctl net.ipv4.conf.all.arp_ignore
sysctl net.ipv4.conf.all.arp_announce
sysctl net.ipv4.conf.all.arp_filter
ENDSSH

# 2. ARP保護を設定
echo -e "\n2. ARP保護を設定:"
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
# ARPキャッシュポイゾニング対策
echo "ARPキャッシュポイゾニング対策を設定..."

# カーネルパラメータを設定
cat > /etc/sysctl.d/99-arp-protection.conf << 'EOF'
# ARP保護設定
# arp_ignore: ARPリクエストへの応答を制限
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1

# arp_announce: ARP送信時のソースIPアドレスを制限  
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2

# arp_filter: ARPフィルタリングを有効化
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.default.arp_filter = 1

# プロキシARPを無効化
net.ipv4.conf.all.proxy_arp = 0
net.ipv4.conf.default.proxy_arp = 0

# ICMPリダイレクトを無効化
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# ソースルート検証を有効化
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF

# 設定を適用
sysctl -p /etc/sysctl.d/99-arp-protection.conf

echo "✓ ARP保護設定を適用しました"
ENDSSH

# 3. 静的ARPエントリを設定（オプション）
echo -e "\n3. 重要なホストの静的ARPエントリ設定:"
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
# ゲートウェイのMACアドレスを取得して静的設定
# 注: 実際のゲートウェイのIPとMACアドレスに置き換えてください

# 例: ゲートウェイが192.168.234.1の場合
# GATEWAY_IP="192.168.234.1"
# GATEWAY_MAC=$(arp -n $GATEWAY_IP | grep -v "incomplete" | awk '{print $3}' | grep -v "HWaddress")
# if [ ! -z "$GATEWAY_MAC" ]; then
#     arp -s $GATEWAY_IP $GATEWAY_MAC
#     echo "ゲートウェイの静的ARPエントリを設定: $GATEWAY_IP -> $GATEWAY_MAC"
# fi

echo "静的ARPエントリの設定はスキップしました（手動設定が必要）"
ENDSSH

# 4. ARPwatchのインストール（オプション）
echo -e "\n4. ARPモニタリングツールの推奨:"
echo "以下のコマンドでarpwatchをインストールできます:"
echo "  apt-get install arpwatch"
echo "  systemctl enable arpwatch"
echo "  systemctl start arpwatch"

echo -e "\n=== ARP保護設定完了 ==="
echo "注意事項:"
echo "1. 静的ARPエントリはネットワーク環境に応じて手動設定が必要です"
echo "2. arpwatchでARPテーブルの変更を監視することを推奨します"
echo "3. 定期的にARPテーブルを確認してください: arp -a"