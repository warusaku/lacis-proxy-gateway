#!/bin/bash
# lpg-cron-setup.sh - LPG Cron Job Setup Script
# Version: 1.0.0
# Description: LPGの定期タスク（バックアップ、ログローテーションなど）を設定

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# rootユーザーチェック
if [ "$EUID" -ne 0 ]; then 
   error "このスクリプトはrootユーザーで実行してください"
   exit 1
fi

log "LPG定期タスクを設定しています..."

# 1. cronディレクトリの作成
mkdir -p /etc/cron.d

# 2. LPG cronジョブファイルの作成
cat > /etc/cron.d/lpg-maintenance <<'EOF'
# LacisProxyGateway Maintenance Jobs
# Version: 1.0.0
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
MAILTO=""

# バックアップ - 毎日午前2時に実行
0 2 * * * root /usr/local/bin/backup-lpg.sh > /dev/null 2>&1

# ログローテーション - 毎日午前3時に実行
0 3 * * * root /usr/local/bin/lpg-log-rotate.sh > /dev/null 2>&1

# ヘルスチェック - 5分ごとに実行
*/5 * * * * root /usr/local/bin/lpg-health-check.sh > /var/log/lpg/health-check.json 2>&1

# Telegrafメトリクス送信チェック - 15分ごと
*/15 * * * * root systemctl is-active --quiet telegraf || systemctl restart telegraf

# ディスククリーンアップ - 毎週日曜日午前4時
0 4 * * 0 root /usr/local/bin/lpg-cleanup.sh > /dev/null 2>&1

# 設定ファイルのバックアップ（5世代管理） - 1時間ごと
0 * * * * root /usr/local/bin/config-backup.sh > /dev/null 2>&1
EOF

# 3. ログローテーションスクリプトの作成
cat > /usr/local/bin/lpg-log-rotate.sh <<'EOF'
#!/bin/bash
# lpg-log-rotate.sh - Log Rotation Script
# Version: 1.0.0

LOG_DIR="/var/log/lpg"
MAX_SIZE="300K"  # 300KB
KEEP_PERCENT=20  # 最新20%を保持

# ログローテーション関数
rotate_log() {
    local logfile="$1"
    local size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
    local max_bytes=307200  # 300KB in bytes
    
    if [ "$size" -gt "$max_bytes" ]; then
        # ファイルの総行数を取得
        total_lines=$(wc -l < "$logfile")
        
        # 保持する行数を計算（最新20%）
        keep_lines=$((total_lines * KEEP_PERCENT / 100))
        
        # 一時ファイルに最新の行を保存
        tail -n "$keep_lines" "$logfile" > "${logfile}.tmp"
        
        # 元のファイルを置き換え
        mv "${logfile}.tmp" "$logfile"
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ローテーション完了: $logfile (${total_lines}行 → ${keep_lines}行)"
    fi
}

# すべてのログファイルをチェック
find "$LOG_DIR" -name "*.log" -type f | while read -r logfile; do
    rotate_log "$logfile"
done
EOF

# 4. クリーンアップスクリプトの作成
cat > /usr/local/bin/lpg-cleanup.sh <<'EOF'
#!/bin/bash
# lpg-cleanup.sh - System Cleanup Script
# Version: 1.0.0

# 古いログファイルの削除（30日以上）
find /var/log/lpg -name "*.log.gz" -mtime +30 -delete 2>/dev/null

# 古いバックアップの削除（処理済み）
find /var/backups/lpg -name "lpg-backup-*.tar.gz" -mtime +7 -delete 2>/dev/null

# FTPアップロードディレクトリのクリーンアップ（7日以上）
find /var/ftp/lpg/upload -type f -mtime +7 -delete 2>/dev/null
find /var/ftp/lpg/deploy -type f -mtime +30 -delete 2>/dev/null

# 一時ファイルの削除
find /tmp -name "lpg-*" -mtime +1 -delete 2>/dev/null

# キャッシュのクリア（必要に応じて）
sync && echo 3 > /proc/sys/vm/drop_caches

echo "[$(date '+%Y-%m-%d %H:%M:%S')] クリーンアップ完了"
EOF

# 5. 設定バックアップスクリプトの作成
cat > /usr/local/bin/config-backup.sh <<'EOF'
#!/bin/bash
# config-backup.sh - Configuration Backup Script
# Version: 1.0.0

CONFIG_FILE="/etc/lpg/config.json"
BACKUP_DIR="/etc/lpg/backups"
MAX_BACKUPS=5

# バックアップディレクトリの作成
mkdir -p "$BACKUP_DIR"

# 現在の設定ファイルのハッシュを取得
if [ -f "$CONFIG_FILE" ]; then
    current_hash=$(sha256sum "$CONFIG_FILE" | awk '{print $1}')
    
    # 最新のバックアップのハッシュを取得
    latest_backup=$(ls -t "$BACKUP_DIR"/config-*.json 2>/dev/null | head -n1)
    if [ -n "$latest_backup" ]; then
        latest_hash=$(sha256sum "$latest_backup" | awk '{print $1}')
    else
        latest_hash=""
    fi
    
    # ハッシュが異なる場合のみバックアップ
    if [ "$current_hash" != "$latest_hash" ]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$CONFIG_FILE" "$BACKUP_DIR/config-${timestamp}.json"
        
        # 古いバックアップを削除（5世代を超える分）
        ls -t "$BACKUP_DIR"/config-*.json | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 設定ファイルをバックアップしました: config-${timestamp}.json"
    fi
fi
EOF

# 6. スクリプトに実行権限を付与
chmod +x /usr/local/bin/lpg-log-rotate.sh
chmod +x /usr/local/bin/lpg-cleanup.sh
chmod +x /usr/local/bin/config-backup.sh
chmod +x /usr/local/bin/backup-lpg.sh
chmod +x /usr/local/bin/lpg-health-check.sh

log "cronジョブの設定が完了しました"

# 7. logrotateの設定（オプション）
cat > /etc/logrotate.d/lpg <<'EOF'
/var/log/lpg/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 lpg lpg
    sharedscripts
    postrotate
        # 必要に応じてサービスにシグナルを送信
        /usr/bin/killall -SIGUSR1 lpg-api 2>/dev/null || true
    endscript
}
EOF

log "logrotate設定が完了しました"

# 8. systemdタイマーの作成（cronの代替として）
cat > /etc/systemd/system/lpg-backup.service <<'EOF'
[Unit]
Description=LPG Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-lpg.sh
User=root
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/lpg-backup.timer <<'EOF'
[Unit]
Description=Run LPG Backup daily
Requires=lpg-backup.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# systemdタイマーの有効化
systemctl daemon-reload
systemctl enable lpg-backup.timer
systemctl start lpg-backup.timer

log "systemdタイマーの設定が完了しました"

# 設定の確認
log "設定された定期タスク:"
echo "  - バックアップ: 毎日午前2時"
echo "  - ログローテーション: 毎日午前3時"
echo "  - ヘルスチェック: 5分ごと"
echo "  - クリーンアップ: 毎週日曜日午前4時"
echo "  - 設定バックアップ: 1時間ごと（変更時のみ）"

log "完了しました！" 