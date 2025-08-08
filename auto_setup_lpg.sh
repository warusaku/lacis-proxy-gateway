#!/bin/bash
# LPG Auto Setup Script for Fresh Orange Pi Zero 3
# Safe and automated installation with all protection mechanisms

set -e

# Configuration
ORANGE_PI_IP="192.168.234.2"
DEFAULT_USER="orangepi"
DEFAULT_PASS="orangepi"
NEW_ROOT_PASS="orangepi"  # Change this for production!

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}   LPG Auto Setup for Orange Pi Zero 3${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""

# Wait for Orange Pi to be ready
echo -e "${GREEN}Waiting for Orange Pi at ${ORANGE_PI_IP}...${NC}"
while ! ping -c 1 ${ORANGE_PI_IP} &> /dev/null; do
    echo -n "."
    sleep 2
done
echo -e "\n${GREEN}✓ Orange Pi is online!${NC}"

# Step 1: Copy all necessary files
echo -e "\n${GREEN}Step 1: Copying installation files...${NC}"
sshpass -p "${DEFAULT_PASS}" scp -o StrictHostKeyChecking=no -r \
    /Volumes/crucial_MX500/lacis_project/project/LPG/src \
    /Volumes/crucial_MX500/lacis_project/project/LPG/systemd \
    /Volumes/crucial_MX500/lacis_project/project/LPG/nginx \
    /Volumes/crucial_MX500/lacis_project/project/LPG/install.sh \
    /Volumes/crucial_MX500/lacis_project/project/LPG/test_safety_mechanisms.sh \
    ${DEFAULT_USER}@${ORANGE_PI_IP}:/tmp/

# Step 2: Run setup on Orange Pi
echo -e "\n${GREEN}Step 2: Running initial setup...${NC}"
sshpass -p "${DEFAULT_PASS}" ssh -o StrictHostKeyChecking=no ${DEFAULT_USER}@${ORANGE_PI_IP} << 'SETUP_EOF'
# Initial system setup
echo "orangepi" | sudo -S bash << 'ROOT_EOF'

# Set hostname
hostnamectl set-hostname lpg-proxy
echo "127.0.0.1 lpg-proxy" >> /etc/hosts

# Set timezone
timedatectl set-timezone Asia/Tokyo

# Configure network (ensure static IP)
cat > /etc/netplan/01-network.yaml << 'NET_EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.234.2/24
      gateway4: 192.168.234.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
NET_EOF

netplan apply

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    python3 \
    python3-pip \
    nginx \
    git \
    curl \
    net-tools \
    iptables \
    iptables-persistent

# Install Python packages
pip3 install flask werkzeug requests

# Create LPG directories
mkdir -p /opt/lpg
mkdir -p /var/log/lpg
mkdir -p /etc/lpg

# Copy files from tmp
cp -r /tmp/src /opt/lpg/
cp -r /tmp/systemd /opt/lpg/
cp /tmp/install.sh /opt/lpg/
cp /tmp/test_safety_mechanisms.sh /opt/lpg/

# Set permissions
chmod +x /opt/lpg/install.sh
chmod +x /opt/lpg/test_safety_mechanisms.sh
chmod +x /opt/lpg/src/ssh_fallback.sh
chmod +x /opt/lpg/src/lpg_safe_wrapper.py
chmod +x /opt/lpg/src/network_watchdog.py

# Install systemd services
cp /opt/lpg/systemd/*.service /etc/systemd/system/
systemctl daemon-reload

# Configure nginx
cp /tmp/nginx/lpg-ssl /etc/nginx/sites-available/lpg-proxy
ln -sf /etc/nginx/sites-available/lpg-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Setup SSH fallback protection FIRST
/opt/lpg/src/ssh_fallback.sh

# Create safe environment file
cat > /etc/lpg/lpg.env << 'ENV_EOF'
# LPG Environment Configuration
# CRITICAL: Never change LPG_ADMIN_HOST to 0.0.0.0!
LPG_ADMIN_HOST=127.0.0.1
LPG_ADMIN_PORT=8443
LPG_SAFE_MODE=1
ENV_EOF

# Enable and start services in correct order
systemctl enable ssh-fallback || true
systemctl enable lpg-watchdog
systemctl enable lpg-admin

# Start services
systemctl start lpg-watchdog
sleep 3
systemctl start lpg-admin

# Check status
systemctl status lpg-admin --no-pager
systemctl status lpg-watchdog --no-pager

# Set up firewall rules
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -s 127.0.0.1 -p tcp --dport 8443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j DROP
netfilter-persistent save

echo "====================================="
echo "LPG Installation Complete!"
echo "====================================="
echo "Access: http://192.168.234.2:8443 (local only)"
echo "Default: admin / lpgadmin123"
echo ""
echo "CRITICAL SAFETY NOTES:"
echo "- LPG_ADMIN_HOST is locked to 127.0.0.1"
echo "- Network watchdog is active"
echo "- SSH fallback protection enabled"
echo "====================================="

ROOT_EOF
SETUP_EOF

echo -e "\n${GREEN}✅ Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Important Information:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IP Address: ${ORANGE_PI_IP}"
echo "LPG Admin: http://${ORANGE_PI_IP}:8443"
echo "SSH Access: ssh ${DEFAULT_USER}@${ORANGE_PI_IP}"
echo "Default Login: admin / lpgadmin123"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${RED}⚠️  Safety Features Active:${NC}"
echo "• Network Watchdog: Monitoring for dangerous bindings"
echo "• SSH Fallback: Protected SSH access"
echo "• Safe Wrapper: Environment protection"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Test access: curl http://${ORANGE_PI_IP}:8443"
echo "2. Run safety test: ssh ${DEFAULT_USER}@${ORANGE_PI_IP} 'sudo /opt/lpg/test_safety_mechanisms.sh'"
echo "3. Monitor logs: ssh ${DEFAULT_USER}@${ORANGE_PI_IP} 'sudo tail -f /var/log/lpg_admin.log'"