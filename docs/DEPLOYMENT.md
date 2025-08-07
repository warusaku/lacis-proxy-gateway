# LPG デプロイメントガイド

## デプロイメント環境

- **ホスト**: Orange Pi Zero 3
- **IP**: 192.168.234.2
- **OS**: Orange Pi 1.0.2 Jammy
- **Python**: 3.10+
- **nginx**: 1.18.0

## ディレクトリ構成

```
/opt/lpg/
├── src/                    # アプリケーションソース
│   ├── lpg_admin.py       # Flask管理UI
│   ├── templates/         # HTMLテンプレート
│   ├── config.json        # プロキシ設定
│   ├── devices.json       # デバイス情報
│   └── config.py          # Flask設定
├── backups/               # バックアップ
│   └── v1.0_YYYYMMDD/    # バージョンバックアップ
└── logs/                  # ログファイル
```

## デプロイメント手順

### 1. 初期セットアップ

```bash
# ディレクトリ作成
sudo mkdir -p /opt/lpg/{src,backups,logs}
sudo chown -R $USER:$USER /opt/lpg

# 依存関係インストール
sudo apt update
sudo apt install python3-pip nginx
pip3 install flask werkzeug
```

### 2. ファイル配置

```bash
# ソースコードをコピー
cp lpg_admin.py /opt/lpg/src/
cp -r templates/ /opt/lpg/src/
cp config.json /opt/lpg/src/
cp devices.json /opt/lpg/src/
```

### 3. nginx設定

```bash
# SSL証明書取得（Let's Encrypt）
sudo certbot certonly --nginx -d akb001yebraxfqsm9y.dyndns-web.com

# nginx設定ファイル作成
sudo nano /etc/nginx/sites-available/lpg-ssl
# （設定内容は README.md 参照）

# 設定を有効化
sudo ln -s /etc/nginx/sites-available/lpg-ssl /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 4. システムサービス設定

```bash
# systemdサービスファイル作成
sudo nano /etc/systemd/system/lpg-admin.service
```

```ini
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

[Install]
WantedBy=multi-user.target
```

```bash
# サービス有効化
sudo systemctl daemon-reload
sudo systemctl enable lpg-admin
sudo systemctl start lpg-admin
```

## アップデート手順

### 1. バックアップ作成

```bash
cd /opt/lpg/src
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p /opt/lpg/backups/pre_update_${DATE}
cp -r * /opt/lpg/backups/pre_update_${DATE}/
```

### 2. 新しいファイルをデプロイ

```bash
# ローカルから転送
scp -r src/* root@192.168.234.2:/opt/lpg/src/
```

### 3. サービス再起動

```bash
sudo systemctl restart lpg-admin
sudo systemctl status lpg-admin
```

### 4. 動作確認

```bash
# ヘルスチェック
curl -s http://localhost:8443/api/health

# ログ確認
tail -f /var/log/lpg_admin.log
```

## バックアップとリストア

### バックアップ

```bash
# フルバックアップ
cd /opt/lpg
tar -czf lpg_backup_$(date +%Y%m%d).tar.gz src/ backups/

# 設定のみバックアップ
cd /opt/lpg/src
tar -czf config_backup_$(date +%Y%m%d).tar.gz *.json config.py
```

### リストア

```bash
# バックアップから復元
cd /opt/lpg
tar -xzf lpg_backup_YYYYMMDD.tar.gz

# 特定バージョンから復元
cp -r /opt/lpg/backups/v1.0_YYYYMMDD/* /opt/lpg/src/

# サービス再起動
sudo systemctl restart lpg-admin
```

## モニタリング

### ログ確認

```bash
# アプリケーションログ
tail -f /var/log/lpg_admin.log

# nginxアクセスログ
tail -f /var/log/nginx/access.log

# nginxエラーログ
tail -f /var/log/nginx/error.log
```

### プロセス確認

```bash
# LPGプロセス
ps aux | grep lpg_admin

# ポート確認
netstat -tlnp | grep 8443
```

### システムリソース

```bash
# CPU/メモリ使用率
htop

# ディスク使用量
df -h

# ネットワーク接続
ss -tulpn
```

## トラブルシューティング

### サービスが起動しない

1. ログ確認
```bash
journalctl -u lpg-admin -n 50
```

2. 手動起動でエラー確認
```bash
cd /opt/lpg/src
python3 lpg_admin.py
```

3. ポート競合確認
```bash
lsof -i :8443
```

### nginx 502エラー

1. LPGサービス確認
```bash
systemctl status lpg-admin
```

2. nginx設定確認
```bash
nginx -t
```

3. プロキシ先確認
```bash
curl -v http://127.0.0.1:8443/
```

## セキュリティ推奨事項

1. **定期的なバックアップ**
   - 週次でフルバックアップ
   - 日次で設定バックアップ

2. **SSL証明書の更新**
   - Let's Encryptの自動更新設定
   - 証明書期限の監視

3. **アクセス制限**
   - 管理UIへのIPアドレス制限
   - fail2ban設定

4. **ログ監視**
   - 異常なアクセスパターンの検出
   - エラーログの定期確認