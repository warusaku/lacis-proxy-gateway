#!/bin/bash
# SSH Fallback Protection Script
# Purpose: Ensure SSH access remains available even during network issues
# Version: 1.0

set -e

# Configuration
SSH_PORT=22
FALLBACK_IP="192.168.234.2"
INTERFACE="eth0"
LOG_FILE="/var/log/ssh_fallback.log"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    logger -t "SSH_FALLBACK" "$1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script must be run as root"
    exit 1
fi

log_message "Starting SSH Fallback Protection"

# 1. Ensure SSH is running and configured correctly
setup_ssh() {
    log_message "Configuring SSH for fallback access..."
    
    # Backup current SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # Ensure SSH listens on all interfaces (but with restrictions)
    sed -i 's/^#*ListenAddress.*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
    
    # Ensure root login is permitted (temporarily for emergency)
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    
    # Set SSH to start before network issues
    sed -i 's/^#*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
    
    # Restart SSH
    systemctl restart sshd || systemctl restart ssh
    
    log_message "SSH configured for fallback access"
}

# 2. Create iptables rules to protect SSH
setup_firewall_rules() {
    log_message "Setting up firewall rules for SSH protection..."
    
    # Save current rules
    iptables-save > /etc/iptables/rules.backup.$(date +%Y%m%d_%H%M%S)
    
    # Ensure SSH is always accessible
    iptables -I INPUT 1 -p tcp --dport $SSH_PORT -j ACCEPT
    iptables -I OUTPUT 1 -p tcp --sport $SSH_PORT -j ACCEPT
    
    # Rate limiting for SSH (prevent brute force)
    iptables -A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -m recent --set
    iptables -A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
    
    # Block LPG ports if network issues detected
    iptables -N LPG_BLOCK 2>/dev/null || true
    iptables -F LPG_BLOCK
    iptables -A LPG_BLOCK -p tcp --dport 8443 -j DROP
    iptables -A LPG_BLOCK -p tcp --dport 8080 -j DROP
    
    # Save rules
    iptables-save > /etc/iptables/rules.v4
    
    log_message "Firewall rules configured"
}

# 3. Create network interface fallback
setup_network_fallback() {
    log_message "Setting up network interface fallback..."
    
    # Add static IP as alias (backup connection method)
    ip addr add ${FALLBACK_IP}/24 dev ${INTERFACE} 2>/dev/null || true
    
    # Ensure interface stays up
    ip link set ${INTERFACE} up
    
    # Add static ARP entry for gateway (prevent ARP issues)
    arp -s 192.168.234.1 $(arp -n 192.168.234.1 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' || echo "00:00:00:00:00:00")
    
    log_message "Network fallback configured"
}

# 4. Create emergency SSH tunnel
create_ssh_tunnel() {
    log_message "Creating emergency SSH tunnel script..."
    
    cat > /usr/local/bin/emergency_ssh_tunnel.sh << 'EOF'
#!/bin/bash
# Emergency SSH Tunnel
# Use this to create a reverse SSH tunnel if normal access fails

REMOTE_HOST="YOUR_BACKUP_SERVER"  # Configure this
REMOTE_PORT="2222"
LOCAL_SSH_PORT="22"

# Create reverse tunnel
ssh -R ${REMOTE_PORT}:localhost:${LOCAL_SSH_PORT} \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=no \
    user@${REMOTE_HOST} \
    "echo 'Tunnel established'; sleep infinity"
EOF
    
    chmod +x /usr/local/bin/emergency_ssh_tunnel.sh
    log_message "Emergency SSH tunnel script created"
}

# 5. Create systemd service for SSH protection
create_systemd_service() {
    log_message "Creating systemd service for SSH protection..."
    
    cat > /etc/systemd/system/ssh-fallback.service << 'EOF'
[Unit]
Description=SSH Fallback Protection
Before=network.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/opt/lpg/src/ssh_fallback.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ssh-fallback.service
    
    log_message "SSH fallback service created and enabled"
}

# 6. Monitor and protect SSH
monitor_ssh() {
    log_message "Starting SSH monitoring..."
    
    while true; do
        # Check if SSH is running
        if ! systemctl is-active --quiet sshd && ! systemctl is-active --quiet ssh; then
            log_message "WARNING: SSH is not running! Attempting restart..."
            systemctl start sshd || systemctl start ssh
            
            # If LPG might be causing issues, kill it
            if [ -f /var/run/lpg_emergency_shutdown ]; then
                log_message "Emergency shutdown flag detected, killing LPG processes"
                pkill -9 -f lpg_admin.py || true
                pkill -9 -f lpg-proxy.py || true
            fi
        fi
        
        # Check if we can bind to SSH port
        if ! netstat -tln | grep -q ":${SSH_PORT} "; then
            log_message "ERROR: SSH port not listening! Force restart..."
            systemctl restart sshd || systemctl restart ssh
        fi
        
        sleep 10
    done
}

# Main execution
main() {
    log_message "=== SSH Fallback Protection Setup ==="
    
    setup_ssh
    setup_firewall_rules
    setup_network_fallback
    create_ssh_tunnel
    create_systemd_service
    
    log_message "=== SSH Fallback Protection Setup Complete ==="
    log_message "SSH should remain accessible even during network issues"
    
    # Start monitoring in background
    if [ "${1:-}" = "--monitor" ]; then
        monitor_ssh
    fi
}

# Run main function
main "$@"