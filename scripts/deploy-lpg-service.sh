#!/bin/bash

# LPGサーバーにサービスを適用するスクリプト
set -e

# 設定
LPG_HOST="192.168.234.2"
LPG_USER="root"
LPG_PASS="orangepi"

# Color functions
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

export SSHPASS="$LPG_PASS"

log "Deploying LPG service to $LPG_HOST..."

# ファイルをLPGサーバーにコピー
log "1. Copying files to LPG server..."
sshpass -e scp -o StrictHostKeyChecking=no \
    "/Volumes/crucial_MX500/lacis_project/project/LPG/src/lpg-proxy-8080.py" \
    "$LPG_USER@$LPG_HOST:/root/"

sshpass -e scp -o StrictHostKeyChecking=no \
    "/Volumes/crucial_MX500/lacis_project/project/LPG/src/lpg_admin.py" \
    "$LPG_USER@$LPG_HOST:/root/"

sshpass -e scp -o StrictHostKeyChecking=no \
    "/Volumes/crucial_MX500/lacis_project/project/LPG/systemd/lpg-proxy-8080.service" \
    "$LPG_USER@$LPG_HOST:/tmp/"

sshpass -e scp -o StrictHostKeyChecking=no \
    "/Volumes/crucial_MX500/lacis_project/project/LPG/nginx/lacisstack-boards-lpg.conf" \
    "$LPG_USER@$LPG_HOST:/tmp/"

log "2. Setting up services on LPG server..."
sshpass -e ssh -o StrictHostKeyChecking=no "$LPG_USER@$LPG_HOST" << 'EOF'
set -e

echo "=== Installing Python dependencies ==="
pip3 install flask

echo "=== Setting up systemd service ==="
# Stop existing services
systemctl stop lpg-proxy-8080.service 2>/dev/null || true
systemctl stop lpg-proxy.service 2>/dev/null || true

# Kill any existing proxy processes
pkill -f "lpg-proxy" || true
pkill -f "python3.*8080" || true
sleep 3

# Make sure port 80 is free
if lsof -i :80 > /dev/null 2>&1; then
    echo "Port 80 is in use, killing processes..."
    lsof -t -i:80 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Install systemd service
cp /tmp/lpg-proxy-8080.service /etc/systemd/system/
systemctl daemon-reload

# Make scripts executable
chmod +x /root/lpg-proxy-8080.py
chmod +x /root/lpg_admin.py

echo "=== Setting up nginx configuration ==="
# Install nginx config
cp /tmp/lacisstack-boards-lpg.conf /etc/nginx/sites-available/lacisstack-boards.conf

# Remove old symlink if exists
rm -f /etc/nginx/sites-enabled/lacisstack-boards.conf

# Create new symlink
ln -s /etc/nginx/sites-available/lacisstack-boards.conf /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

echo "=== Starting services ==="
# Start LPG proxy service
systemctl enable lpg-proxy-8080.service
systemctl start lpg-proxy-8080.service

# Wait for service to start
sleep 5

# Check service status
echo ""
echo "=== Service Status ==="
systemctl status lpg-proxy-8080.service --no-pager -l

# Check if service is listening on port 80
echo ""
echo "=== Port Status ==="
netstat -tlpn | grep :80 || echo "No process listening on port 80"

# Test health endpoint
echo ""
echo "=== Health Check ==="
curl -s http://localhost/health | jq . || curl -s http://localhost/health

# Check if admin service is running
echo ""
echo "=== Admin Service Status ==="
if ps aux | grep -q "lpg_admin.py"; then
    echo "Admin service is already running"
else
    echo "Starting admin service..."
    nohup python3 /root/lpg_admin.py > /var/log/lpg-admin.log 2>&1 &
    sleep 3
fi

# Reload nginx
systemctl reload nginx

echo ""
echo "=== Final Status Check ==="
systemctl is-active lpg-proxy-8080.service
systemctl is-active nginx
EOF

# Test from outside
log "3. Testing services from external host..."
sleep 5

response=$(curl -s -o /dev/null -w "%{http_code}" http://$LPG_HOST/health || echo "000")
if [ "$response" = "200" ]; then
    success "LPG proxy is accessible!"
    curl -s http://$LPG_HOST/health | jq .
else
    error "Cannot access LPG proxy (HTTP $response)"
fi

# Test admin UI
admin_response=$(curl -s -o /dev/null -w "%{http_code}" http://$LPG_HOST:8443/login || echo "000")
if [ "$admin_response" = "200" ]; then
    success "LPG admin UI is accessible!"
else
    error "Cannot access LPG admin UI (HTTP $admin_response)"
fi

# Test routing
log "4. Testing routing..."
curl -I http://$LPG_HOST/lacisstack/boards 2>&1 | head -10

success "LPG service deployment completed!"
echo ""
echo "Services status:"
echo "- LPG Proxy (HTTP): http://$LPG_HOST (port 80)"
echo "- LPG Admin UI: http://$LPG_HOST:8443"
echo "- HTTPS endpoint: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards/"