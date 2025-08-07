#!/usr/bin/env python3
"""
LPG Network Watchdog
Purpose: Monitor network health and automatically kill LPG if network issues detected
Version: 1.0
Critical: This script prevents network-wide outages
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

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/lpg_watchdog.log'),
        logging.StreamHandler()
    ]
)

class NetworkWatchdog:
    def __init__(self):
        self.gateway_ip = "192.168.234.1"  # ER605 router
        self.local_ip = "192.168.234.2"
        self.check_interval = 5  # seconds
        self.failure_threshold = 3  # consecutive failures before action
        self.failure_count = 0
        self.lpg_process_names = ['lpg_admin.py', 'lpg-proxy.py']
        
    def check_gateway_connectivity(self):
        """Check if gateway is reachable"""
        try:
            # Ping gateway
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '1', self.gateway_ip],
                capture_output=True,
                text=True,
                timeout=2
            )
            return result.returncode == 0
        except Exception as e:
            logging.error(f"Gateway check failed: {e}")
            return False
    
    def check_port_binding(self):
        """Check if any process is binding to 0.0.0.0"""
        dangerous_bindings = []
        try:
            connections = psutil.net_connections()
            for conn in connections:
                if conn.status == 'LISTEN':
                    # Check for 0.0.0.0 binding
                    if conn.laddr and conn.laddr.ip == '0.0.0.0':
                        # Get process info
                        try:
                            proc = psutil.Process(conn.pid)
                            if any(lpg in proc.name() or lpg in ' '.join(proc.cmdline()) 
                                   for lpg in self.lpg_process_names):
                                dangerous_bindings.append({
                                    'pid': conn.pid,
                                    'name': proc.name(),
                                    'port': conn.laddr.port,
                                    'cmdline': ' '.join(proc.cmdline())
                                })
                        except:
                            pass
        except Exception as e:
            logging.error(f"Port binding check failed: {e}")
        
        return dangerous_bindings
    
    def kill_dangerous_processes(self, processes):
        """Kill processes that are binding to 0.0.0.0"""
        for proc in processes:
            try:
                logging.critical(f"KILLING DANGEROUS PROCESS: PID {proc['pid']} - {proc['name']} on 0.0.0.0:{proc['port']}")
                os.kill(proc['pid'], signal.SIGKILL)
                
                # Log to system journal
                subprocess.run([
                    'logger',
                    '-p', 'emerg',
                    f"LPG WATCHDOG: Killed dangerous process {proc['name']} (PID {proc['pid']}) binding to 0.0.0.0"
                ])
            except Exception as e:
                logging.error(f"Failed to kill process {proc['pid']}: {e}")
    
    def emergency_shutdown(self):
        """Emergency shutdown of all LPG processes"""
        logging.critical("EMERGENCY SHUTDOWN: Network connectivity lost, killing all LPG processes")
        
        # Kill all LPG processes
        for proc_name in self.lpg_process_names:
            try:
                subprocess.run(['pkill', '-9', '-f', proc_name])
                logging.info(f"Killed all {proc_name} processes")
            except:
                pass
        
        # Disable services
        try:
            subprocess.run(['systemctl', 'stop', 'lpg-admin.service'])
            subprocess.run(['systemctl', 'stop', 'lpg-proxy.service'])
            logging.info("Stopped LPG services")
        except:
            pass
        
        # Create emergency flag file
        with open('/var/run/lpg_emergency_shutdown', 'w') as f:
            f.write(f"Emergency shutdown at {datetime.now()}\n")
            f.write("Network connectivity lost - LPG killed to protect network\n")
        
        # Send alert to syslog
        subprocess.run([
            'logger',
            '-p', 'emerg',
            'LPG WATCHDOG: Emergency shutdown executed - network protection activated'
        ])
    
    def run(self):
        """Main watchdog loop"""
        logging.info("LPG Network Watchdog started")
        logging.info(f"Monitoring gateway: {self.gateway_ip}")
        logging.info(f"Check interval: {self.check_interval}s")
        logging.info(f"Failure threshold: {self.failure_threshold}")
        
        while True:
            try:
                # Check for dangerous port bindings (highest priority)
                dangerous_procs = self.check_port_binding()
                if dangerous_procs:
                    logging.critical(f"DETECTED {len(dangerous_procs)} DANGEROUS BINDINGS TO 0.0.0.0")
                    self.kill_dangerous_processes(dangerous_procs)
                    time.sleep(1)  # Brief pause after killing
                    continue
                
                # Check gateway connectivity
                if not self.check_gateway_connectivity():
                    self.failure_count += 1
                    logging.warning(f"Gateway unreachable ({self.failure_count}/{self.failure_threshold})")
                    
                    if self.failure_count >= self.failure_threshold:
                        self.emergency_shutdown()
                        logging.critical("Watchdog exiting after emergency shutdown")
                        sys.exit(1)
                else:
                    if self.failure_count > 0:
                        logging.info("Gateway connectivity restored")
                    self.failure_count = 0
                
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                logging.info("Watchdog stopped by user")
                break
            except Exception as e:
                logging.error(f"Watchdog error: {e}")
                time.sleep(self.check_interval)

if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
    
    # Check if emergency shutdown flag exists
    if os.path.exists('/var/run/lpg_emergency_shutdown'):
        print("WARNING: Emergency shutdown flag exists")
        print("Previous emergency shutdown detected")
        print("Remove /var/run/lpg_emergency_shutdown to clear")
    
    watchdog = NetworkWatchdog()
    watchdog.run()