# Orange Pi 5 Plus 手動セットアップ手順

## 1. SSH接続

```bash
ssh root@192.168.234.10
# パスワードを入力（デフォルトまたは設定済みのもの）
```

## 2. 初期設定

初回ログイン時に自動的に開始される設定ウィザードに従ってください：

1. **rootパスワードの変更**
   - 現在のパスワードを入力
   - 新しいパスワード: `OrangePi2024!`

2. **一般ユーザーの作成**
   - ユーザー名: `lacissystem`
   - パスワード: `lacis12345@`
   - フルネーム: `Lacis System Admin`

3. **言語設定**: n (英語のまま)

## 3. 基本設定

ユーザー作成後、新しいユーザーでログインしてください：

```bash
ssh lacissystem@192.168.234.10
```

## 4. システムアップデート

```bash
sudo apt update
sudo apt upgrade -y
```

## 5. テストWebサーバーのセットアップ

### 必要なパッケージのインストール

```bash
sudo apt install -y python3 python3-pip curl wget vim net-tools
sudo pip3 install websockets
```

### テストWebページの作成

```bash
sudo mkdir -p /var/www/test
sudo tee /var/www/test/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LPG Test Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 50px;
            background-color: #f0f0f0;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .success {
            color: green;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .info {
            background: #e8f4f8;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">✓ LPG Routing Success!</h1>
        <p>If you can see this page, the LPG reverse proxy is working correctly.</p>
        
        <div class="info">
            <h2>Connection Information</h2>
            <p><strong>Server:</strong> Orange Pi 5 Plus</p>
            <p><strong>IP Address:</strong> 192.168.234.10</p>
            <p><strong>Service:</strong> Test Web Server on Port 8080</p>
            <p><strong>Path:</strong> /lacisstack/boards</p>
        </div>
        
        <p>Page generated at: <script>document.write(new Date().toLocaleString('ja-JP'));</script></p>
    </div>
</body>
</html>
EOF
```

### HTTPサーバーの起動

```bash
# テスト用に一時的に起動
cd /var/www/test
sudo python3 -m http.server 8080
```

### 別のターミナルでWebSocketサーバーの作成

```bash
mkdir -p ~/ws-test
cat > ~/ws-test/ws-server.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import json
import datetime

async def handle_client(websocket, path):
    print(f"New WebSocket connection from {websocket.remote_address}")
    
    await websocket.send(json.dumps({
        "type": "welcome",
        "message": "Connected to Orange Pi 5 Plus WebSocket server",
        "timestamp": datetime.datetime.now().isoformat()
    }))
    
    try:
        async for message in websocket:
            print(f"Received: {message}")
            await websocket.send(json.dumps({
                "type": "echo",
                "data": message,
                "timestamp": datetime.datetime.now().isoformat()
            }))
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    print("Starting WebSocket server on port 8081...")
    async with websockets.serve(handle_client, "0.0.0.0", 8081):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x ~/ws-test/ws-server.py
python3 ~/ws-test/ws-server.py
```

## 6. 動作確認

### 直接アクセステスト

```bash
# HTTPテスト
curl http://localhost:8080

# 外部からのテスト（管理PCから）
curl http://192.168.234.10:8080
```

### LPG経由のテスト

管理PCのブラウザから：
1. `test-lpg-routing.html` ファイルを開く
2. 各テストボタンをクリック

または、curlコマンドで：

```bash
# LPG経由でのアクセステスト
curl -k https://192.168.234.2/lacisstack/boards
curl -k https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards
```

## 7. サービス化（オプション）

永続的に動作させる場合：

```bash
# HTTPサービス
sudo tee /etc/systemd/system/test-web.service > /dev/null << 'EOF'
[Unit]
Description=Test Web Server
After=network.target

[Service]
Type=simple
User=lacissystem
WorkingDirectory=/var/www/test
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# WebSocketサービス
sudo tee /etc/systemd/system/test-ws.service > /dev/null << 'EOF'
[Unit]
Description=Test WebSocket Server
After=network.target

[Service]
Type=simple
User=lacissystem
WorkingDirectory=/home/lacissystem/ws-test
ExecStart=/usr/bin/python3 /home/lacissystem/ws-test/ws-server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# サービスの有効化と起動
sudo systemctl daemon-reload
sudo systemctl enable test-web test-ws
sudo systemctl start test-web test-ws
```

## トラブルシューティング

### ポートが使用中の場合
```bash
sudo lsof -i :8080
sudo lsof -i :8081
```

### ファイアウォールの確認
```bash
sudo ufw status
```

### ネットワーク設定の確認
```bash
ip addr show
ip route show
```