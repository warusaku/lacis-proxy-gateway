#!/bin/bash
# lpg-health-check.sh - LPG Health Check Script
# Version: 1.0.0
# Description: LPGサービスの健全性をチェックし、JSON形式で結果を出力

# 現在時刻
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 結果を格納する変数
HEALTH_STATUS="healthy"
HEALTH_SCORE=100
ISSUES=()

# Caddyのチェック
check_caddy() {
    if curl -sf http://localhost:2019/config/ > /dev/null; then
        CADDY_STATUS="running"
    else
        CADDY_STATUS="down"
        HEALTH_STATUS="unhealthy"
        HEALTH_SCORE=$((HEALTH_SCORE - 30))
        ISSUES+=("Caddy admin API is not responding")
    fi
}

# LPG APIのチェック
check_lpg_api() {
    if curl -sfk https://localhost:8443/api/v1/health > /dev/null; then
        API_STATUS="running"
    else
        API_STATUS="down"
        HEALTH_STATUS="unhealthy"
        HEALTH_SCORE=$((HEALTH_SCORE - 30))
        ISSUES+=("LPG API is not responding")
    fi
}

# vsftpdのチェック
check_vsftpd() {
    if pgrep vsftpd > /dev/null; then
        VSFTPD_STATUS="running"
    else
        VSFTPD_STATUS="down"
        HEALTH_STATUS="warning"
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
        ISSUES+=("vsftpd is not running")
    fi
}

# 設定ファイルのチェック
check_config() {
    CONFIG_FILE="/etc/lpg/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
            CONFIG_STATUS="valid"
        else
            CONFIG_STATUS="invalid"
            HEALTH_STATUS="unhealthy"
            HEALTH_SCORE=$((HEALTH_SCORE - 20))
            ISSUES+=("config.json is invalid JSON")
        fi
    else
        CONFIG_STATUS="missing"
        HEALTH_STATUS="unhealthy"
        HEALTH_SCORE=$((HEALTH_SCORE - 40))
        ISSUES+=("config.json is missing")
    fi
}

# ディスク使用量のチェック
check_disk_usage() {
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        HEALTH_STATUS="critical"
        HEALTH_SCORE=$((HEALTH_SCORE - 25))
        ISSUES+=("Disk usage is critical: ${DISK_USAGE}%")
    elif [ "$DISK_USAGE" -gt 80 ]; then
        HEALTH_STATUS="warning"
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
        ISSUES+=("Disk usage is high: ${DISK_USAGE}%")
    fi
}

# メモリ使用量のチェック
check_memory_usage() {
    MEMORY_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
    if [ "$MEMORY_USAGE" -gt 90 ]; then
        HEALTH_STATUS="critical"
        HEALTH_SCORE=$((HEALTH_SCORE - 25))
        ISSUES+=("Memory usage is critical: ${MEMORY_USAGE}%")
    elif [ "$MEMORY_USAGE" -gt 80 ]; then
        HEALTH_STATUS="warning"
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
        ISSUES+=("Memory usage is high: ${MEMORY_USAGE}%")
    fi
}

# ログファイルサイズのチェック
check_log_sizes() {
    LOG_DIR="/var/log/lpg"
    TOTAL_SIZE=$(du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}')
    
    # 個別の大きなログファイルをチェック
    find "$LOG_DIR" -type f -size +100M | while read -r file; do
        SIZE=$(du -h "$file" | awk '{print $1}')
        FILENAME=$(basename "$file")
        ISSUES+=("Large log file: $FILENAME ($SIZE)")
        HEALTH_SCORE=$((HEALTH_SCORE - 5))
    done
}

# チェックを実行
check_caddy
check_lpg_api
check_vsftpd
check_config
check_disk_usage
check_memory_usage
check_log_sizes

# スコアの最小値を0に
if [ $HEALTH_SCORE -lt 0 ]; then
    HEALTH_SCORE=0
fi

# ステータスの最終決定
if [ $HEALTH_SCORE -lt 50 ]; then
    HEALTH_STATUS="critical"
elif [ $HEALTH_SCORE -lt 70 ]; then
    HEALTH_STATUS="unhealthy"
elif [ $HEALTH_SCORE -lt 90 ]; then
    HEALTH_STATUS="warning"
fi

# JSON形式で出力
cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$HEALTH_STATUS",
  "score": $HEALTH_SCORE,
  "services": {
    "caddy": "$CADDY_STATUS",
    "lpg_api": "$API_STATUS",
    "vsftpd": "$VSFTPD_STATUS"
  },
  "config": "$CONFIG_STATUS",
  "resources": {
    "disk_usage": $DISK_USAGE,
    "memory_usage": $MEMORY_USAGE
  },
  "issues": [
EOF

# 問題のリストを出力
FIRST=true
for issue in "${ISSUES[@]}"; do
    if [ "$FIRST" = true ]; then
        echo -n "    \"$issue\""
        FIRST=false
    else
        echo ","
        echo -n "    \"$issue\""
    fi
done

echo ""
echo "  ]"
echo "}" 