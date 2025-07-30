---
title: LacisProxyGateway API仕様書
projects:
- LPG
tags:
- '#proj-lpg'
created: '2025-07-28'
updated: '2025-07-28'
author: unknown
status: draft
---
# LacisProxyGateway API仕様書

**― REST API詳細設計書 ―**  
作成日: 2025-07-26  
バージョン: 1.0.0

---

## 1. API概要

### 1.1 基本情報

| 項目 | 内容 |
|------|------|
| ベースURL | https://192.168.234.2:8443/api |
| プロトコル | HTTPS |
| 認証方式 | Bearer Token (JWT) |
| レスポンス形式 | JSON |
| 文字エンコーディング | UTF-8 |
| APIバージョン | v1 |

### 1.2 共通仕様

#### リクエストヘッダー

```
Authorization: Bearer <jwt_token>
Content-Type: application/json
Accept: application/json
```

#### レスポンス形式

**成功時**:
```json
{
  "status": "success",
  "data": { ... },
  "timestamp": "2025-07-26T12:34:56+09:00"
}
```

**エラー時**:
```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ",
    "details": { ... }
  },
  "timestamp": "2025-07-26T12:34:56+09:00"
}
```

#### HTTPステータスコード

| コード | 説明 |
|--------|------|
| 200 | OK - 正常終了 |
| 201 | Created - リソース作成成功 |
| 204 | No Content - 削除成功 |
| 400 | Bad Request - リクエスト不正 |
| 401 | Unauthorized - 認証エラー |
| 403 | Forbidden - 権限エラー |
| 404 | Not Found - リソース不在 |
| 409 | Conflict - 競合エラー |
| 422 | Unprocessable Entity - 検証エラー |
| 500 | Internal Server Error - サーバーエラー |

---

## 2. 認証関連API

### 2.1 ログイン

**POST** `/api/auth/login`

ユーザー認証を行い、JWTトークンを発行します。

**リクエスト**:
```json
{
  "username": "lacisadmin",
  "password": "password123"
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 86400,
    "expiresAt": "2025-07-27T12:34:56+09:00",
    "requirePasswordChange": false
  }
}
```

**エラー**:
- `INVALID_CREDENTIALS`: 認証情報が無効
- `ACCOUNT_LOCKED`: アカウントロック中

### 2.2 ログアウト

**POST** `/api/auth/logout`

現在のセッションを終了します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "ログアウトしました"
  }
}
```

### 2.3 パスワード変更

**PUT** `/api/auth/password`

ユーザーのパスワードを変更します。

**リクエスト**:
```json
{
  "currentPassword": "oldpassword",
  "newPassword": "newpassword123",
  "confirmPassword": "newpassword123"
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "パスワードを変更しました"
  }
}
```

**エラー**:
- `INVALID_CURRENT_PASSWORD`: 現在のパスワードが無効
- `PASSWORD_MISMATCH`: パスワード確認が一致しない
- `WEAK_PASSWORD`: パスワードが弱い

### 2.4 トークン更新

**POST** `/api/auth/refresh`

JWTトークンを更新します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 86400,
    "expiresAt": "2025-07-27T12:34:56+09:00"
  }
}
```

---

## 3. 設定管理API

### 3.1 設定取得

**GET** `/api/config`

現在の設定を取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "version": "1.0.0",
    "lastModified": "2025-07-26T12:00:00+09:00",
    "config": {
      "hostdomains": { ... },
      "hostingdevice": { ... },
      "adminuser": { ... },
      "endpoint": { ... },
      "options": { ... }
    }
  }
}
```

### 3.2 設定更新

**PUT** `/api/config`

設定を更新します（要Deploy）。

**リクエスト**:
```json
{
  "config": {
    "hostdomains": { ... },
    "hostingdevice": { ... }
  }
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "設定を更新しました",
    "requireDeploy": true
  }
}
```

### 3.3 設定適用

**POST** `/api/config/deploy`

変更した設定を適用します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "設定を適用しました",
    "deployedAt": "2025-07-26T12:34:56+09:00"
  }
}
```

### 3.4 設定ロールバック

**POST** `/api/config/rollback`

前バージョンの設定に戻します。

**リクエスト**:
```json
{
  "version": 2  // 省略時は直前のバージョン
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "設定をロールバックしました",
    "rolledBackTo": 2
  }
}
```

### 3.5 設定履歴取得

**GET** `/api/config/history`

設定変更履歴を取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "history": [
      {
        "version": 3,
        "modifiedAt": "2025-07-26T12:00:00+09:00",
        "modifiedBy": "lacisadmin",
        "changes": ["domains", "devices"]
      }
    ]
  }
}
```

---

## 4. ドメイン管理API

### 4.1 ドメイン一覧取得

**GET** `/api/domains`

登録済みドメインの一覧を取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "domains": [
      {
        "domain": "lacisstack.ath.cx",
        "subnet": "192.168.234.0/24",
        "pathCount": 5,
        "enabled": true,
        "certificate": {
          "issuer": "Let's Encrypt",
          "expiresAt": "2025-10-26T00:00:00Z",
          "status": "valid"
        }
      }
    ]
  }
}
```

### 4.2 ドメイン詳細取得

**GET** `/api/domains/{domain}`

特定ドメインの詳細情報を取得します。

**パラメータ**:
- `domain`: ドメイン名（URLエンコード必須）

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "domain": "lacisstack.ath.cx",
    "subnet": "192.168.234.0/24",
    "paths": [
      {
        "path": "/board",
        "deviceip": "192.168.234.10",
        "port": [8080],
        "sitename": "whiteboard"
      }
    ],
    "statistics": {
      "totalRequests": 12345,
      "last24h": 1234
    }
  }
}
```

### 4.3 ドメイン追加

**POST** `/api/domains`

新規ドメインを追加します。

**リクエスト**:
```json
{
  "domain": "example.com",
  "subnet": "192.168.123.0/24"
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "message": "ドメインを追加しました",
    "domain": "example.com"
  }
}
```

### 4.4 ドメイン更新

**PUT** `/api/domains/{domain}`

ドメイン設定を更新します。

**リクエスト**:
```json
{
  "subnet": "192.168.123.0/24",
  "enabled": true
}
```

### 4.5 ドメイン削除

**DELETE** `/api/domains/{domain}`

ドメインと関連する全ルールを削除します。

---

## 5. デバイス（ルーティング）管理API

### 5.1 ルール一覧取得

**GET** `/api/devices`

全ルーティングルールを取得します。

**クエリパラメータ**:
- `domain`: ドメインでフィルタ
- `sitename`: サイト名でフィルタ

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "rules": [
      {
        "id": "rule_001",
        "domain": "lacisstack.ath.cx",
        "path": "/board",
        "deviceip": "192.168.234.10",
        "port": [8080, 8443],
        "sitename": "whiteboard",
        "ips": ["any"],
        "enabled": true,
        "statistics": {
          "requests24h": 123,
          "lastAccess": "2025-07-26T11:00:00+09:00"
        }
      }
    ]
  }
}
```

### 5.2 ルール追加

**POST** `/api/devices`

新規ルーティングルールを追加します。

**リクエスト**:
```json
{
  "domain": "lacisstack.ath.cx",
  "path": "/app",
  "deviceip": "192.168.234.20",
  "port": [3000],
  "sitename": "webapp",
  "ips": ["192.168.1.0/24", "10.0.0.0/8"]
}
```

### 5.3 ルール更新

**PUT** `/api/devices/{id}`

既存ルールを更新します。

### 5.4 ルール削除

**DELETE** `/api/devices/{id}`

ルールを削除します。

### 5.5 ルール一括インポート

**POST** `/api/devices/import`

JSON形式でルールを一括インポートします。

**リクエスト**:
```json
{
  "rules": [
    { ... },
    { ... }
  ],
  "mode": "merge"  // "merge" or "replace"
}
```

### 5.6 ルール一括エクスポート

**GET** `/api/devices/export`

ルールをJSON形式でエクスポートします。

---

## 6. ログ管理API

### 6.1 アクセスログ取得

**GET** `/api/logs`

アクセスログを取得します。

**クエリパラメータ**:
- `from`: 開始日時（ISO8601）
- `to`: 終了日時（ISO8601）
- `domain`: ドメインフィルタ
- `status`: ステータスコード
- `limit`: 取得件数（デフォルト: 100）
- `offset`: オフセット

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "logs": [
      {
        "timestamp": "2025-07-26T12:34:56+09:00",
        "host": "lacisstack.ath.cx",
        "path": "/board",
        "method": "GET",
        "status": 200,
        "bytes": 12345,
        "duration": 123,
        "ip": "192.168.1.100",
        "userAgent": "Mozilla/5.0...",
        "sitename": "whiteboard"
      }
    ],
    "total": 1234,
    "hasMore": true
  }
}
```

### 6.2 ログストリーム（WebSocket）

**GET** `/api/logs/stream`

WebSocket接続でリアルタイムログを配信します。

**WebSocketメッセージ形式**:
```json
{
  "type": "log",
  "data": {
    "timestamp": "2025-07-26T12:34:56+09:00",
    "host": "lacisstack.ath.cx",
    // ... その他フィールド
  }
}
```

### 6.3 ログ統計取得

**GET** `/api/logs/stats`

ログ統計情報を取得します。

**クエリパラメータ**:
- `period`: 集計期間（hour, day, week, month）
- `domain`: ドメインフィルタ

---

## 7. システム管理API

### 7.1 システム状態取得

**GET** `/api/system/status`

システムの稼働状態を取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "status": "healthy",
    "uptime": 86400,
    "version": "1.0.0",
    "services": {
      "caddy": "running",
      "api": "running",
      "telegraf": "running"
    }
  }
}
```

### 7.2 メトリクス取得

**GET** `/api/system/metrics`

システムメトリクスを取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "cpu": {
      "usage": 15.5,
      "cores": 4
    },
    "memory": {
      "total": 4096,
      "used": 1024,
      "free": 3072,
      "usage": 25.0
    },
    "disk": {
      "total": 32768,
      "used": 8192,
      "free": 24576,
      "usage": 25.0
    },
    "network": {
      "rx_bytes": 1234567890,
      "tx_bytes": 9876543210,
      "rx_rate": 1234.5,
      "tx_rate": 5678.9
    }
  }
}
```

### 7.3 接続テスト

**POST** `/api/system/test`

指定したエンドポイントへの接続をテストします。

**リクエスト**:
```json
{
  "target": "192.168.234.10",
  "port": 8080,
  "timeout": 5
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "reachable": true,
    "responseTime": 15,
    "message": "接続成功"
  }
}
```

### 7.4 バックアップ作成

**POST** `/api/system/backup`

設定のバックアップを作成します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "backupId": "backup_20250726_123456",
    "size": 12345,
    "createdAt": "2025-07-26T12:34:56+09:00"
  }
}
```

### 7.5 バックアップ一覧

**GET** `/api/system/backups`

バックアップ一覧を取得します。

### 7.6 バックアップリストア

**POST** `/api/system/restore`

バックアップから設定を復元します。

**リクエスト**:
```json
{
  "backupId": "backup_20250726_123456"
}
```

---

## 8. Caddy管理API

### 8.1 Caddy設定取得

**GET** `/api/caddy/config`

Caddyの現在の設定を取得します。

### 8.2 証明書一覧取得

**GET** `/api/caddy/certificates`

SSL証明書の一覧と状態を取得します。

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "certificates": [
      {
        "domain": "lacisstack.ath.cx",
        "issuer": "Let's Encrypt",
        "notBefore": "2025-04-26T00:00:00Z",
        "notAfter": "2025-07-26T00:00:00Z",
        "daysRemaining": 30,
        "autoRenew": true
      }
    ]
  }
}
```

### 8.3 証明書更新

**POST** `/api/caddy/certificates/{domain}/renew`

証明書を手動で更新します。

---

## 9. 設定管理API（詳細）

### 9.1 オプション設定取得

**GET** `/api/settings/options`

詳細オプション設定を取得します。

### 9.2 オプション設定更新

**PUT** `/api/settings/options`

詳細オプション設定を更新します。

**リクエスト**:
```json
{
  "websocket_timeout": 600,
  "log_retention_days": 30,
  "session_timeout": 86400
}
```

---

## 10. エラーコード一覧

| コード | 説明 |
|--------|------|
| `INVALID_REQUEST` | リクエスト形式不正 |
| `INVALID_CREDENTIALS` | 認証情報不正 |
| `UNAUTHORIZED` | 認証が必要 |
| `FORBIDDEN` | アクセス権限なし |
| `NOT_FOUND` | リソースが見つからない |
| `CONFLICT` | リソース競合 |
| `VALIDATION_FAILED` | 入力検証エラー |
| `INTERNAL_ERROR` | 内部エラー |
| `SERVICE_UNAVAILABLE` | サービス利用不可 |

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|-----------|------|----------|--------|
| 1.0.0 | 2025-07-26 | 初版作成 | System | 