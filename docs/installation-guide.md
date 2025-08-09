# LPG インストールガイド

## 目次
1. [システム要件](#システム要件)
2. [事前準備](#事前準備)
3. [自動インストール](#自動インストール)
4. [手動インストール](#手動インストール)
5. [ディスクイメージからのインストール](#ディスクイメージからのインストール)
6. [インストール後の設定](#インストール後の設定)
7. [動作確認](#動作確認)

## システム要件

### ハードウェア要件
- **CPU**: ARM64またはx86_64アーキテクチャ
- **RAM**: 最小2GB、推奨4GB以上
- **ストレージ**: 8GB以上の空き容量
- **ネットワーク**: 固定IPアドレス推奨

### ソフトウェア要件
- **OS**: Ubuntu 22.04 LTS以上
- **Python**: 3.10以上
- **Nginx**: 1.18以上
- **systemd**: 245以上

### 推奨環境
- Orange Pi Zero 3 (4GB RAM)
- Ubuntu 22.04 LTS
- 固定IPアドレス環境
- VLAN対応ネットワーク

## 事前準備

### 1. システムの更新
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. 必要なパッケージのインストール
```bash
sudo apt install -y \
    python3 python3-pip \
    nginx \
    git \
    curl \
    net-tools \
    sshpass
```

### 3. Pythonパッケージのインストール
```bash
pip3 install --upgrade pip
pip3 install flask werkzeug requests psutil
```

## 自動インストール

### クイックインストール
```bash
# リポジトリのクローン
git clone https://github.com/warusaku/lacis-proxy-gateway.git
cd lacis-proxy-gateway

# インストールスクリプトの実行
chmod +x install.sh
sudo ./install.sh
```

### インストールスクリプトの動作
1. 依存関係の確認とインストール
2. ディレクトリ構造の作成
3. 設定ファイルの生成
4. systemdサービスの設定
5. Nginx設定の適用
6. 安全機構の初期化

## 手動インストール

### 1. ディレクトリ構造の作成
```bash
sudo mkdir -p /opt/lpg/{src,templates,logs}
sudo mkdir -p /var/log/lpg
```

### 2. ソースコードの配置
```bash
# ソースコードをコピー
sudo cp -r src/* /opt/lpg/src/
sudo cp -r templates/* /opt/lpg/src/templates/

# 実行権限の付与
sudo chmod +x /opt/lpg/src/*.py
sudo chmod +x /opt/lpg/src/*.sh
```

### 3. 設定ファイルの作成

#### config.json
```bash
sudo cat > /opt/lpg/src/config.json << 'EOF'
{
  "hostdomains": {
    "akb001yebraxfqsm9y.dyndns-web.com": {
      "/lacisstack/boards/": {
        "proxy_url": "http://192.168.234.10:8080",
        "headers": {
          "X-Real-IP": "$remote_addr",
          "X-Forwarded-For": "$proxy_add_x_forwarded_for",
          "X-Forwarded-Proto": "$scheme"
        }
      }
    }
  }
}
EOF
```

#### devices.json
```bash
sudo cat > /opt/lpg/src/devices.json << 'EOF'
{
  "devices": [
    {
      "id": "device1",
      "name": "OrangePi 5 Plus",
      "ip": "192.168.234.10",
      "type": "server",
      "status": "active",
      "description": "Main server hosting all services",
      "access_count": 0
    }
  ]
}
EOF
```

### 4. systemdサービスの設定

#### lpg-proxy.service
```bash
sudo cat > /etc/systemd/system/lpg-proxy.service << 'EOF'
[Unit]
Description=LPG Proxy Service
After=network.target

[Service]
Type=simple
User=root
Environment="LPG_PROXY_HOST=127.0.0.1"
Environment="LPG_PROXY_PORT=8080"
ExecStart=/usr/bin/python3 /opt/lpg/src/lpg-proxy.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### lpg-admin.service
```bash
sudo cat > /etc/systemd/system/lpg-admin.service << 'EOF'
[Unit]
Description=LPG Admin Interface (Safe Mode)
After=network.target lpg-proxy.service
Requires=lpg-proxy.service

[Service]
Type=simple
User=root
Environment="LPG_ADMIN_HOST=127.0.0.1"
Environment="LPG_ADMIN_PORT=8443"
ExecStart=/usr/bin/python3 /opt/lpg/src/lpg_safe_wrapper.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 5. サービスの有効化と起動
```bash
# サービスの再読み込み
sudo systemctl daemon-reload

# サービスの有効化
sudo systemctl enable lpg-proxy
sudo systemctl enable lpg-admin

# サービスの起動
sudo systemctl start lpg-proxy
sudo systemctl start lpg-admin
```

## ディスクイメージからのインストール

### 1. ディスクイメージの準備

Orange Pi用の事前設定済みディスクイメージが利用可能です。

#### イメージの入手
```bash
# ディスクイメージはプロジェクトのdiskimageディレクトリに含まれています
ls -la diskimage/
```

### 2. SDカードへの書き込み

#### macOSの場合
```bash
# SDカードのデバイスを確認
diskutil list

# SDカードをアンマウント（例: disk2）
diskutil unmountDisk /dev/disk2

# イメージを書き込み
sudo dd if=diskimage/lpg-orangepi.img of=/dev/rdisk2 bs=1m status=progress

# SDカードを取り出し
diskutil eject /dev/disk2
```

#### Linuxの場合
```bash
# SDカードのデバイスを確認
lsblk

# イメージを書き込み（例: /dev/sdb）
sudo dd if=diskimage/lpg-orangepi.img of=/dev/sdb bs=4M status=progress conv=fsync

# 同期
sync
```

### 3. 初回起動設定

1. SDカードをOrange Piに挿入
2. 電源を接続して起動
3. DHCPで割り当てられたIPアドレスを確認
4. SSHで接続（デフォルト: root/orangepi）
5. ネットワーク設定を固定IPに変更

```bash
# ネットワーク設定
sudo nmcli con mod "Wired connection 1" \
  ipv4.addresses 192.168.234.2/24 \
  ipv4.gateway 192.168.234.1 \
  ipv4.dns 8.8.8.8 \
  ipv4.method manual

# 接続を再起動
sudo nmcli con down "Wired connection 1"
sudo nmcli con up "Wired connection 1"
```

## インストール後の設定

### 1. Nginx設定

```bash
# SSL証明書の設定（Let's Encrypt推奨）
sudo certbot --nginx -d your-domain.com

# Nginx設定ファイルの作成
sudo cat > /etc/nginx/sites-available/lpg-ssl << 'EOF'
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location /lpg-admin/ {
        proxy_pass http://127.0.0.1:8443/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 設定を有効化
sudo ln -s /etc/nginx/sites-available/lpg-ssl /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 2. ファイアウォール設定

```bash
# UFWの設定
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 3. 管理者パスワードの変更

初回ログイン後、管理画面から管理者パスワードを変更してください。

デフォルト認証情報:
- ユーザー名: admin
- パスワード: lpgadmin123

## 動作確認

### 1. サービス状態の確認
```bash
# サービスの状態確認
sudo systemctl status lpg-proxy
sudo systemctl status lpg-admin

# ポートの確認
sudo netstat -tlnp | grep -E '8080|8443'
```

### 2. ログの確認
```bash
# ログファイルの確認
sudo tail -f /var/log/lpg_admin.log
sudo tail -f /var/log/lpg_proxy.log
```

### 3. Web UIへのアクセス

ブラウザで以下のURLにアクセス:
- https://your-domain.com/lpg-admin/

### 4. 安全機構のテスト

**⚠️ 警告: テスト環境でのみ実行してください**

```bash
# 安全機構のテスト
sudo ./test_safety_mechanisms.sh
```

## トラブルシューティング

### サービスが起動しない場合

1. ログを確認
```bash
sudo journalctl -u lpg-proxy -n 50
sudo journalctl -u lpg-admin -n 50
```

2. Pythonパッケージの確認
```bash
pip3 list | grep -E 'flask|werkzeug|requests|psutil'
```

3. ポートの競合確認
```bash
sudo lsof -i :8080
sudo lsof -i :8443
```

### ネットワークエラーの場合

1. バインドアドレスの確認
```bash
grep LPG_ADMIN_HOST /etc/systemd/system/lpg-admin.service
# 必ず127.0.0.1であること
```

2. network_watchdog.pyの状態確認
```bash
ps aux | grep network_watchdog
```

### 緊急復旧手順

```bash
# 全サービスの停止
sudo systemctl stop lpg-admin lpg-proxy

# プロセスの強制終了
sudo pkill -f lpg_admin
sudo pkill -f lpg-proxy

# フラグファイルの削除
sudo rm -f /var/run/lpg_emergency_*

# サービスの再起動
sudo systemctl start lpg-proxy
sudo systemctl start lpg-admin
```

## 次のステップ

インストールが完了したら、以下のガイドを参照してください:
- [設定ガイド](configuration-guide.md)
- [操作ガイド](operation-guide.md)
- [セキュリティガイド](security-guide.md)