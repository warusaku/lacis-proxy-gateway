#!/bin/bash
# docker-entrypoint.sh - LacisProxyGateway Docker Entrypoint
# Version: 1.0.0

set -e

echo "=== LacisProxyGateway 起動中 ==="

# 環境変数の確認
echo "環境: ${ENVIRONMENT:-production}"

# ディレクトリの作成
mkdir -p /var/log/lpg /var/run/lpg /var/backups/lpg

# FTP設定のセットアップ
if [ -f /usr/local/bin/setup-ftp.sh ]; then
    echo "FTPサーバーをセットアップしています..."
    /usr/local/bin/setup-ftp.sh
fi

# SSL証明書の生成（存在しない場合）
if [ ! -f "${TLS_CERT_FILE}" ] || [ ! -f "${TLS_KEY_FILE}" ]; then
    echo "SSL証明書を生成しています..."
    mkdir -p $(dirname "${TLS_CERT_FILE}")
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${TLS_KEY_FILE}" \
        -out "${TLS_CERT_FILE}" \
        -subj "/C=JP/ST=Tokyo/L=Tokyo/O=LacisProxyGateway/CN=lpg.local"
fi

# 設定ファイルの初期化
if [ ! -f /etc/lpg/config.json ]; then
    echo "config.jsonを初期化しています..."
    cp /etc/lpg/config.example.json /etc/lpg/config.json
fi

# Telegraf設定の環境変数置換
if [ -f /etc/lpg/telegraf/telegraf.conf ]; then
    echo "Telegraf設定を準備しています..."
    # LOG_ENDPOINTが設定されていない場合はデフォルト値を使用
    export LOG_ENDPOINT=${LOG_ENDPOINT:-"http://localhost:8080/api/v1"}
    export HOSTNAME=$(hostname)
    
    # 設定ファイルの環境変数を置換
    envsubst < /etc/lpg/telegraf/telegraf.conf > /etc/telegraf/telegraf.conf
fi

# vsftpdの起動
if [ -x /usr/sbin/vsftpd ]; then
    echo "vsftpdを起動しています..."
    /usr/sbin/vsftpd /etc/vsftpd.conf &
fi

# FTPデプロイ監視の起動
if [ -f /usr/local/bin/ftp-deploy-watcher.sh ]; then
    echo "FTPデプロイ監視を起動しています..."
    nohup /usr/local/bin/ftp-deploy-watcher.sh > /var/log/lpg/deploy-watcher.log 2>&1 &
fi

# Telegrafの起動
if [ -x /usr/bin/telegraf ] && [ -f /etc/telegraf/telegraf.conf ]; then
    echo "Telegrafを起動しています..."
    /usr/bin/telegraf -config /etc/telegraf/telegraf.conf &
fi

# Caddyの起動
echo "Caddyを起動しています..."
caddy start --config /etc/caddy/Caddyfile --adapter caddyfile &

# ヘルスチェックの定期実行（バックグラウンド）
if [ -f /usr/local/bin/lpg-health-check.sh ]; then
    echo "ヘルスチェックを開始しています..."
    (
        while true; do
            sleep 300  # 5分ごと
            /usr/local/bin/lpg-health-check.sh > /var/log/lpg/health-check.json 2>&1
        done
    ) &
fi

# LPG APIサーバーの起動
echo "LPG APIサーバーを起動しています..."

# 権限を変更してAPIを実行
exec su-exec lpg /usr/local/bin/lpg-api 