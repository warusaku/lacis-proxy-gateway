#!/bin/bash

# SSH公開鍵認証設定スクリプト
# 作成日: 2025-08-04
# 目的: SSHセキュリティ強化

echo "=== SSH公開鍵認証設定 ==="
echo ""

# 公開鍵を生成（既に存在する場合はスキップ）
if [ ! -f ~/.ssh/id_ed25519_lpg ]; then
    echo "1. SSH鍵ペアを生成..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_lpg -N "" -C "lpg-admin@lacis"
else
    echo "1. 既存のSSH鍵を使用"
fi

# 公開鍵を表示
echo ""
echo "2. 公開鍵:"
cat ~/.ssh/id_ed25519_lpg.pub

# リモートサーバーに公開鍵を設定
echo ""
echo "3. 公開鍵をLPGサーバーに転送..."

expect << 'EOF'
set timeout 30

spawn ssh-copy-id -i ~/.ssh/id_ed25519_lpg.pub root@192.168.234.2

expect {
    "password:" {
        send "orangepi\r"
        exp_continue
    }
    "Number of key(s) added:" {
        puts "\n公開鍵が正常に追加されました"
    }
    "already exist" {
        puts "\n公開鍵は既に登録されています"
    }
}
EOF

# SSH設定を更新
echo ""
echo "4. SSH設定ファイルを更新..."

cat >> ~/.ssh/config << 'SSH_CONFIG'

# LPG Server
Host lpg
    HostName 192.168.234.2
    User root
    IdentityFile ~/.ssh/id_ed25519_lpg
    StrictHostKeyChecking no
SSH_CONFIG

# 公開鍵認証でテスト接続
echo ""
echo "5. 公開鍵認証でテスト接続..."
ssh lpg 'echo "公開鍵認証成功！" && uname -a'

# サーバー側のSSH設定を強化
echo ""
echo "6. サーバー側のSSH設定を強化..."

ssh lpg << 'REMOTE_SSH'
# SSHDの設定をバックアップ
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

# セキュリティ設定を適用
cat > /etc/ssh/sshd_config.d/99-security.conf << 'SSHD_CONFIG'
# 公開鍵認証を有効化
PubkeyAuthentication yes

# パスワード認証を無効化（公開鍵のみ）
PasswordAuthentication no

# rootログインを公開鍵のみ許可
PermitRootLogin prohibit-password

# 空パスワードを拒否
PermitEmptyPasswords no

# チャレンジレスポンス認証を無効化
ChallengeResponseAuthentication no

# X11転送を無効化
X11Forwarding no

# 最大認証試行回数
MaxAuthTries 3

# ログイングレースタイム
LoginGraceTime 30
SSHD_CONFIG

# SSH設定をテスト
sshd -t && echo "SSH設定テスト: OK"

# SSHサービスを再起動
systemctl restart sshd
echo "SSHサービスを再起動しました"
REMOTE_SSH

echo ""
echo "=== SSH公開鍵認証設定完了 ==="
echo ""
echo "接続方法:"
echo "  ssh lpg"
echo "または:"
echo "  ssh -i ~/.ssh/id_ed25519_lpg root@192.168.234.2"
echo ""
echo "セキュリティ設定:"
echo "- パスワード認証: 無効"
echo "- 公開鍵認証: 有効"
echo "- rootログイン: 公開鍵のみ"