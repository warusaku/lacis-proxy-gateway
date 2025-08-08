#!/bin/bash
# LPG Remote Installation Script
# Purpose: Install LPG on Orange Pi with all safety mechanisms

set -e

# Configuration
ORANGE_PI_IP="192.168.234.2"
ORANGE_PI_USER="orangepi"
ORANGE_PI_PASS="orangepi"
ROOT_PASS="orangepi"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}   LPG Remote Installation${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""

# Step 1: Copy installation files
echo -e "${GREEN}Step 1: Copying installation files to Orange Pi...${NC}"
sshpass -p "$ORANGE_PI_PASS" scp -r \
    /Volumes/crucial_MX500/lacis_project/project/LPG/src \
    /Volumes/crucial_MX500/lacis_project/project/LPG/systemd \
    /Volumes/crucial_MX500/lacis_project/project/LPG/nginx \
    /Volumes/crucial_MX500/lacis_project/project/LPG/install.sh \
    /Volumes/crucial_MX500/lacis_project/project/LPG/test_safety_mechanisms.sh \
    ${ORANGE_PI_USER}@${ORANGE_PI_IP}:/tmp/

# Step 2: Run installation
echo -e "${GREEN}Step 2: Running installation on Orange Pi...${NC}"
sshpass -p "$ORANGE_PI_PASS" ssh ${ORANGE_PI_USER}@${ORANGE_PI_IP} << 'REMOTE_EOF'
# Become root
echo "orangepi" | sudo -S su - << 'ROOT_EOF'

# Set hostname
hostnamectl set-hostname lpg-proxy

# Set timezone
timedatectl set-timezone Asia/Tokyo

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y python3 python3-pip nginx git curl

# Install Python packages
pip3 install flask werkzeug requests

# Create LPG directory
mkdir -p /opt/lpg
cp -r /tmp/src /opt/lpg/
cp -r /tmp/systemd /opt/lpg/
cp /tmp/install.sh /opt/lpg/
cp /tmp/test_safety_mechanisms.sh /opt/lpg/

# Set permissions
chmod +x /opt/lpg/install.sh
chmod +x /opt/lpg/test_safety_mechanisms.sh
chmod +x /opt/lpg/src/ssh_fallback.sh

# Create log directory
mkdir -p /var/log/lpg

# Run installation with safety
cd /opt/lpg
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
./install.sh

# Configure nginx
cp /tmp/nginx/lpg-ssl /etc/nginx/sites-available/lpg-proxy
ln -sf /etc/nginx/sites-available/lpg-proxy /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Enable services
systemctl enable ssh-fallback
systemctl enable lpg-watchdog
systemctl enable lpg-admin

# Start services in order
systemctl start ssh-fallback
systemctl start lpg-watchdog
systemctl start lpg-admin

# Check status
systemctl status lpg-admin --no-pager

echo "Installation completed!"
echo "LPG Admin Interface: http://127.0.0.1:8443"
echo "Default credentials: admin / lpgadmin123"

ROOT_EOF
REMOTE_EOF

echo -e "${GREEN}✅ Remote installation completed!${NC}"
echo ""
echo "Access points:"
echo "- Local: http://192.168.234.2:8443"
echo "- Via nginx: https://[your-domain]/lpg-admin/"
echo ""
echo -e "${YELLOW}⚠️  Remember: Always use LPG_ADMIN_HOST=127.0.0.1${NC}"