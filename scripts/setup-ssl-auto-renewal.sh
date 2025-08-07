#!/bin/bash

# Let's Encrypt SSL証明書自動更新設定スクリプト
# 作成日: 2025-08-04
# 目的: SSL証明書の自動更新を設定

echo "=== Let's Encrypt SSL証明書自動更新設定 ==="
echo ""

# SSHで接続して設定
expect << 'EOF'
set timeout 60

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

# certbotがインストールされているか確認
send "echo '=== Certbotインストール確認 ==='\r"
expect "root@"

send "which certbot\r"
expect {
    "/usr/bin/certbot" {
        send "echo 'Certbotは既にインストールされています'\r"
    }
    "no certbot" {
        send "echo 'Certbotをインストールします...'\r"
        expect "root@"
        send "apt-get update\r"
        expect "root@"
        send "apt-get install -y certbot python3-certbot-nginx\r"
        expect "root@"
    }
}

expect "root@"

# 既存の証明書を確認
send "echo ''\r"
expect "root@"
send "echo '=== 既存の証明書確認 ==='\r"
expect "root@"

send "certbot certificates\r"
expect "root@"

# 証明書がない場合は新規作成
send "echo ''\r"
expect "root@"
send "echo '=== SSL証明書設定 ==='\r"
expect "root@"

# ドメイン用の証明書を作成（既にある場合はスキップ）
send "certbot certonly --nginx -d akb001yebraxfqsm9y.dyndns-web.com --non-interactive --agree-tos --email admin@lacis.local --keep-until-expiring\r"
expect "root@"

# 自動更新用のcronジョブを作成
send "echo ''\r"
expect "root@"
send "echo '=== 自動更新Cronジョブ設定 ==='\r"
expect "root@"

# 既存のcertbot cronジョブを確認
send "crontab -l | grep certbot || echo '既存のcertbot cronジョブなし'\r"
expect "root@"

# 自動更新スクリプトを作成
send "cat > /etc/cron.d/certbot-renewal << 'CRON_EOF'\r"
send "# Certbot SSL証明書自動更新\r"
send "# 毎日午前2時と午後2時に更新チェック\r"
send "0 2,14 * * * root certbot renew --quiet --no-self-upgrade --post-hook 'systemctl reload nginx' >> /var/log/certbot-renewal.log 2>&1\r"
send "CRON_EOF\r"
expect "root@"

# cronジョブの権限設定
send "chmod 644 /etc/cron.d/certbot-renewal\r"
expect "root@"

# systemdタイマーも設定（より信頼性が高い）
send "echo ''\r"
expect "root@"
send "echo '=== Systemdタイマー設定 ==='\r"
expect "root@"

# certbot.timerの状態確認
send "systemctl status certbot.timer --no-pager | head -10\r"
expect "root@"

# タイマーを有効化
send "systemctl enable certbot.timer\r"
expect "root@"
send "systemctl start certbot.timer\r"
expect "root@"

# 更新テスト実行（ドライラン）
send "echo ''\r"
expect "root@"
send "echo '=== 更新テスト（ドライラン）==='\r"
expect "root@"

send "certbot renew --dry-run\r"
expect "root@"

# nginx設定でSSL証明書パスを確認
send "echo ''\r"
expect "root@"
send "echo '=== Nginx SSL設定確認 ==='\r"
expect "root@"

send "grep -r 'ssl_certificate' /etc/nginx/sites-enabled/ | head -5\r"
expect "root@"

# ログローテーション設定
send "echo ''\r"
expect "root@"
send "echo '=== ログローテーション設定 ==='\r"
expect "root@"

send "cat > /etc/logrotate.d/certbot-renewal << 'LOGROTATE_EOF'\r"
send "/var/log/certbot-renewal.log {\r"
send "    weekly\r"
send "    rotate 4\r"
send "    compress\r"
send "    delaycompress\r"
send "    missingok\r"
send "    notifempty\r"
send "    create 644 root root\r"
send "}\r"
send "LOGROTATE_EOF\r"
expect "root@"

# 設定確認
send "echo ''\r"
expect "root@"
send "echo '=== 設定完了確認 ==='\r"
expect "root@"

send "echo '1. Cronジョブ:'\r"
expect "root@"
send "cat /etc/cron.d/certbot-renewal\r"
expect "root@"

send "echo ''\r"
expect "root@"
send "echo '2. Systemdタイマー:'\r"
expect "root@"
send "systemctl list-timers certbot.timer --no-pager\r"
expect "root@"

send "echo ''\r"
expect "root@"
send "echo '3. 証明書の有効期限:'\r"
expect "root@"
send "certbot certificates | grep -A2 'Expiry Date'\r"
expect "root@"

send "exit\r"
expect eof
EOF

echo ""
echo "=== SSL証明書自動更新設定完了 ==="
echo ""
echo "設定内容:"
echo "1. Cronジョブ: 毎日2時と14時に更新チェック"
echo "2. Systemdタイマー: certbot.timerによる自動更新"
echo "3. ログファイル: /var/log/certbot-renewal.log"
echo "4. ログローテーション: 週次、4世代保持"
echo ""
echo "証明書の手動更新:"
echo "ssh root@192.168.234.2 'certbot renew'"
echo ""
echo "更新状況確認:"
echo "ssh root@192.168.234.2 'certbot certificates'"