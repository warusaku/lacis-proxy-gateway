#!/bin/bash
# ftp-deploy-watcher.sh - FTP Upload Auto-Deployment Script
# Version: 1.0.0

UPLOAD_DIR="/var/ftp/lpg/upload"
DEPLOY_DIR="/var/ftp/lpg/deploy"
BACKUP_DIR="/var/ftp/lpg/backup"
LOG_FILE="/var/log/lpg/ftp-deploy.log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# デプロイ関数
deploy_file() {
    local file="$1"
    local filename=$(basename "$file")
    local deploy_path=""
    
    # ファイルタイプによる配置先の決定
    case "$filename" in
        config.json)
            deploy_path="/etc/lpg/config.json"
            ;;
        *.html|*.js|*.css)
            deploy_path="/var/www/html/$filename"
            ;;
        lpg-api)
            deploy_path="/usr/local/bin/lpg-api"
            ;;
        *.sh)
            deploy_path="/usr/local/bin/$filename"
            ;;
        *)
            log "警告: 不明なファイルタイプ: $filename"
            return 1
            ;;
    esac
    
    # バックアップの作成
    if [ -f "$deploy_path" ]; then
        backup_file="$BACKUP_DIR/$(basename $deploy_path).$(date +%Y%m%d_%H%M%S)"
        cp "$deploy_path" "$backup_file"
        log "バックアップ作成: $backup_file"
    fi
    
    # ファイルのデプロイ
    cp "$file" "$deploy_path"
    chmod 644 "$deploy_path"
    
    # 実行権限の付与（必要な場合）
    case "$filename" in
        lpg-api|*.sh)
            chmod +x "$deploy_path"
            ;;
    esac
    
    # デプロイ済みファイルを移動
    mv "$file" "$DEPLOY_DIR/"
    
    log "デプロイ完了: $filename → $deploy_path"
    
    # サービスの再起動（必要な場合）
    case "$filename" in
        config.json)
            log "設定変更を検出。LPGサービスを再起動します..."
            systemctl restart lpg-api
            ;;
        lpg-api)
            log "APIバイナリ更新を検出。サービスを再起動します..."
            systemctl restart lpg-api
            ;;
    esac
    
    return 0
}

# メイン処理
log "FTPデプロイ監視を開始しました"

# inotifywaitがインストールされているか確認
if ! command -v inotifywait &> /dev/null; then
    log "エラー: inotify-toolsがインストールされていません"
    exit 1
fi

# ディレクトリの作成
mkdir -p "$UPLOAD_DIR" "$DEPLOY_DIR" "$BACKUP_DIR"

# ファイル監視ループ
while true; do
    # アップロードディレクトリを監視
    inotifywait -e close_write -e moved_to "$UPLOAD_DIR" 2>/dev/null | while read path action file; do
        if [ -n "$file" ]; then
            log "新しいファイルを検出: $file"
            
            # ファイルが完全にアップロードされるまで待機
            sleep 2
            
            # デプロイ実行
            if [ -f "$UPLOAD_DIR/$file" ]; then
                deploy_file "$UPLOAD_DIR/$file"
            fi
        fi
    done
    
    # エラーで終了した場合は再起動
    log "監視プロセスが終了しました。再起動します..."
    sleep 5
done 