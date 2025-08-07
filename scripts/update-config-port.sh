#!/bin/bash

# LPG config.jsonポート設定更新スクリプト
# 作成日: 2025-08-04
# 目的: バックエンドルーティングのポートを80から8081に修正

echo "=== LPG config.json ポート設定更新 ==="
echo ""

# SSHで接続してconfig.jsonを更新
expect << 'EOF'
set timeout 30

spawn ssh -o StrictHostKeyChecking=no root@192.168.234.2

expect {
    "password:" {
        send "orangepi\r"
    }
    timeout {
        puts "SSH接続タイムアウト"
        exit 1
    }
}

expect "root@"

# 現在のconfig.jsonを確認
send "cd /opt/lpg\r"
expect "root@"

send "echo '=== 現在のconfig.json ==='\r"
expect "root@"

send "cat config.json\r"
expect "root@"

# config.jsonをバックアップ
send "cp config.json config.json.bak.$(date +%Y%m%d_%H%M%S)\r"
expect "root@"

# 修正されたconfig.jsonを作成
send "cat > config.json << 'CONFIG_EOF'\r"
send {
{
  "hostingdevice": {
    "akb001yebraxfqsm9y.dyndns-web.com": {
      "/lacisstack/boards": {
        "deviceip": "192.168.234.10",
        "port": [8081],
        "sitename": "whiteboard"
      }
    }
  },
  "hostdomains": {
    "akb001yebraxfqsm9y.dyndns-web.com": "any"
  },
  "adminuser": {
    "admin": "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
  }
}
}
send "\r"
send "CONFIG_EOF\r"
expect "root@"

# 変更を確認
send "echo ''\r"
expect "root@"
send "echo '=== 更新後のconfig.json ==='\r"
expect "root@"

send "cat config.json\r"
expect "root@"

# lpg-proxy-8080.pyのソースコードも確認（既に8081に修正済みかチェック）
send "echo ''\r"
expect "root@"
send "echo '=== lpg-proxy-8080.pyのポート設定確認 ==='\r"
expect "root@"

send "cd /opt/lpg/src\r"
expect "root@"

send "grep -n 'port.*8081' lpg-proxy-8080.py || echo 'ポート8081の設定が見つかりません'\r"
expect "root@"

# lpg-proxy-8080サービスを再起動
send "echo ''\r"
expect "root@"
send "echo '=== LPGプロキシサービス再起動 ==='\r"
expect "root@"

send "systemctl restart lpg-proxy-8080\r"
expect "root@"

send "sleep 2\r"
expect "root@"

# サービス状態確認
send "systemctl status lpg-proxy-8080 | head -10\r"
expect "root@"

# ポート確認
send "echo ''\r"
expect "root@"
send "echo '=== ポート確認 ==='\r"
expect "root@"

send "netstat -tlnp | grep -E '(8080|8443)'\r"
expect "root@"

# テスト用のcurlコマンド
send "echo ''\r"
expect "root@"
send "echo '=== ルーティングテスト ==='\r"
expect "root@"

send "curl -I -H 'Host: akb001yebraxfqsm9y.dyndns-web.com' http://localhost:8080/lacisstack/boards/ 2>&1 | head -5\r"
expect "root@"

send "exit\r"
expect eof
EOF

echo ""
echo "=== 設定更新完了 ==="
echo ""
echo "変更内容:"
echo "- config.json: port [80] → [8081]"
echo "- lpg-proxy-8080サービスを再起動"
echo ""
echo "動作確認:"
echo "https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/"