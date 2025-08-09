#!/bin/bash
# 安全なLPG再起動スクリプト
# ネットワーク全体に影響を与えないように慎重に設計

echo "=== 安全なLPG再起動スクリプト ==="
echo "このスクリプトは127.0.0.1のみでLPGをバインドします"

# 1. 既存のプロセスを確実に停止
echo -e "\n1. 既存のプロセスを停止..."
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
# すべてのLPG関連プロセスを停止
pkill -f lpg_admin.py
pkill -f lpg-proxy.py
sleep 3

# 確実に停止したか確認
if pgrep -f lpg_admin.py > /dev/null; then
    echo "警告: lpg_admin.pyがまだ実行中です。強制終了します..."
    pkill -9 -f lpg_admin.py
    sleep 2
fi

echo "プロセス停止完了"
ENDSSH

# 2. ポート使用状況を確認
echo -e "\n2. ポート8443の使用状況を確認..."
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
netstat -tlnp | grep 8443 || echo "ポート8443は使用されていません"
ENDSSH

# 3. 安全な設定でLPGを起動
echo -e "\n3. LPGを安全な設定で起動..."
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
cd /opt/lpg/src

# 環境変数を明示的に設定（127.0.0.1のみでバインド）
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
export LPG_BIND_ADDRESS=127.0.0.1

# ログファイルをローテーション
if [ -f /var/log/lpg_admin.log ]; then
    mv /var/log/lpg_admin.log /var/log/lpg_admin.log.$(date +%Y%m%d_%H%M%S)
fi

# LPGを起動
echo "Starting LPG with HOST=$LPG_ADMIN_HOST PORT=$LPG_ADMIN_PORT"
nohup python3 lpg_admin.py > /var/log/lpg_admin.log 2>&1 &
sleep 5

# 起動確認
if pgrep -f lpg_admin.py > /dev/null; then
    echo "✓ LPGが正常に起動しました"
    ps aux | grep lpg_admin | grep -v grep
else
    echo "✗ LPGの起動に失敗しました"
    tail -20 /var/log/lpg_admin.log
    exit 1
fi
ENDSSH

# 4. ネットワーク設定の確認
echo -e "\n4. ネットワーク設定を確認..."
sshpass -p "orangepi" ssh root@192.168.234.2 << 'ENDSSH'
echo "IPアドレス:"
ip addr show | grep "inet " | grep -v "127.0.0.1"

echo -e "\nリスニングポート:"
netstat -tlnp | grep -E "(8443|8080|443|80)"

echo -e "\nNginxステータス:"
systemctl status nginx --no-pager | head -5
ENDSSH

echo -e "\n=== 起動完了 ==="
echo "アクセス方法:"
echo "  外部から: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/"
echo "  内部から: https://192.168.234.2/lpg-admin/"
echo ""
echo "重要: LPGは127.0.0.1:8443でのみリスニングしています"
echo "外部アクセスはNginxリバースプロキシ経由です"