#!/bin/bash
# LPG Production Setup Script
# This script sets up LPG on Orange Pi Zero 3

set -e

echo "=== LPG Production Setup Script ==="
echo "Starting at: $(date)"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

# System update
echo "1. Updating system packages..."
apt update
apt upgrade -y

# Install required packages
echo "2. Installing required packages..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    build-essential \
    ufw \
    vsftpd \
    nginx \
    certbot \
    python3-certbot-nginx \
    golang-go \
    jq

# Install Caddy
echo "3. Installing Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy

# Create directories
echo "4. Creating directories..."
mkdir -p /opt/lpg
mkdir -p /etc/lpg/certs
mkdir -p /var/log/lpg
mkdir -p /var/ftp/lpg/{upload,backup,deploy}
mkdir -p /usr/local/bin

# Set permissions
chown -R lacissystem:lacissystem /opt/lpg
chown -R lacissystem:lacissystem /etc/lpg
chown -R lacissystem:lacissystem /var/log/lpg
chown -R lacissystem:lacissystem /var/ftp/lpg

# Copy configuration files
echo "5. Copying configuration files..."
if [ -d "config" ]; then
    cp config/config.json /etc/lpg/
    cp config/caddy/Caddyfile /etc/caddy/
    cp config/vsftpd/vsftpd.conf /etc/vsftpd.conf
fi

# Copy scripts
echo "6. Copying scripts..."
if [ -d "scripts" ]; then
    cp scripts/*.sh /usr/local/bin/
    chmod +x /usr/local/bin/*.sh
fi

# Configure firewall
echo "7. Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH from VLAN1
ufw allow from 192.168.3.0/24 to any port 22 comment 'SSH from VLAN1'

# Allow web traffic from VLAN1
ufw allow from 192.168.3.0/24 to any port 80 comment 'HTTP from VLAN1'
ufw allow from 192.168.3.0/24 to any port 443 comment 'HTTPS from VLAN1'
ufw allow from 192.168.3.0/24 to any port 8443 comment 'Admin UI from VLAN1'

# Allow FTP from VLAN1
ufw allow from 192.168.3.0/24 to any port 21 comment 'FTP from VLAN1'
ufw allow from 192.168.3.0/24 to any port 30000:30100 proto tcp comment 'FTP Passive from VLAN1'

# Enable firewall
ufw --force enable

# Configure vsftpd
echo "8. Configuring FTP server..."
systemctl stop vsftpd || true

# Create vsftpd SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/vsftpd.key \
    -out /etc/ssl/certs/vsftpd.pem \
    -subj "/C=JP/ST=Tokyo/L=Tokyo/O=LACIS/CN=lpg.local"

# Start services
echo "9. Starting services..."
systemctl enable caddy
systemctl start caddy

systemctl enable vsftpd
systemctl start vsftpd

# Create LPG systemd service
echo "10. Creating LPG service..."
cat > /etc/systemd/system/lpg.service << 'EOF'
[Unit]
Description=Lacis Proxy Gateway
After=network.target

[Service]
Type=simple
User=lacissystem
WorkingDirectory=/opt/lpg
ExecStart=/usr/local/bin/lpg-api
Restart=always
RestartSec=10
Environment="CONFIG_PATH=/etc/lpg/config.json"
Environment="LOG_DIR=/var/log/lpg"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# Note: lpg service will be started after lpg-api binary is deployed

# Setup cron jobs
echo "11. Setting up cron jobs..."
cat > /etc/cron.d/lpg << 'EOF'
# LPG maintenance tasks
0 2 * * * root /usr/local/bin/backup-lpg.sh
0 * * * * root /usr/local/bin/lpg-health-check.sh
*/5 * * * * root /usr/local/bin/ftp-deploy-watcher.sh
EOF

# Create simple Go API server for initial testing
echo "12. Creating temporary API server..."
cat > /opt/lpg/temp-api.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
)

func main() {
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(map[string]interface{}{
            "status": "ok",
            "timestamp": time.Now().Unix(),
            "service": "LPG Temporary API",
        })
    })

    http.HandleFunc("/api/v1/version", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(map[string]interface{}{
            "version": "1.0.0-temp",
            "build": "temporary",
        })
    })

    fmt.Println("Starting temporary API server on :8443...")
    log.Fatal(http.ListenAndServe(":8443", nil))
}
EOF

cd /opt/lpg
go build -o /usr/local/bin/lpg-api temp-api.go || echo "Go build failed - manual build required"

# Display status
echo ""
echo "=== Setup Complete ==="
echo "1. Caddy status:"
systemctl status caddy --no-pager || true
echo ""
echo "2. FTP status:"
systemctl status vsftpd --no-pager || true
echo ""
echo "3. Firewall status:"
ufw status
echo ""
echo "4. Network configuration:"
ip addr show eth0 | grep inet
echo ""
echo "Next steps:"
echo "- Deploy lpg-api binary via FTP to /var/ftp/lpg/upload/"
echo "- It will be automatically deployed to /usr/local/bin/"
echo "- The service will start automatically"
echo ""
echo "Completed at: $(date)"