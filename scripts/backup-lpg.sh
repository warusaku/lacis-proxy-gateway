#!/bin/bash
# backup-lpg.sh - LPG Backup Script
# Version: 1.0.0
# Description: LPGの設定、ログ、証明書を定期的にバックアップ

# 設定
BACKUP_BASE_DIR="/var/backups/lpg"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE_DIR}/${TIMESTAMP}"
KEEP_DAYS=7
KEEP_GENERATIONS=5

# バックアップ対象
CONFIG_DIR="/etc/lpg"
LOG_DIR="/var/log/lpg"
CADDY_DATA="/var/lib/caddy"
FTP_DIR="/var/ftp/lpg"

# リモートバックアップ設定（オプション）
REMOTE_BACKUP_ENABLED=${REMOTE_BACKUP_ENABLED:-false}
REMOTE_BACKUP_HOST=${REMOTE_BACKUP_HOST:-""}
REMOTE_BACKUP_PATH=${REMOTE_BACKUP_PATH:-""}
REMOTE_BACKUP_USER=${REMOTE_BACKUP_USER:-""}

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/lpg/backup.log
}

# エラーハンドリング
set -e
trap 'log "エラーが発生しました: Line $LINENO"' ERR

# バックアップディレクトリの作成
log "バックアップを開始します: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1. 設定ファイルのバックアップ
log "設定ファイルをバックアップしています..."
if [ -d "$CONFIG_DIR" ]; then
    tar -czf "${BACKUP_DIR}/config.tar.gz" -C "$(dirname $CONFIG_DIR)" "$(basename $CONFIG_DIR)" 2>/dev/null || {
        log "警告: 設定ファイルのバックアップで一部エラーが発生しました"
    }
fi

# 2. ログファイルのバックアップ（圧縮）
log "ログファイルをバックアップしています..."
if [ -d "$LOG_DIR" ]; then
    # アクティブなログファイルを除外してバックアップ
    find "$LOG_DIR" -type f -name "*.log" ! -name "*.log.gz" -mtime +1 | while read -r logfile; do
        gzip -c "$logfile" > "${logfile}.gz" 2>/dev/null || true
    done
    
    tar -czf "${BACKUP_DIR}/logs.tar.gz" \
        --exclude="*.log" \
        -C "$(dirname $LOG_DIR)" "$(basename $LOG_DIR)" 2>/dev/null || {
        log "警告: ログファイルのバックアップで一部エラーが発生しました"
    }
fi

# 3. Caddy証明書のバックアップ
log "証明書をバックアップしています..."
if [ -d "$CADDY_DATA" ]; then
    tar -czf "${BACKUP_DIR}/caddy-data.tar.gz" -C "$(dirname $CADDY_DATA)" "$(basename $CADDY_DATA)" 2>/dev/null || {
        log "警告: 証明書のバックアップで一部エラーが発生しました"
    }
fi

# 4. FTPアップロードディレクトリのバックアップ
log "FTPデータをバックアップしています..."
if [ -d "$FTP_DIR" ]; then
    tar -czf "${BACKUP_DIR}/ftp-data.tar.gz" \
        --exclude="upload/*" \
        -C "$(dirname $FTP_DIR)" "$(basename $FTP_DIR)" 2>/dev/null || {
        log "警告: FTPデータのバックアップで一部エラーが発生しました"
    }
fi

# 5. システム情報の保存
log "システム情報を保存しています..."
cat > "${BACKUP_DIR}/system-info.txt" <<EOF
バックアップ日時: $(date)
ホスト名: $(hostname)
IPアドレス: $(hostname -I)
カーネル: $(uname -r)
稼働時間: $(uptime)
ディスク使用量:
$(df -h)
メモリ使用量:
$(free -h)
実行中のサービス:
$(systemctl list-units --type=service --state=running | grep -E '(lpg|caddy|vsftpd)')
EOF

# 6. バックアップのメタデータを作成
cat > "${BACKUP_DIR}/backup-metadata.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0",
  "hostname": "$(hostname)",
  "files": [
    "config.tar.gz",
    "logs.tar.gz",
    "caddy-data.tar.gz",
    "ftp-data.tar.gz",
    "system-info.txt"
  ]
}
EOF

# 7. バックアップ全体を圧縮
log "バックアップを圧縮しています..."
cd "$BACKUP_BASE_DIR"
tar -czf "lpg-backup-${TIMESTAMP}.tar.gz" "$TIMESTAMP"

# 8. 古いバックアップの削除
log "古いバックアップを削除しています..."

# 日数ベースの削除
find "$BACKUP_BASE_DIR" -name "lpg-backup-*.tar.gz" -mtime +$KEEP_DAYS -delete 2>/dev/null || true

# 世代数ベースの削除
ls -t "$BACKUP_BASE_DIR"/lpg-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP_GENERATIONS + 1)) | xargs -r rm -f

# 一時ディレクトリの削除
rm -rf "$BACKUP_DIR"

# 9. リモートバックアップ（有効な場合）
if [ "$REMOTE_BACKUP_ENABLED" = "true" ] && [ -n "$REMOTE_BACKUP_HOST" ]; then
    log "リモートバックアップを実行しています..."
    
    BACKUP_FILE="lpg-backup-${TIMESTAMP}.tar.gz"
    
    # rsyncを使用してバックアップを転送
    if command -v rsync >/dev/null 2>&1; then
        rsync -avz --timeout=300 \
            "${BACKUP_BASE_DIR}/${BACKUP_FILE}" \
            "${REMOTE_BACKUP_USER}@${REMOTE_BACKUP_HOST}:${REMOTE_BACKUP_PATH}/" 2>&1 | tee -a /var/log/lpg/backup.log || {
            log "エラー: リモートバックアップに失敗しました"
        }
    else
        # scpをフォールバックとして使用
        scp -o ConnectTimeout=30 \
            "${BACKUP_BASE_DIR}/${BACKUP_FILE}" \
            "${REMOTE_BACKUP_USER}@${REMOTE_BACKUP_HOST}:${REMOTE_BACKUP_PATH}/" 2>&1 | tee -a /var/log/lpg/backup.log || {
            log "エラー: リモートバックアップに失敗しました"
        }
    fi
fi

# 10. バックアップサイズの確認
BACKUP_SIZE=$(du -h "${BACKUP_BASE_DIR}/lpg-backup-${TIMESTAMP}.tar.gz" | awk '{print $1}')
log "バックアップが完了しました: lpg-backup-${TIMESTAMP}.tar.gz (${BACKUP_SIZE})"

# 11. 成功通知（オプション）
if [ -n "$LOG_ENDPOINT" ]; then
    curl -X POST "$LOG_ENDPOINT/backup" \
        -H "Content-Type: application/json" \
        -d "{\"status\":\"success\",\"timestamp\":\"$TIMESTAMP\",\"size\":\"$BACKUP_SIZE\"}" \
        2>/dev/null || true
fi

exit 0 