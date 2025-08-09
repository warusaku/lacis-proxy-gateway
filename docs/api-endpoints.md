# LPG APIエンドポイント

## 目次
1. [概要](#概要)
2. [認証](#認証)
3. [デバイスAPI](#デバイスapi)
4. [ドメインAPI](#ドメインapi)
5. [ネットワークAPI](#ネットワークapi)
6. [ログAPI](#ログapi)
7. [システムAPI](#システムapi)
8. [エラーレスポンス](#エラーレスポンス)

## 概要

### ベースURL
```
https://your-domain.com/lpg-admin/api/
```

### レスポンス形式
- Content-Type: `application/json`
- 文字エンコーディング: UTF-8

### HTTPメソッド
- `GET`: リソースの取得
- `POST`: リソースの作成
- `PUT`: リソースの更新
- `DELETE`: リソースの削除

## 認証

### ログイン
```http
POST /login
Content-Type: application/x-www-form-urlencoded

username=admin&password=lpgadmin123
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Login successful",
  "redirect": "/lpg-admin/topology"
}
```

### ログアウト
```http
GET /logout
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Logged out successfully",
  "redirect": "/lpg-admin/login"
}
```

### セッション確認
```http
GET /api/session
```

**レスポンス**
```json
{
  "authenticated": true,
  "username": "admin",
  "session_id": "xxx-xxx-xxx",
  "expires": "2025-08-09T10:30:00Z"
}
```

## デバイスAPI

### デバイス一覧取得
```http
GET /api/devices
```

**レスポンス**
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
      "access_count": 42
    }
  ]
}
```

### デバイス詳細取得
```http
GET /api/device/<device_id>
```

**パラメータ**
- `device_id`: デバイスID（パス内）

**レスポンス**
```json
{
  "id": "device1",
  "name": "OrangePi 5 Plus",
  "ip": "192.168.234.10",
  "port": 8080,
  "path": "/lacisstack/boards/",
  "type": "server",
  "status": "active",
  "description": "Main server hosting all services",
  "access_count": 42,
  "created_at": "2025-08-01T10:00:00Z",
  "updated_at": "2025-08-09T08:30:00Z"
}
```

### デバイス追加
```http
POST /api/device
Content-Type: application/json

{
  "name": "New Device",
  "description": "Device description",
  "ip": "192.168.234.20",
  "port": 3000,
  "path": "/app/",
  "domain_name": "example.com",
  "type": "application"
}
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Device added successfully",
  "device_id": "device_xxx"
}
```

### デバイス更新
```http
PUT /api/device/<device_id>
Content-Type: application/json

{
  "name": "Updated Device Name",
  "description": "Updated description",
  "ip": "192.168.234.21",
  "port": 3001,
  "path": "/newapp/",
  "domain_name": "newdomain.com",
  "type": "server"
}
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Device updated successfully"
}
```

### デバイス削除
```http
DELETE /api/device/<device_id>
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Device deleted successfully"
}
```

### デバイスPing
```http
GET /api/device/<device_id>/ping
```

**レスポンス**
```json
{
  "status": "success",
  "device_id": "device1",
  "ip_address": "192.168.234.10",
  "is_alive": true,
  "response_time": 1.234,
  "timestamp": "2025-08-09T10:30:00Z"
}
```

### アクセス数増加
```http
POST /api/device/<device_id>/increment-access
```

**レスポンス**
```json
{
  "status": "success",
  "device_id": "device1",
  "access_count": 43
}
```

## ドメインAPI

### ドメイン一覧取得
```http
GET /api/domains
```

**レスポンス**
```json
{
  "domains": [
    {
      "domain": "akb001yebraxfqsm9y.dyndns-web.com",
      "paths": [
        {
          "path": "/lacisstack/boards/",
          "proxy_url": "http://192.168.234.10:8080",
          "headers": {
            "X-Real-IP": "$remote_addr",
            "X-Forwarded-For": "$proxy_add_x_forwarded_for"
          }
        }
      ]
    }
  ]
}
```

### ドメイン追加
```http
POST /api/domain
Content-Type: application/json

{
  "domain": "new.example.com",
  "path": "/api/",
  "proxy_url": "http://192.168.234.30:8080",
  "headers": {}
}
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Domain configuration added"
}
```

### ドメイン削除
```http
DELETE /api/domain/<domain>/<path>
```

**パラメータ**
- `domain`: ドメイン名（URLエンコード必要）
- `path`: パス（URLエンコード必要）

**レスポンス**
```json
{
  "status": "success",
  "message": "Domain configuration deleted"
}
```

## ネットワークAPI

### ネットワーク統計取得
```http
GET /api/network/stats
```

**レスポンス**
```json
{
  "interfaces": [
    {
      "name": "eth0",
      "ip_address": "192.168.234.2",
      "mac_address": "xx:xx:xx:xx:xx:xx",
      "bytes_sent": 1234567890,
      "bytes_recv": 9876543210,
      "packets_sent": 123456,
      "packets_recv": 654321,
      "errin": 0,
      "errout": 0,
      "dropin": 0,
      "dropout": 0
    }
  ],
  "total_bytes_sent": 1234567890,
  "total_bytes_recv": 9876543210,
  "bandwidth_usage": 65
}
```

### アクティブ接続取得
```http
GET /api/network/connections
```

**レスポンス**
```json
{
  "connections": [
    {
      "local_address": "192.168.234.2:8080",
      "remote_address": "192.168.234.10:45678",
      "status": "ESTABLISHED",
      "pid": 1234,
      "program": "lpg-proxy.py"
    }
  ],
  "total_connections": 15,
  "connections_by_status": {
    "ESTABLISHED": 10,
    "TIME_WAIT": 3,
    "LISTEN": 2
  }
}
```

## ログAPI

### ログ取得
```http
GET /api/logs?type=access&limit=100&offset=0
```

**クエリパラメータ**
- `type`: ログタイプ（access/system/audit）
- `limit`: 取得件数（デフォルト: 100）
- `offset`: オフセット（デフォルト: 0）
- `start_date`: 開始日時（ISO 8601形式）
- `end_date`: 終了日時（ISO 8601形式）
- `level`: ログレベル（DEBUG/INFO/WARNING/ERROR）
- `search`: 検索キーワード

**レスポンス**
```json
{
  "logs": [
    {
      "timestamp": "2025-08-09T10:30:00Z",
      "level": "INFO",
      "source": "lpg-proxy",
      "message": "Proxy request: GET /api/data",
      "details": {
        "ip": "192.168.234.10",
        "method": "GET",
        "path": "/api/data",
        "status": 200,
        "response_time": 0.123
      }
    }
  ],
  "total": 1234,
  "offset": 0,
  "limit": 100
}
```

### ログクリア
```http
DELETE /api/logs?type=access&older_than=30
```

**クエリパラメータ**
- `type`: ログタイプ
- `older_than`: 日数（この日数より古いログを削除）

**レスポンス**
```json
{
  "status": "success",
  "message": "Logs cleared",
  "deleted_count": 500
}
```

## システムAPI

### システム情報取得
```http
GET /api/system/info
```

**レスポンス**
```json
{
  "version": "2.0.0",
  "uptime": "5 days 3 hours 20 minutes",
  "hostname": "lpg-server",
  "os": "Ubuntu 22.04 LTS",
  "python_version": "3.10.12",
  "memory": {
    "total": 4294967296,
    "used": 2147483648,
    "free": 2147483648,
    "percent": 50.0
  },
  "cpu": {
    "count": 4,
    "percent": 25.5
  },
  "disk": {
    "total": 32212254720,
    "used": 8053063680,
    "free": 24159190016,
    "percent": 25.0
  }
}
```

### 設定取得
```http
GET /api/system/config
```

**レスポンス**
```json
{
  "admin_host": "127.0.0.1",
  "admin_port": 8443,
  "proxy_host": "127.0.0.1",
  "proxy_port": 8080,
  "log_level": "INFO",
  "session_timeout": 1800,
  "max_connections": 1000
}
```

### 設定更新
```http
PUT /api/system/config
Content-Type: application/json

{
  "log_level": "DEBUG",
  "session_timeout": 3600,
  "max_connections": 2000
}
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Configuration updated",
  "restart_required": true
}
```

### サービス再起動
```http
POST /api/system/restart
Content-Type: application/json

{
  "service": "proxy",
  "force": false
}
```

**パラメータ**
- `service`: 再起動するサービス（proxy/admin/all）
- `force`: 強制再起動フラグ

**レスポンス**
```json
{
  "status": "success",
  "message": "Service restarting",
  "service": "proxy"
}
```

### バックアップ作成
```http
POST /api/system/backup
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Backup created",
  "filename": "lpg_backup_20250809_103000.tar.gz",
  "size": 1024000,
  "download_url": "/api/system/backup/download/lpg_backup_20250809_103000.tar.gz"
}
```

### バックアップダウンロード
```http
GET /api/system/backup/download/<filename>
```

**レスポンス**
- Content-Type: `application/gzip`
- バイナリデータ

### リストア
```http
POST /api/system/restore
Content-Type: multipart/form-data

backup_file=@lpg_backup.tar.gz
```

**レスポンス**
```json
{
  "status": "success",
  "message": "Restore completed",
  "restart_required": true
}
```

## エラーレスポンス

### エラー形式
```json
{
  "status": "error",
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### HTTPステータスコード

| コード | 説明 |
|--------|------|
| 200 | 成功 |
| 201 | 作成成功 |
| 400 | 不正なリクエスト |
| 401 | 認証が必要 |
| 403 | アクセス拒否 |
| 404 | リソースが見つからない |
| 409 | 競合 |
| 500 | サーバーエラー |
| 502 | プロキシエラー |
| 503 | サービス利用不可 |

### エラーコード

| コード | 説明 |
|--------|------|
| `AUTH_REQUIRED` | 認証が必要 |
| `INVALID_CREDENTIALS` | 認証情報が無効 |
| `SESSION_EXPIRED` | セッション期限切れ |
| `INVALID_REQUEST` | リクエストが不正 |
| `RESOURCE_NOT_FOUND` | リソースが見つからない |
| `DUPLICATE_RESOURCE` | リソースが重複 |
| `VALIDATION_ERROR` | バリデーションエラー |
| `PROXY_ERROR` | プロキシエラー |
| `INTERNAL_ERROR` | 内部エラー |

## 使用例

### cURLでの使用例

```bash
# ログイン
curl -c cookies.txt -X POST \
  -d "username=admin&password=lpgadmin123" \
  https://your-domain.com/lpg-admin/login

# デバイス一覧取得
curl -b cookies.txt \
  https://your-domain.com/lpg-admin/api/devices

# デバイス追加
curl -b cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","ip":"192.168.1.10","port":8080}' \
  https://your-domain.com/lpg-admin/api/device
```

### JavaScriptでの使用例

```javascript
// ログイン
async function login(username, password) {
  const formData = new URLSearchParams();
  formData.append('username', username);
  formData.append('password', password);
  
  const response = await fetch('/lpg-admin/login', {
    method: 'POST',
    body: formData
  });
  
  return response.json();
}

// デバイス一覧取得
async function getDevices() {
  const response = await fetch('/lpg-admin/api/devices');
  return response.json();
}

// デバイス追加
async function addDevice(device) {
  const response = await fetch('/lpg-admin/api/device', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(device)
  });
  
  return response.json();
}
```

## レート制限

- 認証エンドポイント: 5回/分
- API エンドポイント: 100回/分
- バックアップ/リストア: 1回/時間

制限を超えた場合、`429 Too Many Requests`が返されます。