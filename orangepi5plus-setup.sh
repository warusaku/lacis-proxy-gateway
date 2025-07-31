#!/bin/bash
# Orange Pi 5 Plus Setup Script for LPG Testing

echo "=== Orange Pi 5 Plus Setup Script ==="
echo "This script will configure the system for LPG testing"
echo ""

# Update system
echo "1. Updating system packages..."
apt update
apt upgrade -y

# Install basic packages
echo "2. Installing basic packages..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    python3 \
    python3-pip \
    nginx

# Configure network (if needed)
echo "3. Checking network configuration..."
ip addr show eth0

# Create test web server
echo "4. Setting up test web server..."
mkdir -p /var/www/test
cat > /var/www/test/index.html << 'EOF'
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
        .timestamp {
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">✓ LPG Routing Success!</h1>
        <p>If you can see this page, the LPG reverse proxy is working correctly.</p>
        
        <div class="info">
            <h2>Connection Information</h2>
            <p><strong>Server:</strong> Orange Pi 5 Plus (Test Server)</p>
            <p><strong>IP Address:</strong> 192.168.234.10</p>
            <p><strong>Service:</strong> Test Web Server on Port 8080</p>
            <p><strong>Path:</strong> /lacisstack/boards</p>
        </div>
        
        <div class="info">
            <h2>Request Headers</h2>
            <p>Check the browser developer tools to see the forwarded headers.</p>
        </div>
        
        <p class="timestamp">Page generated at: <span id="time"></span></p>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('ja-JP');
    </script>
</body>
</html>
EOF

# Configure Python simple HTTP server as a service
echo "5. Creating web server service..."
cat > /etc/systemd/system/test-web.service << 'EOF'
[Unit]
Description=Test Web Server for LPG
After=network.target

[Service]
Type=simple
User=lacissystem
WorkingDirectory=/var/www/test
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create WebSocket test server
echo "6. Creating WebSocket test server..."
mkdir -p /home/lacissystem/ws-test
cat > /home/lacissystem/ws-test/ws-server.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import json
import datetime

async def handle_client(websocket, path):
    print(f"New WebSocket connection from {websocket.remote_address}")
    
    # Send welcome message
    await websocket.send(json.dumps({
        "type": "welcome",
        "message": "Connected to Orange Pi 5 Plus WebSocket server",
        "timestamp": datetime.datetime.now().isoformat()
    }))
    
    try:
        async for message in websocket:
            print(f"Received: {message}")
            # Echo the message back
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
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x /home/lacissystem/ws-test/ws-server.py
chown -R lacissystem:lacissystem /home/lacissystem/ws-test

# Install Python WebSocket library
pip3 install websockets

# Create WebSocket service
cat > /etc/systemd/system/test-ws.service << 'EOF'
[Unit]
Description=Test WebSocket Server for LPG
After=network.target

[Service]
Type=simple
User=lacissystem
WorkingDirectory=/home/lacissystem/ws-test
ExecStart=/usr/bin/python3 /home/lacissystem/ws-test/ws-server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo "7. Starting services..."
systemctl daemon-reload
systemctl enable test-web.service
systemctl start test-web.service
systemctl enable test-ws.service
systemctl start test-ws.service

# Configure firewall (basic)
echo "8. Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.234.0/24 to any port 22
ufw allow from 192.168.234.0/24 to any port 8080
ufw allow from 192.168.234.0/24 to any port 8081
ufw --force enable

# Display status
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Service Status:"
systemctl status test-web --no-pager
echo ""
systemctl status test-ws --no-pager
echo ""
echo "Network Configuration:"
ip addr show eth0 | grep inet
echo ""
echo "Test URLs:"
echo "- Direct HTTP: http://192.168.234.10:8080"
echo "- Direct WS: ws://192.168.234.10:8081"
echo "- Via LPG: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards"
echo ""
echo "Next steps:"
echo "1. Test direct access: curl http://192.168.234.10:8080"
echo "2. Configure LPG to route to this server"
echo "3. Test via LPG from VLAN1"