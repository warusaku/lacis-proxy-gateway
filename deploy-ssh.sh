#!/bin/bash
# LPG SSH Deployment Script
# This script deploys LPG to the target server via SSH

set -e

echo "=== LPG SSH Deployment Script ==="
echo "Target: 192.168.234.2"
echo "User: lacissystem"
echo ""

# Check if sshpass is available, if not use expect
if ! command -v sshpass &> /dev/null && ! command -v expect &> /dev/null; then
    echo "ERROR: Neither sshpass nor expect is installed."
    echo "Please install one of them or use manual SSH."
    exit 1
fi

# Target information
TARGET_HOST="192.168.234.2"
TARGET_USER="lacissystem"
TARGET_PASS="lacis12345@"

# Function to execute SSH command
ssh_exec() {
    local cmd="$1"
    echo "Executing: $cmd"
    
    if command -v sshpass &> /dev/null; then
        sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "$cmd"
    else
        # Use expect as fallback
        expect -c "
            set timeout 30
            spawn ssh $TARGET_USER@$TARGET_HOST \"$cmd\"
            expect {
                \"password:\" {
                    send \"$TARGET_PASS\r\"
                    expect eof
                }
                eof
            }
        "
    fi
}

# Function to copy file via SCP
scp_copy() {
    local src="$1"
    local dst="$2"
    echo "Copying $src to $dst"
    
    if command -v sshpass &> /dev/null; then
        sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no "$src" "$TARGET_USER@$TARGET_HOST:$dst"
    else
        # Use expect as fallback
        expect -c "
            set timeout 60
            spawn scp $src $TARGET_USER@$TARGET_HOST:$dst
            expect {
                \"password:\" {
                    send \"$TARGET_PASS\r\"
                    expect eof
                }
                eof
            }
        "
    fi
}

echo "Step 1: Creating deployment package..."
tar -czf lpg-deploy-v2.tar.gz config/ scripts/

echo ""
echo "Step 2: Copying deployment package to target server..."
scp_copy "lpg-deploy-v2.tar.gz" "/home/lacissystem/"

echo ""
echo "Step 3: Extracting package on target server..."
ssh_exec "cd /home/lacissystem && tar -xzf lpg-deploy-v2.tar.gz"

echo ""
echo "Step 4: Running setup script with sudo..."
ssh_exec "echo '$TARGET_PASS' | sudo -S /home/lacissystem/scripts/setup-lpg.sh"

echo ""
echo "Step 5: Checking service status..."
ssh_exec "sudo systemctl status caddy --no-pager || true"
ssh_exec "sudo systemctl status vsftpd --no-pager || true"

echo ""
echo "=== Deployment Complete ==="
echo "Access points:"
echo "- Admin UI: https://192.168.234.2:8443"
echo "- FTP: ftp://192.168.234.2:21"
echo "- Main URL: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/"
echo ""
echo "Next steps:"
echo "1. Change default passwords"
echo "2. Test routing to backend services"
echo "3. Configure LacisDrawBoards connection"