#!/usr/bin/env python3
"""
LPG Safe Wrapper
Purpose: Wrap lpg_admin.py with additional safety checks
This wrapper ensures network safety before and during LPG execution
"""

import os
import sys
import signal
import socket
import subprocess
import time
import threading
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/lpg_safe_wrapper.log'),
        logging.StreamHandler()
    ]
)

class SafetyWrapper:
    def __init__(self):
        self.lpg_process = None
        self.monitoring = True
        self.safe_host = "127.0.0.1"
        self.safe_port = 8443
        
    def check_environment(self):
        """Check environment variables for safety"""
        host = os.environ.get('LPG_ADMIN_HOST', '127.0.0.1')
        
        if host == '0.0.0.0':
            logging.critical("FATAL: LPG_ADMIN_HOST is set to 0.0.0.0")
            logging.critical("This would crash the network. Aborting!")
            
            # Set emergency flag
            with open('/var/run/lpg_emergency_abort', 'w') as f:
                f.write("Aborted due to dangerous host setting\n")
            
            sys.exit(1)
        
        # Force safe environment
        os.environ['LPG_ADMIN_HOST'] = self.safe_host
        os.environ['LPG_ADMIN_PORT'] = str(self.safe_port)
        
        logging.info(f"Environment check passed. Host: {self.safe_host}")
        return True
    
    def check_network_state(self):
        """Check if network is in a safe state"""
        try:
            # Check if we can reach the gateway
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('192.168.234.1', 80))
            sock.close()
            
            if result != 0:
                logging.warning("Cannot reach gateway - network may be unstable")
                return False
            
            return True
        except Exception as e:
            logging.error(f"Network check failed: {e}")
            return False
    
    def monitor_lpg_process(self):
        """Monitor the LPG process for dangerous behavior"""
        while self.monitoring and self.lpg_process:
            try:
                # Check if process is still running
                if self.lpg_process.poll() is not None:
                    logging.info("LPG process has terminated")
                    break
                
                # Check for dangerous port bindings
                result = subprocess.run(
                    ['netstat', '-tlnp'],
                    capture_output=True,
                    text=True
                )
                
                if '0.0.0.0:8443' in result.stdout or ':::8443' in result.stdout:
                    logging.critical("DETECTED DANGEROUS BINDING TO 0.0.0.0:8443")
                    logging.critical("KILLING LPG IMMEDIATELY")
                    
                    # Kill the process
                    self.lpg_process.kill()
                    
                    # Kill all lpg_admin.py processes
                    subprocess.run(['pkill', '-9', '-f', 'lpg_admin.py'])
                    
                    # Set emergency flag
                    with open('/var/run/lpg_dangerous_binding', 'w') as f:
                        f.write("Killed due to dangerous binding\n")
                    
                    break
                
                time.sleep(2)
                
            except Exception as e:
                logging.error(f"Monitoring error: {e}")
                time.sleep(2)
    
    def signal_handler(self, signum, frame):
        """Handle signals gracefully"""
        logging.info(f"Received signal {signum}")
        self.monitoring = False
        
        if self.lpg_process:
            logging.info("Terminating LPG process...")
            self.lpg_process.terminate()
            time.sleep(2)
            
            if self.lpg_process.poll() is None:
                logging.warning("Force killing LPG process...")
                self.lpg_process.kill()
    
    def run(self):
        """Run LPG with safety wrapper"""
        logging.info("=== LPG Safe Wrapper Starting ===")
        
        # Check environment
        if not self.check_environment():
            return 1
        
        # Check network state
        if not self.check_network_state():
            logging.warning("Network is not in optimal state")
            # Continue anyway but with extra monitoring
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        # Start monitoring thread
        monitor_thread = threading.Thread(target=self.monitor_lpg_process)
        monitor_thread.daemon = True
        
        try:
            # Start LPG with explicit environment
            env = os.environ.copy()
            env['LPG_ADMIN_HOST'] = self.safe_host
            env['LPG_ADMIN_PORT'] = str(self.safe_port)
            
            logging.info(f"Starting LPG with host={self.safe_host} port={self.safe_port}")
            
            self.lpg_process = subprocess.Popen(
                [sys.executable, '/opt/lpg/src/lpg_admin.py'],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Start monitoring
            monitor_thread.start()
            
            # Wait for process to complete
            stdout, stderr = self.lpg_process.communicate()
            
            if stdout:
                logging.info(f"LPG stdout: {stdout.decode()}")
            if stderr:
                logging.error(f"LPG stderr: {stderr.decode()}")
            
            return_code = self.lpg_process.returncode
            logging.info(f"LPG exited with code {return_code}")
            
            return return_code
            
        except Exception as e:
            logging.error(f"Failed to run LPG: {e}")
            return 1
        finally:
            self.monitoring = False
            
            # Ensure LPG is stopped
            if self.lpg_process and self.lpg_process.poll() is None:
                self.lpg_process.terminate()
                time.sleep(2)
                if self.lpg_process.poll() is None:
                    self.lpg_process.kill()

if __name__ == "__main__":
    wrapper = SafetyWrapper()
    sys.exit(wrapper.run())