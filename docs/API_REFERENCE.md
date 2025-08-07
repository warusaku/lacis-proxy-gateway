# LPG API リファレンス

## 認証

すべてのAPIエンドポイント（ヘルスチェックを除く）は認証が必要です。

### ログイン

```http
POST /login
Content-Type: application/x-www-form-urlencoded

username=admin&password=lpgadmin123
```

成功時、セッションCookieが設定されます。

### ログアウト

```http
GET /logout
```

## デバイス管理API

### デバイス一覧取得

```http
GET /api/devices
```

**レスポンス例:**
```json
{
  "devices": [
    {
      "id": "device-001",
      "name": "OrangePi 5+",
      "ip": "192.168.234.10",
      "port": 80,
      "path": "/",
      "domain": "lacisstack.boards",
      "status": "active",
      "description": "Main server",
      "access_count": 42,
      "type": "server"
    }
  ]
}
```

### デバイス追加

```http
POST /api/devices
Content-Type: application/json

{
  "name": "New Device",
  "ip": "192.168.1.100",
  "port": 8080,
  "path": "/app",
  "domain": "app.local",
  "description": "Application server"
}
```

**レスポンス例:**
```json
{
  "id": "device-123",
  "name": "New Device",
  "ip": "192.168.1.100",
  "port": 8080,
  "path": "/app",
  "domain": "app.local",
  "status": "active",
  "description": "Application server"
}
```

### デバイス更新

```http
PUT /api/device/<device_id>
Content-Type: application/json

{
  "name": "Updated Device",
  "ip": "192.168.1.101",
  "port": 8081,
  "description": "Updated description"
}
```

### デバイス削除

```http
DELETE /api/device/<device_id>
```

**レスポンス例:**
```json
{
  "message": "Device deleted successfully"
}
```

### デバイスPing確認

```http
GET /api/device/<device_id>/ping
```

**レスポンス例:**
```json
{
  "device_id": "device-001",
  "status": "online",
  "response_time": 23.5
}
```

## ドメイン管理API

### ドメイン一覧取得

```http
GET /api/domains
```

**レスポンス例:**
```json
{
  "domains": [
    {
      "name": "lacisstack.boards",
      "upstream": "192.168.234.10:80",
      "path": "/boards",
      "ssl": true
    }
  ]
}
```

### ドメイン追加

```http
POST /api/domains
Content-Type: application/json

{
  "name": "new.domain.com",
  "upstream": "192.168.1.100:8080",
  "path": "/",
  "ssl": false
}
```

### ドメイン削除

```http
DELETE /api/domain/<domain_name>
```

## システム管理API

### システムメトリクス取得

```http
GET /api/metrics
```

**レスポンス例:**
```json
{
  "connected_devices": 10,
  "active_sessions": 11,
  "system_uptime": "21h 6m",
  "bandwidth_usage": "0%",
  "cpu_usage": 27,
  "memory_usage": 5,
  "disk_usage": 6
}
```

### ログ取得

```http
GET /api/logs?limit=100&type=access
```

**パラメータ:**
- `limit`: 取得するログの件数（デフォルト: 100）
- `type`: ログタイプ（access, error, all）

**レスポンス例:**
```json
{
  "logs": [
    {
      "timestamp": "2025-08-05 15:30:00",
      "type": "access",
      "message": "User admin logged in from 192.168.1.100",
      "level": "info"
    }
  ]
}
```

### プロキシ再起動

```http
POST /api/restart-proxy
```

**レスポンス例:**
```json
{
  "message": "Proxy restarted successfully"
}
```

## WebSocket API

### リアルタイムメトリクス

```javascript
const ws = new WebSocket('wss://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/ws/metrics');

ws.onmessage = (event) => {
  const metrics = JSON.parse(event.data);
  console.log('Metrics update:', metrics);
};
```

### リアルタイムログ

```javascript
const ws = new WebSocket('wss://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/ws/logs');

ws.onmessage = (event) => {
  const log = JSON.parse(event.data);
  console.log('New log:', log);
};
```

## エラーレスポンス

すべてのAPIエンドポイントは、エラー時に以下の形式でレスポンスを返します：

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Detailed error information"
}
```

### HTTPステータスコード

- `200 OK`: 成功
- `201 Created`: リソース作成成功
- `400 Bad Request`: リクエストパラメータエラー
- `401 Unauthorized`: 認証エラー
- `404 Not Found`: リソースが見つからない
- `500 Internal Server Error`: サーバーエラー

## 使用例

### cURL

```bash
# ログイン
curl -c cookies.txt -X POST https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/login \
  -d "username=admin&password=lpgadmin123"

# デバイス一覧取得
curl -b cookies.txt https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/api/devices

# デバイス追加
curl -b cookies.txt -X POST https://akb001yebraxfqsm9y.dyndns-web.com/lpg-admin/api/devices \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Device","ip":"192.168.1.200","port":80}'
```

### JavaScript (Fetch API)

```javascript
// ログイン
const loginResponse = await fetch('/lpg-admin/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded'
  },
  body: 'username=admin&password=lpgadmin123',
  credentials: 'include'
});

// デバイス一覧取得
const devicesResponse = await fetch('/lpg-admin/api/devices', {
  credentials: 'include'
});
const devices = await devicesResponse.json();

// デバイス追加
const newDevice = await fetch('/lpg-admin/api/devices', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    name: 'Test Device',
    ip: '192.168.1.200',
    port: 80
  }),
  credentials: 'include'
});
```