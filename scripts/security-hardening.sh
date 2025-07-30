#!/bin/bash
# security-hardening.sh - LPG Security Hardening Script
# Version: 1.0.0
# Description: LPGのセキュリティを強化する設定を適用

set -e

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

log "LPGセキュリティ強化を開始します..."

# 1. システムの更新
log "システムパッケージを更新しています..."
apt-get update && apt-get upgrade -y

# 2. 必要なセキュリティツールのインストール
log "セキュリティツールをインストールしています..."
apt-get install -y \
    fail2ban \
    ufw \
    unattended-upgrades \
    apt-listchanges \
    rkhunter \
    chkrootkit \
    aide

# 3. UFW（Uncomplicated Firewall）の設定
log "ファイアウォールを設定しています..."

# デフォルトポリシー
ufw default deny incoming
ufw default allow outgoing

# 必要なポートのみ許可
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 8443/tcp comment 'LPG Admin UI'
ufw allow 21/tcp comment 'FTP'
ufw allow 30000:30100/tcp comment 'FTP Passive'

# ログ記録を有効化
ufw logging on

# UFWを有効化（非対話的）
echo "y" | ufw enable

# 4. fail2banの設定
log "fail2banを設定しています..."

# LPG用のfail2ban設定
cat > /etc/fail2ban/jail.d/lpg.conf <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[lpg-admin]
enabled = true
port = 8443
logpath = /var/log/lpg/api.log
filter = lpg-admin
maxretry = 3
bantime = 7200

[vsftpd]
enabled = true
port = ftp,ftp-data,30000:30100
logpath = /var/log/lpg/vsftpd.log
maxretry = 3

[caddy-dos]
enabled = true
port = http,https
logpath = /var/log/lpg/caddy.log
filter = caddy-dos
maxretry = 100
findtime = 60
bantime = 600
EOF

# LPG管理UIのフィルター
cat > /etc/fail2ban/filter.d/lpg-admin.conf <<'EOF'
[Definition]
failregex = ^.*Failed login attempt.*from <HOST>.*$
            ^.*Unauthorized access attempt.*from <HOST>.*$
ignoreregex =
EOF

# Caddy DoS攻撃フィルター
cat > /etc/fail2ban/filter.d/caddy-dos.conf <<'EOF'
[Definition]
failregex = ^.*"remote_addr":"<HOST>".*$
ignoreregex =
EOF

# fail2banの再起動
systemctl restart fail2ban

# 5. SSH強化
log "SSH設定を強化しています..."

# SSHの設定をバックアップ
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# SSH設定の強化
cat >> /etc/ssh/sshd_config <<'EOF'

# LPG Security Hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers lacisadmin
X11Forwarding no
UsePAM yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression delayed
EOF

# SSH再起動
systemctl restart sshd

# 6. カーネルパラメータの強化
log "カーネルパラメータを強化しています..."

cat > /etc/sysctl.d/99-lpg-security.conf <<'EOF'
# LPG Security Kernel Parameters

# IPスプーフィング防止
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN攻撃対策
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2

# パケット転送無効化
net.ipv4.ip_forward = 0

# ICMPリダイレクト無効化
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# ソースルーティング無効化
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# ログマーティアン
net.ipv4.conf.all.log_martians = 1

# ICMP無視（オプション）
#net.ipv4.icmp_echo_ignore_all = 1

# TCP FIN タイムアウト
net.ipv4.tcp_fin_timeout = 30

# TCPキープアライブ
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# ファイル記述子の上限
fs.file-max = 65535

# Core dumps無効化
kernel.core_uses_pid = 1
fs.suid_dumpable = 0
EOF

# カーネルパラメータを適用
sysctl -p /etc/sysctl.d/99-lpg-security.conf

# 7. ファイルシステムの権限設定
log "ファイルシステムの権限を設定しています..."

# 重要なディレクトリの権限設定
chmod 700 /etc/lpg
chmod 600 /etc/lpg/config.json
chmod 755 /var/log/lpg
chmod 640 /var/log/lpg/*.log

# setuidビットの確認と記録
find / -perm -4000 -type f 2>/dev/null > /etc/lpg/setuid-files.txt

# 8. 自動セキュリティアップデートの設定
log "自動セキュリティアップデートを設定しています..."

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# 9. セキュリティ監査の設定
log "セキュリティ監査を設定しています..."

# AIDE（ファイル整合性チェック）の初期化
aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# AIDE cronジョブ
cat > /etc/cron.daily/aide-check <<'EOF'
#!/bin/bash
/usr/bin/aide --check | /usr/bin/mail -s "AIDE Report for $(hostname)" root
EOF
chmod +x /etc/cron.daily/aide-check

# 10. ログ監視の強化
log "ログ監視を設定しています..."

# rsyslogの設定
cat >> /etc/rsyslog.conf <<'EOF'

# LPG Security Logging
auth,authpriv.*                 /var/log/lpg/auth.log
*.*;auth,authpriv.none          -/var/log/lpg/syslog
kern.*                          -/var/log/lpg/kern.log
EOF

systemctl restart rsyslog

# 11. プロセス監視
log "プロセス監視を設定しています..."

# 不要なサービスの無効化
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true
systemctl disable avahi-daemon.service 2>/dev/null || true

# 12. セキュリティヘッダーの確認
log "セキュリティヘッダーを確認しています..."

# Caddyfile にセキュリティヘッダーが含まれているか確認
if ! grep -q "X-Content-Type-Options" /etc/caddy/Caddyfile; then
    warn "Caddyfileにセキュリティヘッダーが設定されていません"
fi

# 13. バナーの設定
log "セキュリティバナーを設定しています..."

cat > /etc/issue <<'EOF'
**********************************************************************
*                      AUTHORIZED ACCESS ONLY                        *
*                                                                    *
* This system is for authorized use only. Unauthorized access is     *
* prohibited and will be prosecuted. All activities are monitored.   *
**********************************************************************
EOF

cp /etc/issue /etc/issue.net

# 14. 最終チェック
log "セキュリティ設定を確認しています..."

# 開いているポートの確認
echo "開いているポート:"
ss -tlnp

# fail2banの状態
echo -e "\nfail2banの状態:"
fail2ban-client status

# ファイアウォールの状態
echo -e "\nファイアウォールの状態:"
ufw status verbose

log "セキュリティ強化が完了しました！"
log "システムを再起動することを推奨します。"

# セキュリティレポートの生成
cat > /etc/lpg/security-report.txt <<EOF
LPG Security Hardening Report
Generated: $(date)

1. Firewall: UFW enabled with restrictive rules
2. Fail2ban: Configured for SSH, FTP, and LPG services
3. SSH: Hardened configuration applied
4. Kernel: Security parameters optimized
5. Updates: Automatic security updates enabled
6. Monitoring: AIDE and system logging configured
7. Services: Unnecessary services disabled

Next steps:
- Review /etc/lpg/setuid-files.txt for suspicious files
- Configure SSH key-based authentication
- Consider implementing SELinux/AppArmor
- Regular security audits with rkhunter and chkrootkit
EOF

log "セキュリティレポートを /etc/lpg/security-report.txt に保存しました" 