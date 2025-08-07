# LacisProxyGateway (LPG) v1.0

## 概要

LacisProxyGateway (LPG) は、LACIS エコシステムのためのリバースプロキシおよび管理インターフェースシステムです。複数のバックエンドサービスへのルーティング、デバイス管理、ネットワーク監視、ログ管理などの機能を提供します。

## バージョン情報

- **Version**: 1.0
- **Release Date**: 2025-08-05
- **Status**: Production Ready

## 主な機能

### 1. リバースプロキシ機能
- パスベースのルーティング
- ドメインベースのルーティング
- WebSocketサポート
- SSL/TLS終端

### 2. Web管理UI
- **統一されたダークテーマUI**
- トポロジービジュアライゼーション（D3.js）
- デバイス管理（CRUD操作）
- ドメイン管理
- ネットワーク監視
- リアルタイムログビューア
- システム設定管理

### 3. 外部アクセスサポート
- HTTPS経由の安全なアクセス
- プロキシプレフィックス対応（/lpg-admin/）
- 正しいURL生成とナビゲーション

## システム要件

- Python 3.8以上
- Flask 2.0以上
- nginx 1.18以上
- SSL証明書（Let's Encrypt推奨）

## インストール

### 1. 依存関係のインストール

```bash
pip3 install flask werkzeug
```

### 2. ディレクトリ構成

```
/opt/lpg/
├── src/
│   ├── lpg_admin.py         # メインFlaskアプリケーション
│   ├── lpg_server.py        # プロキシサーバー
│   ├── config.json          # プロキシ設定
│   ├── devices.json         # デバイス情報
│   ├── config.py           # Flask設定
│   └── templates/          # HTMLテンプレート
│       ├── base_unified.html
│       ├── home_unified.html
│       ├── topology_unified.html
│       ├── domains_unified.html
│       ├── devices_unified.html
│       ├── network_unified.html
│       ├── logs_unified.html
│       ├── settings_unified.html
│       └── login_unified.html
├── backups/               # バックアップディレクトリ
└── logs/                  # ログファイル
```

### 3. nginx設定

`/etc/nginx/sites-available/lpg-ssl`:

```nginx
server {
    listen 443 ssl;
    server_name akb001yebraxfqsm9y.dyndns-web.com;

    ssl_certificate /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/privkey.pem;

    # LPG Admin UI
    location /lpg-admin/ {
        proxy_pass http://127.0.0.1:8443/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # Remove duplicate /lpg-admin prefix
        rewrite ^/lpg-admin/lpg-admin/(.*)$ /lpg-admin/$1 permanent;
        
        # Handle redirects
        proxy_redirect / /lpg-admin/;
        proxy_redirect http://127.0.0.1:8443/ /lpg-admin/;
        proxy_redirect https://127.0.0.1:8443/ https://$host/lpg-admin/;
    }
}
```

## 起動方法

### 1. LPG管理UIの起動

```bash
cd /opt/lpg/src
python3 lpg_admin.py
```

デフォルトでポート8443で起動します。

### 2. アクセス

- **ローカルアクセス**: http://192.168.234.2:8443/
- **外部アクセス**: https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/

### 3. デフォルト認証情報

- **ユーザー名**: admin
- **パスワード**: lpgadmin123

## API エンドポイント

### デバイス管理API

- `GET /api/devices` - デバイス一覧取得
- `POST /api/devices` - デバイス追加
- `PUT /api/device/<device_id>` - デバイス更新
- `DELETE /api/device/<device_id>` - デバイス削除
- `GET /api/device/<device_id>/ping` - デバイスping確認

### ドメイン管理API

- `GET /api/domains` - ドメイン一覧取得
- `POST /api/domains` - ドメイン追加
- `DELETE /api/domain/<domain_name>` - ドメイン削除

### システム管理API

- `GET /api/metrics` - システムメトリクス取得
- `GET /api/logs` - システムログ取得
- `POST /api/restart-proxy` - プロキシ再起動

## セキュリティ機能

1. **セッション管理**
   - セキュアなセッションCookie
   - HTTPOnly属性
   - セッションタイムアウト

2. **SSL/TLS**
   - Let's Encrypt証明書
   - HTTPS強制リダイレクト

3. **認証**
   - ログイン必須
   - セッションベース認証

## トラブルシューティング

### 502 Bad Gateway エラー

nginxがLPGに接続できない場合に発生します。

解決方法：
1. LPGが起動しているか確認: `ps aux | grep lpg_admin`
2. ポート8443が使用されているか確認: `netstat -tlnp | grep 8443`
3. LPGを再起動: `pkill -f lpg_admin.py && python3 lpg_admin.py`

### URL重複問題

`/lpg-admin/lpg-admin/` のようなURL重複が発生する場合、nginx設定のrewriteルールを確認してください。

### サイドバーナビゲーション問題

外部URLからアクセス時にサイドバーのリンクが動作しない場合、テンプレートのhref属性が正しいプレフィックスを含んでいるか確認してください。

## 更新履歴

### v1.0 (2025-08-05)
- 統一されたダークテーマUI実装
- 外部URLアクセスサポート追加
- ProxyFix対応
- サイドバーナビゲーション修正
- 全ページの動作確認完了

## ライセンス

LACIS System専用ソフトウェア

## サポート

問題や質問がある場合は、LACISシステム管理者に連絡してください。