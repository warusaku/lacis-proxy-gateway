#!/bin/bash
# LPG Enhanced Deployment Script
# Purpose: Deploy enhanced LPG proxy with config.json support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LPG_HOST="192.168.234.2"
LPG_USER="root"
LPG_PASS="orangepi"
LPG_PATH="/opt/lpg"

echo -e "${GREEN}=== LPG Enhanced Deployment ===${NC}"
echo "Target: $LPG_USER@$LPG_HOST"
echo "Deployment path: $LPG_PATH"
echo ""

# Check files exist
echo -e "${YELLOW}Checking files...${NC}"
if [ ! -f "src/lpg_proxy_enhanced.py" ]; then
    echo -e "${RED}Error: src/lpg_proxy_enhanced.py not found${NC}"
    exit 1
fi

if [ ! -f "config/config.json" ]; then
    echo -e "${RED}Error: config/config.json not found${NC}"
    exit 1
fi

echo -e "${GREEN}Files check passed${NC}"

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
rm -rf deploy_temp
mkdir -p deploy_temp/src
mkdir -p deploy_temp/config
mkdir -p deploy_temp/templates

# Copy files
cp src/lpg_proxy_enhanced.py deploy_temp/src/
cp src/lpg_server.py deploy_temp/src/
cp src/lpg_admin.py deploy_temp/src/
cp -r src/templates/* deploy_temp/templates/ 2>/dev/null || true
cp config/config.json deploy_temp/config/

# Create setup script
cat > deploy_temp/setup.sh << 'EOF'
#!/bin/bash
# LPG Setup Script (runs on target)

echo "Setting up enhanced LPG..."

# Backup existing files
if [ -f /opt/lpg/src/lpg_server.py ]; then
    cp /opt/lpg/src/lpg_server.py /opt/lpg/src/lpg_server.py.bak
fi

if [ -f /etc/lpg/config.json ]; then
    cp /etc/lpg/config.json /etc/lpg/config.json.bak
fi

# Copy new files
cp src/lpg_proxy_enhanced.py /opt/lpg/src/
cp src/lpg_server.py /opt/lpg/src/
cp src/lpg_admin.py /opt/lpg/src/
cp -r templates/* /opt/lpg/src/templates/ 2>/dev/null || true

# Update config if /etc/lpg exists
if [ -d /etc/lpg ]; then
    cp config/config.json /etc/lpg/
else
    mkdir -p /etc/lpg
    cp config/config.json /etc/lpg/
fi

# Set permissions
chmod +x /opt/lpg/src/*.py

echo "Enhanced LPG setup complete!"
EOF

chmod +x deploy_temp/setup.sh

# Create tarball
tar -czf lpg-enhanced-deploy.tar.gz -C deploy_temp .

echo -e "${GREEN}Deployment package created${NC}"

# Transfer to LPG
echo -e "${YELLOW}Transferring to LPG...${NC}"
sshpass -p "$LPG_PASS" scp lpg-enhanced-deploy.tar.gz $LPG_USER@$LPG_HOST:/tmp/

# Execute deployment
echo -e "${YELLOW}Executing deployment...${NC}"
sshpass -p "$LPG_PASS" ssh $LPG_USER@$LPG_HOST << 'REMOTE_SCRIPT'
cd /tmp
rm -rf lpg-deploy
mkdir lpg-deploy
cd lpg-deploy
tar -xzf ../lpg-enhanced-deploy.tar.gz
./setup.sh

# Test enhanced proxy import
python3 -c "
import sys
sys.path.append('/opt/lpg/src')
try:
    from lpg_proxy_enhanced import LPGProxyHandler
    print('✓ Enhanced proxy handler imported successfully')
except Exception as e:
    print('✗ Failed to import enhanced proxy:', e)
"

# Restart LPG service
echo "Restarting LPG service..."
pkill -f lpg_server.py || true
pkill -f lpg-proxy || true
sleep 2

# Start in background
cd /opt/lpg
nohup python3 src/lpg_server.py > /var/log/lpg.log 2>&1 &

echo "Deployment complete!"
REMOTE_SCRIPT

# Cleanup
rm -rf deploy_temp
rm -f lpg-enhanced-deploy.tar.gz

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Test URLs:"
echo "  Health Check: http://$LPG_HOST/health"
echo "  Admin UI: https://$LPG_HOST:8443"
echo "  Proxy Test: http://$LPG_HOST/lacisstack/boards/"
echo ""
echo -e "${YELLOW}Note: The enhanced proxy includes:${NC}"
echo "  - Dynamic config.json loading"
echo "  - Automatic MIME type fixing"
echo "  - Path rewriting support"
echo "  - Enhanced device management UI"