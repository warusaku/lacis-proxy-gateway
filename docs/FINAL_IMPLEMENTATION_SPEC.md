# LacisProxyGateway (LPG) 最終実装仕様書

## 1. 概要

LacisProxyGateway (LPG) は、LacisDrawBoardsシステムのリバースプロキシコンポーネントです。本ドキュメントは、2025年8月3日時点での最終実装仕様を記録したものです。

### 1.1 改修の経緯

- LacisDrawBoardsの最終テストにおいて正常な接続が行えない問題が発生
- 原因調査の結果、LPGに実装されていた不要なセキュリティ機能が接続を妨げていることが判明
- セキュリティ機能の削除と管理UI改善を実施
- 改修後、LacisDrawBoardsへのアクセスにおけるLPG起因の問題が解決

## 2. システム構成

### 2.1 ハードウェア
- **デバイス**: Orange Pi Zero 3
- **IPアドレス**: 192.168.234.2
- **OS**: Ubuntu/Debian系Linux

### 2.2 ソフトウェア構成
- **プロキシサーバー**: lpg-proxy.py (Python3)
- **管理UI**: lpg_admin.py (Flask/Werkzeug)
- **Webサーバー**: Nginx (HTTPSターミネーション用)

## 3. 主要機能

### 3.1 リバースプロキシ機能
- HTTPリクエストのルーティング
- ドメインベースのルーティング
- パスベースのルーティング
- ポート転送

### 3.2 管理UI機能
- **認証**: admin/lpgadmin123
- **ダークテーマ**: 全ページで統一されたダークUI
- **トポロジービュー**: SVG形式でドメイン→LPG→デバイスの関係を可視化
- **デバイス管理**: IPグループ化表示、CRUD操作
- **ログビュー**: アクセスログと内部ログの統合表示、JST時刻変換
- **設定管理**: ユーザー管理、Lacis設定、システム設定

## 4. 削除されたセキュリティ機能

以下の機能は接続問題の原因となっていたため削除されました：

1. **過度なアクセス制限**
   - IPアドレスベースの厳格なアクセス制御
   - 不要なヘッダー検証

2. **セッション管理の制限**
   - セッションタイムアウトの短縮設定
   - 複雑なCSRFトークン検証

3. **プロキシヘッダーの過剰な書き換え**
   - X-Forwarded-* ヘッダーの過剰な検証と書き換え

## 5. 現在の設定

### 5.1 プロキシ設定
```json
{
  "hostdomains": {
    "akb001yebraxfqsm9y.dyndns-web.com": "192.168.234.0/24"
  },
  "hostingdevice": {
    "akb001yebraxfqsm9y.dyndns-web.com": {
      "/lacisstack/boards": {
        "deviceip": "192.168.234.10",
        "port": [5173],
        "sitename": "whiteboard-frontend"
      },
      "/lacisstack/boards/api": {
        "deviceip": "192.168.234.10",
        "port": [8080],
        "sitename": "whiteboard-api"
      },
      "/lacisstack/boards/ws": {
        "deviceip": "192.168.234.10",
        "port": [8081],
        "sitename": "whiteboard-ws"
      },
      "/lacisstack/api": {
        "deviceip": "192.168.234.11",
        "port": [3000],
        "sitename": "api-server"
      }
    }
  }
}
```

### 5.2 Nginx設定（HTTPS）
```nginx
server {
    listen 443 ssl;
    server_name akb001yebraxfqsm9y.dyndns-web.com;
    
    ssl_certificate /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/akb001yebraxfqsm9y.dyndns-web.com/privkey.pem;
    
    # アセットの直接配信
    location /assets/ {
        proxy_pass http://localhost:8080/assets/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # メインプロキシ
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 6. 管理UIの改善点

### 6.1 UI/UX改善
- 全画面ダークテーマの実装
- Deploy Changesボタンの配置修正（ヘッダー右側）
- レスポンシブデザインの改善

### 6.2 機能追加
- **トポロジービュー**: 視覚的な接続関係表示
- **ユーザー管理**: 管理者の追加・削除機能
- **Lacis設定**: エンドポイント、ハートビート、ID生成
- **設定エクスポート/インポート**: JSON形式での設定バックアップ

### 6.3 ログ機能改善
- アクセスログと内部ログの統合表示
- JST（日本標準時）への時刻変換機能
- デバイス操作のログ記録

## 7. ファイル構成

```
/root/
├── lpg-proxy.py          # メインプロキシサーバー
├── lpg_admin.py          # 管理UI Flask アプリケーション
├── config.json           # 設定ファイル
├── templates/            # HTMLテンプレート
│   ├── base_dark.html    # ダークテーマベーステンプレート
│   ├── login.html        # ログインページ
│   ├── topology_v2.html  # トポロジービュー
│   ├── devices_grouped.html  # デバイス管理
│   ├── logs_unified.html # ログビュー
│   ├── settings_with_users.html  # 設定ページ
│   └── ...
└── static/               # 静的ファイル（存在する場合）
```

## 8. アクセス方法

### 8.1 管理UI
- URL: http://192.168.234.2:8443
- 認証: admin / lpgadmin123

### 8.2 プロキシ経由のアクセス
- LacisDrawBoards: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/

## 9. 動作確認済み項目

- ✅ HTTPS経由でのLacisDrawBoardsアクセス
- ✅ 静的アセット（CSS/JS）の正常な配信
- ✅ WebSocket接続の確立
- ✅ 管理UIの全機能動作
- ✅ デバイスのCRUD操作
- ✅ ログの記録と表示

## 10. 今後の扱い

本改修により、LPGに起因する接続問題は解決されました。今後、LacisDrawBoardsシステムにおいて接続問題が発生した場合、LPG以外の要因を調査することとします。

---

更新日: 2025年8月3日
作成者: Claude Code Assistant