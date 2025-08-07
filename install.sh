#!/bin/bash
# LPG Clean Installation Script
# Version: 1.0
# Date: 2025-08-08
# Purpose: Safe installation of LPG with network protection

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== LPG Clean Installation Script ===${NC}"
echo "This script will install LPG with network safety protection"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Safety confirmation
echo -e "${YELLOW}This script will:${NC}"
echo "1. Install LPG files to /opt/lpg"
echo "2. Configure environment variables (127.0.0.1 ONLY)"
echo "3. Set up systemd services"
echo "4. Configure nginx reverse proxy"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 1
fi

# Create directories
echo -e "\n${GREEN}Creating directories...${NC}"
mkdir -p /opt/lpg/{src,templates,logs,backups,config}
mkdir -p /var/log/lpg

# Set up environment variables (CRITICAL FOR SAFETY)
echo -e "\n${GREEN}Setting up environment variables...${NC}"
cat > /opt/lpg/config/lpg_environment << 'EOF'
# LPG Environment Variables - CRITICAL SAFETY CONFIGURATION
# WARNING: NEVER change LPG_ADMIN_HOST to 0.0.0.0 - it will crash the network!
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
export LPG_PROXY_PORT=8080
export LPG_SAFE_MODE=1
EOF

# Add to system environment
echo "LPG_ADMIN_HOST=127.0.0.1" >> /etc/environment
echo "LPG_ADMIN_PORT=8443" >> /etc/environment

# Copy files
echo -e "\n${GREEN}Copying LPG files...${NC}"
cp -r src/* /opt/lpg/src/
cp systemd/*.service /etc/systemd/system/

# Set permissions
echo -e "\n${GREEN}Setting permissions...${NC}"
chown -R root:root /opt/lpg
chmod 755 /opt/lpg
chmod 644 /opt/lpg/src/*.py
chmod 644 /opt/lpg/src/*.json
chmod 644 /opt/lpg/src/templates/*.html

# Install Python dependencies
echo -e "\n${GREEN}Installing Python dependencies...${NC}"
pip3 install flask werkzeug requests || {
    echo -e "${RED}Failed to install Python dependencies${NC}"
    exit 1
}

# Configure nginx
echo -e "\n${GREEN}Configuring nginx...${NC}"
if [ -f nginx/lpg-ssl ]; then
    cp nginx/lpg-ssl /etc/nginx/sites-available/lpg-proxy
    ln -sf /etc/nginx/sites-available/lpg-proxy /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
fi

# Create safety check script
echo -e "\n${GREEN}Creating safety check script...${NC}"
cat > /opt/lpg/safety_check.sh << 'EOF'
#!/bin/bash
# LPG Safety Check - Run before starting services

echo "=== LPG Safety Check ==="

# Check environment variables
source /opt/lpg/config/lpg_environment
if [ "$LPG_ADMIN_HOST" != "127.0.0.1" ]; then
    echo "❌ CRITICAL: LPG_ADMIN_HOST is not 127.0.0.1"
    echo "   Current value: $LPG_ADMIN_HOST"
    echo "   This could crash the network!"
    exit 1
fi
echo "✅ Environment variables: Safe"

# Check if port is already in use
if netstat -tln | grep -q ":8443 "; then
    echo "⚠️  Port 8443 is already in use"
    lsof -i :8443
fi

# Check nginx
if systemctl is-active nginx > /dev/null; then
    echo "✅ Nginx: Active"
else
    echo "⚠️  Nginx: Not running"
fi

echo ""
echo "Safety check complete. Safe to start LPG services."
EOF
chmod +x /opt/lpg/safety_check.sh

# Reload systemd
echo -e "\n${GREEN}Configuring systemd services...${NC}"
systemctl daemon-reload

# Run safety check
echo -e "\n${GREEN}Running safety check...${NC}"
/opt/lpg/safety_check.sh || {
    echo -e "${RED}Safety check failed! Please fix issues before continuing.${NC}"
    exit 1
}

# Enable services (but don't start yet)
echo -e "\n${GREEN}Enabling services for auto-start...${NC}"
systemctl enable lpg-admin.service
systemctl enable lpg-proxy.service

echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Review configuration in /opt/lpg/config/lpg_environment"
echo "2. Start services manually for testing:"
echo "   systemctl start lpg-admin.service"
echo "   systemctl start lpg-proxy.service"
echo "3. Check logs:"
echo "   journalctl -u lpg-admin -f"
echo "   tail -f /var/log/lpg/lpg_admin.log"
echo ""
echo -e "${YELLOW}IMPORTANT: Services are enabled for auto-start on boot${NC}"
echo -e "${YELLOW}but NOT started now. Test manually first.${NC}"