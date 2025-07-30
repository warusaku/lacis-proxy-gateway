#!/bin/bash
# setup-ftp.sh - LacisProxyGateway FTP Server Setup
# Version: 1.0.0

set -e

echo "=== LacisProxyGateway FTPサーバーセットアップ ==="

# ユーザー作成
if ! id -u lacisadmin >/dev/null 2>&1; then
    echo "lacisadminユーザーを作成しています..."
    useradd -m -d /home/lacisadmin -s /bin/bash lacisadmin
    echo "lacisadmin:lacis12345@" | chpasswd
    usermod -aG lpg lacisadmin
fi

# FTPディレクトリの作成
echo "FTPディレクトリを作成しています..."
mkdir -p /var/ftp/lpg/{upload,backup,deploy}
chown -R lacisadmin:lpg /var/ftp/lpg
chmod -R 755 /var/ftp/lpg

# vsftpdディレクトリの作成
mkdir -p /var/run/vsftpd/empty
chmod 755 /var/run/vsftpd/empty

# SSL証明書の生成（自己署名）
if [ ! -f /etc/ssl/certs/vsftpd.pem ]; then
    echo "SSL証明書を生成しています..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.key \
        -out /etc/ssl/certs/vsftpd.pem \
        -subj "/C=JP/ST=Tokyo/L=Tokyo/O=LacisProxyGateway/CN=lpg.local"
    chmod 600 /etc/ssl/private/vsftpd.key
    chmod 644 /etc/ssl/certs/vsftpd.pem
fi

# vsftpd設定ファイルのコピー
echo "vsftpd設定ファイルをコピーしています..."
cp /etc/lpg/vsftpd/vsftpd.conf /etc/vsftpd.conf
cp /etc/lpg/vsftpd/vsftpd.userlist /etc/vsftpd.userlist

# ログディレクトリの作成
mkdir -p /var/log/lpg
chown -R lpg:lpg /var/log/lpg

# vsftpdの起動
echo "vsftpdサービスを開始しています..."
systemctl enable vsftpd
systemctl restart vsftpd

echo "=== FTPサーバーのセットアップが完了しました ==="
echo "FTPSアクセス情報:"
echo "  ホスト: $(hostname -I | awk '{print $1}')"
echo "  ポート: 21"
echo "  ユーザー: lacisadmin"
echo "  パスワード: lacis12345@"
echo "  プロトコル: FTPS (SSL/TLS必須)" 