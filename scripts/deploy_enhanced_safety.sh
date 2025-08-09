#!/bin/bash
# Deploy Enhanced Safety Mechanisms for LPG
# This script installs the hardened watchdog and admin services

set -e

echo "=== LPG Enhanced Safety Deployment ==="
echo "This script will deploy enhanced safety mechanisms to prevent network failures"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Backup existing files
echo "1. Creating backups..."
BACKUP_DIR="/opt/lpg/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup existing watchdog and admin files
if [ -f "/opt/lpg/src/network_watchdog.py" ]; then
    cp /opt/lpg/src/network_watchdog.py "$BACKUP_DIR/"
fi
if [ -f "/opt/lpg/src/lpg_admin.py" ]; then
    cp /opt/lpg/src/lpg_admin.py "$BACKUP_DIR/"
fi

# Stop existing services
echo "2. Stopping existing services..."
systemctl stop lpg-admin.service 2>/dev/null || true
systemctl stop lpg-proxy.service 2>/dev/null || true
systemctl stop lpg-watchdog.service 2>/dev/null || true

# Kill any running LPG processes
pkill -f lpg_admin.py 2>/dev/null || true
pkill -f lpg-proxy.py 2>/dev/null || true
pkill -f network_watchdog.py 2>/dev/null || true

# Copy new files
echo "3. Installing enhanced components..."
cp enhanced_network_watchdog.py /opt/lpg/src/
cp lpg_hardened_admin.py /opt/lpg/src/
chmod +x /opt/lpg/src/enhanced_network_watchdog.py
chmod +x /opt/lpg/src/lpg_hardened_admin.py

# Install systemd services
echo "4. Installing systemd services..."
cp ../systemd/lpg-watchdog-enhanced.service /etc/systemd/system/
cp ../systemd/lpg-admin-hardened.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Install required packages
echo "5. Installing required packages..."
apt-get update
apt-get install -y arping 2>/dev/null || true
pip3 install psutil 2>/dev/null || true

# Enable hardware watchdog (Orange Pi Zero 3)
echo "6. Configuring hardware watchdog..."
modprobe sunxi_wdt 2>/dev/null || true
echo "sunxi_wdt" >> /etc/modules-load.d/watchdog.conf

# Configure watchdog daemon
cat > /etc/watchdog.conf << EOF
# Hardware watchdog configuration
watchdog-device = /dev/watchdog
watchdog-timeout = 60
interval = 10
realtime = yes
priority = 1

# Network monitoring
ping = 192.168.234.1
interface = eth0

# If network fails, reboot
repair-binary = /usr/sbin/reboot
EOF

# Create network recovery script
echo "7. Creating network recovery script..."
cat > /usr/local/bin/lpg-network-recovery.sh << 'EOF'
#!/bin/bash
# Emergency network recovery script

echo "$(date): Network recovery initiated" >> /var/log/lpg-recovery.log

# Kill all LPG processes
pkill -9 -f lpg

# Reset network
ip link set eth0 down
sleep 2
ip link set eth0 up
dhclient -r eth0
dhclient eth0

# Clear ARP
ip neigh flush all

# Test connectivity
if ping -c 1 -W 2 192.168.234.1 > /dev/null 2>&1; then
    echo "$(date): Network recovered" >> /var/log/lpg-recovery.log
    systemctl start lpg-admin-hardened.service
else
    echo "$(date): Network recovery failed - rebooting" >> /var/log/lpg-recovery.log
    shutdown -r now
fi
EOF

chmod +x /usr/local/bin/lpg-network-recovery.sh

# Create cron job for additional monitoring
echo "8. Setting up cron monitoring..."
cat > /etc/cron.d/lpg-safety << EOF
# Check for 0.0.0.0 binding every minute
* * * * * root /usr/bin/ss -tlnp | grep -E '0.0.0.0:8443|\*:8443' && (pkill -9 -f lpg; echo "\$(date): 0.0.0.0 binding detected and killed" >> /var/log/lpg-safety.log)

# Network health check every 5 minutes
*/5 * * * * root ping -c 1 -W 2 192.168.234.1 || /usr/local/bin/lpg-network-recovery.sh
EOF

# Set up iptables rules to block 0.0.0.0:8443
echo "9. Setting up firewall rules..."
iptables -A INPUT -p tcp -d 0.0.0.0 --dport 8443 -j DROP
iptables -A INPUT -p tcp -s 127.0.0.1 -d 127.0.0.1 --dport 8443 -j ACCEPT
iptables -A INPUT -p tcp -s 192.168.234.0/24 -d 192.168.234.2 --dport 8443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j DROP

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Enable services
echo "10. Enabling services..."
systemctl enable lpg-watchdog-enhanced.service
systemctl enable lpg-admin-hardened.service

# Start services
echo "11. Starting services..."
systemctl start lpg-watchdog-enhanced.service
sleep 5
systemctl start lpg-admin-hardened.service

# Verify services
echo ""
echo "=== Service Status ==="
systemctl status lpg-watchdog-enhanced.service --no-pager | head -10
echo ""
systemctl status lpg-admin-hardened.service --no-pager | head -10

# Check for 0.0.0.0 binding
echo ""
echo "=== Port Binding Check ==="
ss -tlnp | grep 8443

# Final message
echo ""
echo "=== Deployment Complete ==="
echo "Enhanced safety mechanisms have been deployed:"
echo "✓ Enhanced network watchdog with auto-recovery"
echo "✓ Hardened LPG admin with 0.0.0.0 prevention"
echo "✓ Systemd watchdog integration"
echo "✓ Hardware watchdog configuration"
echo "✓ Automatic network recovery"
echo "✓ Firewall rules"
echo ""
echo "The system will now:"
echo "1. Kill LPG immediately if 0.0.0.0 binding is detected"
echo "2. Automatically recover network connectivity"
echo "3. Reboot system if recovery fails 3 times in 5 minutes"
echo ""
echo "Monitor logs at:"
echo "  /var/log/lpg_watchdog.log"
echo "  /var/log/lpg-safety.log"
echo "  /var/log/lpg-recovery.log"