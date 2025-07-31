#!/bin/bash
# LPG Deployment Script
# This script prepares and deploys LPG to the target server

echo "=== LPG Deployment Script ==="
echo "Target: 192.168.234.2"
echo ""

# Check if required files exist
required_files=(
    "config/config.json"
    "config/caddy/Caddyfile"
    "scripts/setup-ftp.sh"
    "scripts/docker-entrypoint.sh"
    "scripts/ftp-deploy-watcher.sh"
    "scripts/lpg-health-check.sh"
    "scripts/security-hardening.sh"
)

echo "Checking required files..."
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Missing required file: $file"
        exit 1
    fi
done
echo "All required files found."
echo ""

# Create deployment package
echo "Creating deployment package..."
tar -czf lpg-deploy.tar.gz \
    config/ \
    scripts/ \
    --exclude="*.example.*" \
    --exclude=".DS_Store"

echo "Deployment package created: lpg-deploy.tar.gz"
echo ""

echo "=== Deployment Instructions ==="
echo "1. Copy lpg-deploy.tar.gz to the target server:"
echo "   scp lpg-deploy.tar.gz lacissystem@192.168.234.2:/home/lacissystem/"
echo ""
echo "2. SSH to the server:"
echo "   ssh lacissystem@192.168.234.2"
echo ""
echo "3. On the server, run:"
echo "   tar -xzf lpg-deploy.tar.gz"
echo "   sudo ./scripts/setup-lpg.sh"
echo ""