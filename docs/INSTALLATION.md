# LPG インストールガイド

## 前提条件

### ハードウェア要件
- Orange Pi Zero 3
- RAM: 4GB以上
- ストレージ: 16GB以上（microSD）
- ネットワーク: 有線Ethernet

### OSイメージ
- **イメージファイル**: `Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img`
- **ダウンロード元**: Orange Pi公式サイト
- **書き込みツール**: balenaEtcher または dd コマンド

## OSインストール手順

### 1. SDカードへの書き込み

```bash
# macOS/Linuxの場合
sudo dd if=Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img of=/dev/sdX bs=4M status=progress
sync

# WindowsはbalenaEtcherを使用
```

### 2. 初回起動

1. SDカードをOrange Pi Zero 3に挿入
2. Ethernetケーブルを接続
3. 電源を接続
4. 約2分待機（初回起動は時間がかかります）

### 3. SSH接続

```bash
# IPアドレスを確認（ルーターのDHCPリストから）
ssh root@<IPアドレス>
# デフォルトパスワード: orangepi
```

### 4. 初期設定

```bash
# パスワード変更
passwd

# タイムゾーン設定
timedatectl set-timezone Asia/Tokyo

# ホスト名設定
hostnamectl set-hostname lpg

# システム更新
apt update && apt upgrade -y
```

## LPGソフトウェアインストール

### 1. 依存関係のインストール

```bash
# Python環境
apt install -y python3 python3-pip python3-venv

# nginx
apt install -y nginx

# その他必要なパッケージ
apt install -y git curl wget certbot python3-certbot-nginx
```

### 2. Pythonパッケージのインストール

```bash
# Flask関連
pip3 install flask werkzeug
pip3 install flask-cors
```

### 3. LPGのディレクトリ構成作成

```bash
# ディレクトリ作成
mkdir -p /opt/lpg/{src,backups,logs}
mkdir -p /opt/lpg/src/templates

# 権限設定
chown -R root:root /opt/lpg
chmod -R 755 /opt/lpg
```

### 4. LPGファイルの配置

```bash
# ソースコードをコピー（例：SCPを使用）
scp lpg_admin.py root@192.168.234.2:/opt/lpg/src/
scp -r templates/* root@192.168.234.2:/opt/lpg/src/templates/
scp config.json root@192.168.234.2:/opt/lpg/src/
scp devices.json root@192.168.234.2:/opt/lpg/src/
```

### 5. nginx設定

```bash
# SSL証明書の取得（DDNSが設定済みの場合）
certbot certonly --nginx -d akb001yebraxfqsm9y.dyndns-web.com

# nginx設定ファイル作成
cat > /etc/nginx/sites-available/lpg-ssl << 'EOF'
server {
    listen 443 ssl;
    server_name akb001yebraxfqsm9y.dyndns-web.com;

    ssl_certificate /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/privkey.pem;

    location /lpg-admin/ {
        proxy_pass http://127.0.0.1:8443/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        rewrite ^/lpg-admin/lpg-admin/(.*)$ /lpg-admin/$1 permanent;
        
        proxy_redirect / /lpg-admin/;
        proxy_redirect http://127.0.0.1:8443/ /lpg-admin/;
        proxy_redirect https://127.0.0.1:8443/ https://$host/lpg-admin/;
    }
}

server {
    listen 80;
    server_name akb001yebraxfqsm9y.dyndns-web.com;
    return 301 https://$server_name$request_uri;
}
EOF

# 設定を有効化
ln -s /etc/nginx/sites-available/lpg-ssl /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 6. systemdサービス設定

```bash
# サービスファイル作成
cat > /etc/systemd/system/lpg-admin.service << 'EOF'
[Unit]
Description=LPG Admin UI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lpg/src
ExecStart=/usr/bin/python3 /opt/lpg/src/lpg_admin.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/lpg_admin.log
StandardError=append:/var/log/lpg_admin.log

[Install]
WantedBy=multi-user.target
EOF

# サービス有効化
systemctl daemon-reload
systemctl enable lpg-admin
systemctl start lpg-admin
```

## 動作確認

### 1. サービス状態確認

```bash
# LPGサービス
systemctl status lpg-admin

# nginx
systemctl status nginx

# ポート確認
netstat -tlnp | grep -E "8443|443|80"
```

### 2. ログ確認

```bash
# LPGログ
tail -f /var/log/lpg_admin.log

# nginxログ
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 3. Webアクセス確認

1. ローカルアクセス: http://192.168.234.2:8443/
2. 外部アクセス: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/
3. ログイン: admin / lpgadmin123

## セキュリティ設定

### 1. ファイアウォール設定

```bash
# UFWのインストールと設定
apt install -y ufw
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8443/tcp  # LPG Admin（ローカルのみ）
ufw --force enable
```

### 2. fail2ban設定

```bash
# fail2banのインストール
apt install -y fail2ban

# LPG用の設定
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
EOF

systemctl restart fail2ban
```

## 自動更新設定

### 1. SSL証明書の自動更新

```bash
# cronジョブ追加
echo "0 0,12 * * * root certbot renew --quiet && systemctl reload nginx" >> /etc/crontab
```

### 2. システムの自動更新

```bash
# unattended-upgradesの設定
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

## バックアップ設定

```bash
# 日次バックアップスクリプト
cat > /opt/lpg/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR="/opt/lpg/backups"
mkdir -p $BACKUP_DIR

# 設定ファイルのバックアップ
tar -czf $BACKUP_DIR/lpg_config_$DATE.tar.gz /opt/lpg/src/*.json /opt/lpg/src/config.py

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "lpg_config_*.tar.gz" -mtime +30 -delete
EOF

chmod +x /opt/lpg/backup.sh

# cronに追加
echo "0 2 * * * root /opt/lpg/backup.sh" >> /etc/crontab
```

## 完了

これでLPGのインストールは完了です。管理UIにアクセスして、デバイスの設定を開始できます。

問題が発生した場合は、トラブルシューティングガイド（TROUBLESHOOTING.md）を参照してください。