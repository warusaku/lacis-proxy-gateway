# Dockerfile for LacisProxyGateway
# Version: 1.0.0
# Description: Multi-stage build for LPG application

# Stage 1: Build Go API
FROM golang:1.21-alpine AS go-builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY src/api ./src/api

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o lpg-api ./src/api

# Stage 2: Build React Frontend
FROM node:18-alpine AS node-builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY tsconfig.json vite.config.ts ./
COPY src/web ./src/web
COPY index.html ./

# Build the application
RUN npm run build

# 最終的なランタイムイメージ
FROM debian:bullseye-slim

# 環境変数
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    CONFIG_FILE=/etc/lpg/config.json \
    LOG_DIR=/var/log/lpg \
    TLS_CERT_FILE=/etc/lpg/certs/server.crt \
    TLS_KEY_FILE=/etc/lpg/certs/server.key \
    LOG_ENDPOINT=""

# 必要なパッケージのインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tzdata \
        caddy \
        jq \
        vsftpd \
        openssl \
        inotify-tools \
        bash \
        su-exec \
        gnupg \
        lsb-release && \
    # Telegrafのインストール
    curl -sL https://repos.influxdata.com/influxdb.key | apt-key add - && \
    echo "deb https://repos.influxdata.com/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/influxdb.list && \
    apt-get update && \
    apt-get install -y telegraf && \
    rm -rf /var/lib/apt/lists/*

# ユーザーとグループの作成
RUN groupadd -r lpg && \
    useradd -r -g lpg -s /bin/bash -m lpg && \
    # lacisadminユーザーの作成（FTP用）
    useradd -m -d /home/lacisadmin -s /bin/bash lacisadmin && \
    echo "lacisadmin:lacis12345@" | chpasswd && \
    usermod -aG lpg lacisadmin

# ディレクトリの作成
RUN mkdir -p \
    /etc/lpg/certs \
    /etc/lpg/vsftpd \
    /etc/lpg/telegraf \
    /var/log/lpg \
    /var/lib/lpg \
    /var/run/lpg \
    /var/www/lpg \
    /var/ftp/lpg/upload \
    /var/ftp/lpg/backup \
    /var/ftp/lpg/deploy \
    /var/run/vsftpd/empty \
    /var/backups/lpg && \
    chown -R lpg:lpg /etc/lpg /var/log/lpg /var/lib/lpg /var/run/lpg /var/www/lpg && \
    chown -R lacisadmin:lpg /var/ftp/lpg && \
    chmod -R 755 /var/ftp/lpg

# ビルド成果物のコピー
COPY --from=go-builder /app/lpg-api /usr/local/bin/
COPY --from=node-builder /app/dist /var/www/lpg/

# 設定ファイルのコピー
COPY config/caddy/Caddyfile /etc/caddy/Caddyfile
COPY config/lpg/config.example.json /etc/lpg/config.example.json
COPY config/vsftpd/vsftpd.conf /etc/lpg/vsftpd/vsftpd.conf
COPY config/vsftpd/vsftpd.userlist /etc/lpg/vsftpd/vsftpd.userlist
COPY config/telegraf/telegraf.conf /etc/lpg/telegraf/telegraf.conf

# スクリプトのコピー
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY scripts/setup-ftp.sh /usr/local/bin/
COPY scripts/ftp-deploy-watcher.sh /usr/local/bin/
COPY scripts/lpg-health-check.sh /usr/local/bin/
COPY scripts/backup-lpg.sh /usr/local/bin/
COPY scripts/lpg-cron-setup.sh /usr/local/bin/
COPY scripts/security-hardening.sh /usr/local/bin/

# 実行権限の付与
RUN chmod +x \
    /usr/local/bin/lpg-api \
    /usr/local/bin/docker-entrypoint.sh \
    /usr/local/bin/setup-ftp.sh \
    /usr/local/bin/ftp-deploy-watcher.sh \
    /usr/local/bin/lpg-health-check.sh \
    /usr/local/bin/backup-lpg.sh \
    /usr/local/bin/lpg-cron-setup.sh \
    /usr/local/bin/security-hardening.sh

# ポートの公開
EXPOSE 80 443 8443 2019 21 30000-30100

# rootユーザーで実行（エントリポイントで権限を落とす）
USER root

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/lpg-health-check.sh || exit 1

# エントリポイント
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"] 