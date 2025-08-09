# LPG 設定ガイド

## 目次
1. [初期設定](#初期設定)
2. [プロキシ設定](#プロキシ設定)  
3. [デバイス設定](#デバイス設定)
4. [ネットワーク設定](#ネットワーク設定)
5. [セキュリティ設定](#セキュリティ設定)
6. [環境変数](#環境変数)
7. [設定ファイルの詳細](#設定ファイルの詳細)

## 初期設定

### 管理者アカウント

初回ログイン時のデフォルト認証情報:
- **ユーザー名**: admin
- **パスワード**: lpgadmin123

**重要**: セキュリティのため、初回ログイン後すぐにパスワードを変更してください。

### タイムゾーン設定

```bash
# システムのタイムゾーンを設定
sudo timedatectl set-timezone Asia/Tokyo

# 確認
timedatectl status
```

## プロキシ設定

### config.json の構造

```json
{
  "hostdomains": {
    "ドメイン名": {
      "パス": {
        "proxy_url": "プロキシ先URL",
        "headers": {
          "ヘッダー名": "値"
        },
        "timeout": タイムアウト秒数,
        "retry": リトライ回数
      }
    }
  }
}
```

### 設定例

```json
{
  "hostdomains": {
    "akb001yebraxfqsm9y.dyndns-web.com": {
      "/lacisstack/boards/": {
        "proxy_url": "http://192.168.234.10:8080",
        "headers": {
          "X-Real-IP": "$remote_addr",
          "X-Forwarded-For": "$proxy_add_x_forwarded_for",
          "X-Forwarded-Proto": "$scheme",
          "Host": "$host"
        },
        "timeout": 30,
        "retry": 3
      },
      "/api/": {
        "proxy_url": "http://192.168.234.10:8081",
        "headers": {
          "X-Real-IP": "$remote_addr",
          "X-Forwarded-For": "$proxy_add_x_forwarded_for"
        }
      }
    },
    "subdomain.example.com": {
      "/": {
        "proxy_url": "http://192.168.234.20:3000",
        "headers": {}
      }
    }
  }
}
```

### パスベースルーティングのルール

1. **最長一致優先**: より具体的なパスが優先されます
   - `/api/v1/users` は `/api/` より優先
   - `/lacisstack/boards/api` は `/lacisstack/boards/` より優先

2. **トレイリングスラッシュ**: パスの末尾のスラッシュは重要です
   - `/api/` : `/api/xxx` にマッチ
   - `/api` : `/api` のみにマッチ

3. **大文字小文字の区別**: パスは大文字小文字を区別します

## デバイス設定

### devices.json の構造

```json
{
  "devices": [
    {
      "id": "一意のID",
      "name": "デバイス名",
      "ip": "IPアドレス",
      "port": ポート番号,
      "path": "パス",
      "type": "デバイスタイプ",
      "status": "ステータス",
      "description": "説明",
      "access_count": アクセス数
    }
  ]
}
```

### デバイスタイプ

- `server`: サーバー
- `application`: アプリケーション
- `database`: データベース
- `storage`: ストレージ
- `network`: ネットワーク機器

### ステータス

- `active`: アクティブ
- `inactive`: 非アクティブ
- `maintenance`: メンテナンス中
- `error`: エラー

### 設定例

```json
{
  "devices": [
    {
      "id": "device1",
      "name": "OrangePi 5 Plus",
      "ip": "192.168.234.10",
      "port": 8080,
      "path": "/lacisstack/boards/",
      "type": "server",
      "status": "active",
      "description": "Main server hosting all services",
      "access_count": 0
    },
    {
      "id": "device2",
      "name": "PostgreSQL DB",
      "ip": "192.168.234.10",
      "port": 5432,
      "path": "/",
      "type": "database",
      "status": "active",
      "description": "Main database server",
      "access_count": 0
    }
  ]
}
```

## ネットワーク設定

### IPアドレス設定

```bash
# 固定IPの設定（NetworkManager使用）
sudo nmcli con mod "Wired connection 1" \
  ipv4.addresses 192.168.234.2/24 \
  ipv4.gateway 192.168.234.1 \
  ipv4.dns "8.8.8.8,8.8.4.4" \
  ipv4.method manual

# 設定の適用
sudo nmcli con down "Wired connection 1"
sudo nmcli con up "Wired connection 1"
```

### VLAN設定

**⚠️ 重要な注意事項**

LPGをVLAN環境で使用する場合、以下の点に注意してください:

1. **バインドアドレス**: 必ず127.0.0.1を使用
2. **ポート競合**: VLANインターフェースとのポート競合を避ける
3. **ARPテーブル**: 異常なARPブロードキャストを監視

```bash
# VLAN設定例（VLAN ID: 555）
sudo nmcli con add type vlan \
  con-name vlan555 \
  dev eth0 \
  id 555 \
  ipv4.addresses 192.168.234.2/24 \
  ipv4.gateway 192.168.234.1 \
  ipv4.method manual
```

## セキュリティ設定

### バインドアドレスの設定

**🚨 最重要設定**

```bash
# systemdサービスファイルで必ず設定
Environment="LPG_ADMIN_HOST=127.0.0.1"  # 絶対に0.0.0.0にしない！
Environment="LPG_PROXY_HOST=127.0.0.1"  # 絶対に0.0.0.0にしない！
```

### SSL/TLS設定

```bash
# Let's Encryptの設定
sudo certbot certonly --nginx \
  -d your-domain.com \
  --email admin@example.com \
  --agree-tos \
  --non-interactive

# 自動更新の設定
sudo certbot renew --dry-run
```

### ファイアウォール設定

```bash
# UFWの基本設定
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 必要なポートのみ開放
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# ローカルネットワークからのアクセス許可
sudo ufw allow from 192.168.234.0/24

# ファイアウォールの有効化
sudo ufw enable
```

### アクセス制限

Nginxでのアクセス制限設定:

```nginx
# IPアドレスによるアクセス制限
location /lpg-admin/ {
    allow 192.168.234.0/24;  # ローカルネットワーク
    allow 10.0.0.0/8;        # プライベートネットワーク
    deny all;                 # その他は拒否
    
    proxy_pass http://127.0.0.1:8443/;
    # ... 他の設定
}
```

## 環境変数

### 必須環境変数

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `LPG_ADMIN_HOST` | 127.0.0.1 | 管理UIのバインドアドレス（変更禁止） |
| `LPG_ADMIN_PORT` | 8443 | 管理UIのポート |
| `LPG_PROXY_HOST` | 127.0.0.1 | プロキシのバインドアドレス（変更禁止） |
| `LPG_PROXY_PORT` | 8080 | プロキシのポート |
| `LPG_LOG_LEVEL` | INFO | ログレベル（DEBUG/INFO/WARNING/ERROR） |
| `LPG_LOG_FILE` | /var/log/lpg_admin.log | ログファイルパス |

### 設定方法

#### systemdサービスでの設定
```ini
[Service]
Environment="LPG_ADMIN_HOST=127.0.0.1"
Environment="LPG_ADMIN_PORT=8443"
Environment="LPG_LOG_LEVEL=INFO"
```

#### シェルでの設定
```bash
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
export LPG_LOG_LEVEL=DEBUG
```

## 設定ファイルの詳細

### ファイル一覧

| ファイル | 場所 | 説明 |
|---------|------|------|
| `config.json` | /opt/lpg/src/ | プロキシルーティング設定 |
| `devices.json` | /opt/lpg/src/ | デバイス情報 |
| `lpg-proxy.service` | /etc/systemd/system/ | プロキシサービス設定 |
| `lpg-admin.service` | /etc/systemd/system/ | 管理UIサービス設定 |
| `lpg-ssl` | /etc/nginx/sites-available/ | Nginx SSL設定 |

### 設定の検証

```bash
# config.jsonの検証
python3 -m json.tool /opt/lpg/src/config.json

# devices.jsonの検証
python3 -m json.tool /opt/lpg/src/devices.json

# Nginx設定の検証
sudo nginx -t
```

### 設定の反映

```bash
# プロキシ設定の反映（自動）
# config.jsonは自動的に読み込まれます

# サービスの再起動が必要な場合
sudo systemctl restart lpg-proxy
sudo systemctl restart lpg-admin

# Nginxの再読み込み
sudo systemctl reload nginx
```

## ベストプラクティス

### 1. 定期的なバックアップ

```bash
# 設定ファイルのバックアップ
sudo cp /opt/lpg/src/config.json /opt/lpg/src/config.json.$(date +%Y%m%d)
sudo cp /opt/lpg/src/devices.json /opt/lpg/src/devices.json.$(date +%Y%m%d)
```

### 2. ログローテーション

```bash
# logrotate設定
sudo cat > /etc/logrotate.d/lpg << 'EOF'
/var/log/lpg*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload lpg-admin >/dev/null 2>&1 || true
    endscript
}
EOF
```

### 3. 監視設定

```bash
# 簡単な監視スクリプト
#!/bin/bash
if ! systemctl is-active --quiet lpg-proxy; then
    echo "LPG Proxy is down!" | mail -s "LPG Alert" admin@example.com
    systemctl start lpg-proxy
fi

if ! systemctl is-active --quiet lpg-admin; then
    echo "LPG Admin is down!" | mail -s "LPG Alert" admin@example.com
    systemctl start lpg-admin
fi
```

## 次のステップ

設定が完了したら、以下のガイドを参照してください:
- [操作ガイド](operation-guide.md)
- [APIエンドポイント](api-endpoints.md)
- [セキュリティガイド](security-guide.md)