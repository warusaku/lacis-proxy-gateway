#!/usr/bin/env python3
"""
Enhanced LPG Network Watchdog with Auto-Recovery
Purpose: Monitor network health, prevent 0.0.0.0 binding, and auto-recover from failures
Version: 2.0
Critical: This script prevents network-wide outages and ensures automatic recovery
"""

import os
import sys
import time
import signal
import socket
import subprocess
import logging
from datetime import datetime
import psutil
import threading

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/lpg_watchdog.log'),
        logging.StreamHandler()
    ]
)

class EnhancedNetworkWatchdog:
    def __init__(self):
        self.gateway_ip = "192.168.234.1"  # ER605 router
        self.local_ip = "192.168.234.2"
        self.interface = "eth0"
        self.check_interval = 2  # Faster detection (was 5)
        self.failure_threshold = 3
        self.failure_count = 0
        self.lpg_process_names = ['lpg_admin.py', 'lpg-proxy.py', 'lpg_server.py']
        self.recovery_attempts = 0
        self.max_recovery_attempts = 3
        
        # Pre-emptive monitoring
        self.preemptive_check_interval = 0.5  # 500ms for 0.0.0.0 detection
        self.monitoring_thread = None
        self.stop_monitoring = False
        
    def preemptive_port_monitor(self):
        """Ultra-fast 0.0.0.0 binding detection thread"""
        logging.info("Starting pre-emptive port monitoring (500ms interval)")
        
        while not self.stop_monitoring:
            try:
                # Direct netstat parsing for speed
                result = subprocess.run(
                    ['ss', '-tlnp'],  # ss is faster than netstat
                    capture_output=True,
                    text=True,
                    timeout=1
                )
                
                if '0.0.0.0:8443' in result.stdout or '*:8443' in result.stdout:
                    logging.critical("DETECTED 0.0.0.0:8443 BINDING - IMMEDIATE ACTION!")
                    self.instant_kill_lpg()
                    self.network_recovery()
                    
                time.sleep(self.preemptive_check_interval)
                
            except Exception as e:
                logging.error(f"Pre-emptive monitoring error: {e}")
                time.sleep(1)
    
    def instant_kill_lpg(self):
        """Instantly kill all LPG processes without delay"""
        # Use SIGKILL for immediate termination
        for proc_name in self.lpg_process_names:
            subprocess.run(['pkill', '-9', '-f', proc_name], timeout=1)
        
        # Double-check with process iteration
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info.get('cmdline', []))
                if any(lpg in cmdline for lpg in self.lpg_process_names):
                    os.kill(proc.info['pid'], signal.SIGKILL)
                    logging.critical(f"FORCE KILLED: PID {proc.info['pid']}")
            except:
                pass
    
    def check_gateway_connectivity(self):
        """Check if gateway is reachable"""
        try:
            # Use arping for L2 connectivity check (faster than ping)
            result = subprocess.run(
                ['arping', '-c', '1', '-w', '1', self.gateway_ip],
                capture_output=True,
                timeout=2
            )
            
            if result.returncode != 0:
                # Fallback to ping
                result = subprocess.run(
                    ['ping', '-c', '1', '-W', '1', self.gateway_ip],
                    capture_output=True,
                    timeout=2
                )
            
            return result.returncode == 0
        except Exception as e:
            logging.error(f"Gateway check failed: {e}")
            return False
    
    def network_recovery(self):
        """Comprehensive network recovery procedure"""
        self.recovery_attempts += 1
        logging.warning(f"Starting network recovery (attempt {self.recovery_attempts}/{self.max_recovery_attempts})")
        
        recovery_steps = [
            self.step1_kill_all_lpg,
            self.step2_clear_arp_table,
            self.step3_reset_interface,
            self.step4_renew_dhcp,
            self.step5_verify_connectivity,
            self.step6_restart_safe_lpg
        ]
        
        for step in recovery_steps:
            if not step():
                logging.error(f"Recovery step failed: {step.__name__}")
                if self.recovery_attempts >= self.max_recovery_attempts:
                    self.emergency_reboot()
                    return False
        
        logging.info("Network recovery completed successfully")
        self.recovery_attempts = 0
        return True
    
    def step1_kill_all_lpg(self):
        """Step 1: Ensure all LPG processes are dead"""
        logging.info("Recovery Step 1: Killing all LPG processes")
        self.instant_kill_lpg()
        
        # Stop systemd services
        for service in ['lpg-admin.service', 'lpg-proxy.service']:
            subprocess.run(['systemctl', 'stop', service])
            subprocess.run(['systemctl', 'disable', service])  # Prevent auto-restart during recovery
        
        return True
    
    def step2_clear_arp_table(self):
        """Step 2: Clear ARP cache to remove any poisoned entries"""
        logging.info("Recovery Step 2: Clearing ARP table")
        try:
            subprocess.run(['ip', '-s', 'neigh', 'flush', 'all'], timeout=5)
            subprocess.run(['arp', '-d', self.gateway_ip], timeout=2)
            return True
        except Exception as e:
            logging.error(f"ARP clear failed: {e}")
            return False
    
    def step3_reset_interface(self):
        """Step 3: Reset network interface"""
        logging.info("Recovery Step 3: Resetting network interface")
        try:
            # Down
            subprocess.run(['ip', 'link', 'set', self.interface, 'down'], timeout=5)
            time.sleep(2)
            
            # Flush addresses
            subprocess.run(['ip', 'addr', 'flush', 'dev', self.interface], timeout=5)
            
            # Up
            subprocess.run(['ip', 'link', 'set', self.interface, 'up'], timeout=5)
            time.sleep(3)
            
            return True
        except Exception as e:
            logging.error(f"Interface reset failed: {e}")
            return False
    
    def step4_renew_dhcp(self):
        """Step 4: Renew DHCP lease"""
        logging.info("Recovery Step 4: Renewing DHCP lease")
        try:
            # Kill existing dhclient
            subprocess.run(['pkill', 'dhclient'], timeout=2)
            time.sleep(1)
            
            # Release
            subprocess.run(['dhclient', '-r', self.interface], timeout=10)
            time.sleep(2)
            
            # Renew
            result = subprocess.run(['dhclient', '-v', self.interface], 
                                  capture_output=True, timeout=30)
            
            if result.returncode != 0:
                # Try static IP as fallback
                logging.warning("DHCP failed, setting static IP")
                subprocess.run(['ip', 'addr', 'add', f'{self.local_ip}/24', 
                              'dev', self.interface], timeout=5)
                subprocess.run(['ip', 'route', 'add', 'default', 'via', 
                              self.gateway_ip], timeout=5)
            
            return True
        except Exception as e:
            logging.error(f"DHCP renewal failed: {e}")
            return False
    
    def step5_verify_connectivity(self):
        """Step 5: Verify network connectivity"""
        logging.info("Recovery Step 5: Verifying connectivity")
        
        # Check gateway
        if not self.check_gateway_connectivity():
            logging.error("Gateway still unreachable")
            return False
        
        # Check DNS
        try:
            socket.gethostbyname('google.com')
            logging.info("DNS resolution working")
        except:
            logging.warning("DNS not working, setting fallback")
            subprocess.run(['echo', 'nameserver 8.8.8.8', '>', 
                          '/etc/resolv.conf'], shell=True)
        
        return True
    
    def step6_restart_safe_lpg(self):
        """Step 6: Restart LPG with enhanced safety"""
        logging.info("Recovery Step 6: Restarting LPG with safety measures")
        
        # Set restrictive environment
        safe_env = os.environ.copy()
        safe_env['LPG_ADMIN_HOST'] = '127.0.0.1'
        safe_env['LPG_ADMIN_PORT'] = '8443'
        safe_env['LPG_PROXY_HOST'] = '127.0.0.1'
        safe_env['LPG_PROXY_PORT'] = '8080'
        
        # Create safety wrapper script
        wrapper_script = """#!/bin/bash
export LPG_ADMIN_HOST=127.0.0.1
export LPG_ADMIN_PORT=8443
export LPG_PROXY_HOST=127.0.0.1
export LPG_PROXY_PORT=8080

# Check for 0.0.0.0 binding every second
while true; do
    if ss -tlnp | grep -E '0.0.0.0:8443|\\*:8443'; then
        echo "FATAL: 0.0.0.0 binding detected!"
        pkill -9 -f lpg
        exit 1
    fi
    sleep 1
done &

MONITOR_PID=$!

# Start LPG
python3 /opt/lpg/src/lpg_admin.py &
LPG_PID=$!

# Wait for LPG or monitor to exit
wait -n $LPG_PID $MONITOR_PID
"""
        
        with open('/tmp/lpg_safe_start.sh', 'w') as f:
            f.write(wrapper_script)
        
        os.chmod('/tmp/lpg_safe_start.sh', 0o755)
        
        # Start with wrapper
        subprocess.Popen(['/tmp/lpg_safe_start.sh'], env=safe_env)
        
        # Re-enable services
        for service in ['lpg-admin.service', 'lpg-proxy.service']:
            subprocess.run(['systemctl', 'enable', service])
        
        return True
    
    def emergency_reboot(self):
        """Last resort: System reboot"""
        logging.critical("EMERGENCY: All recovery attempts failed - SYSTEM REBOOT")
        
        # Create persistent flag for post-reboot investigation
        with open('/var/log/lpg_emergency_reboot.flag', 'w') as f:
            f.write(f"Emergency reboot at {datetime.now()}\n")
            f.write(f"Gateway: {self.gateway_ip} unreachable\n")
            f.write(f"Recovery attempts: {self.recovery_attempts}\n")
        
        # Sync filesystem
        subprocess.run(['sync'])
        time.sleep(2)
        
        # Force reboot
        subprocess.run(['shutdown', '-r', 'now'])
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logging.info(f"Received signal {signum}")
        self.stop_monitoring = True
        sys.exit(0)
    
    def run(self):
        """Main watchdog loop with enhanced monitoring"""
        logging.info("Enhanced LPG Network Watchdog v2.0 started")
        logging.info(f"Gateway: {self.gateway_ip}, Interface: {self.interface}")
        logging.info(f"Check interval: {self.check_interval}s, Pre-emptive: {self.preemptive_check_interval}s")
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        # Start pre-emptive monitoring thread
        self.monitoring_thread = threading.Thread(target=self.preemptive_port_monitor)
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        
        # Main monitoring loop
        while True:
            try:
                # Regular gateway check
                if not self.check_gateway_connectivity():
                    self.failure_count += 1
                    logging.warning(f"Gateway unreachable ({self.failure_count}/{self.failure_threshold})")
                    
                    if self.failure_count >= self.failure_threshold:
                        logging.critical("Network failure threshold reached - starting recovery")
                        self.network_recovery()
                        self.failure_count = 0
                else:
                    if self.failure_count > 0:
                        logging.info("Gateway connectivity restored")
                    self.failure_count = 0
                
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logging.error(f"Main loop error: {e}")
                time.sleep(self.check_interval)

if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
    
    # Check for previous emergency reboot
    if os.path.exists('/var/log/lpg_emergency_reboot.flag'):
        print("WARNING: Previous emergency reboot detected")
        with open('/var/log/lpg_emergency_reboot.flag', 'r') as f:
            print(f.read())
        
        # Archive the flag
        os.rename('/var/log/lpg_emergency_reboot.flag', 
                 f'/var/log/lpg_emergency_reboot_{datetime.now().strftime("%Y%m%d_%H%M%S")}.flag')
    
    watchdog = EnhancedNetworkWatchdog()
    watchdog.run()