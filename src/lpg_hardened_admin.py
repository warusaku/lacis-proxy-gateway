#!/usr/bin/env python3
"""
Hardened LPG Admin wrapper with multiple safety checks
This wrapper ensures lpg_admin.py NEVER binds to 0.0.0.0
"""

import os
import sys
import socket
import subprocess
import time
import signal
import threading

class HardenedLPGAdmin:
    def __init__(self):
        self.lpg_process = None
        self.safe_host = "127.0.0.1"
        self.safe_port = 8443
        self.monitor_thread = None
        self.stop_monitoring = False
        
    def validate_socket_binding(self):
        """Validate that we can bind to safe address before starting LPG"""
        try:
            test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            test_socket.bind((self.safe_host, self.safe_port))
            test_socket.close()
            print(f"✓ Can bind to {self.safe_host}:{self.safe_port}")
            return True
        except Exception as e:
            print(f"✗ Cannot bind to {self.safe_host}:{self.safe_port}: {e}")
            return False
    
    def create_hardened_config(self):
        """Create a hardened configuration file that prevents 0.0.0.0 binding"""
        config_content = f"""
import os

# CRITICAL SAFETY: Force localhost binding
class SafeConfig:
    # Network binding - NEVER change these
    BIND_HOST = '127.0.0.1'  # NEVER use 0.0.0.0
    BIND_PORT = 8443
    
    # Override any environment variables
    @staticmethod
    def get_safe_host():
        # Ignore environment variables that might set 0.0.0.0
        host = os.environ.get('LPG_ADMIN_HOST', '127.0.0.1')
        if host == '0.0.0.0' or host == '':
            print("WARNING: Attempted to bind to 0.0.0.0 - BLOCKED!")
            return '127.0.0.1'
        return '127.0.0.1'  # Always return safe value
    
    @staticmethod  
    def get_safe_port():
        try:
            port = int(os.environ.get('LPG_ADMIN_PORT', '8443'))
            return port
        except:
            return 8443

# Export configuration
SAFE_HOST = SafeConfig.get_safe_host()
SAFE_PORT = SafeConfig.get_safe_port()
"""
        
        with open('/opt/lpg/src/safe_config.py', 'w') as f:
            f.write(config_content)
        
        print("✓ Created hardened configuration")
    
    def patch_lpg_admin(self):
        """Patch lpg_admin.py to use hardened configuration"""
        backup_file = '/opt/lpg/src/lpg_admin.py.backup'
        original_file = '/opt/lpg/src/lpg_admin.py'
        
        # Create backup if not exists
        if not os.path.exists(backup_file):
            subprocess.run(['cp', original_file, backup_file])
        
        # Read original file
        with open(original_file, 'r') as f:
            content = f.read()
        
        # Check if already patched
        if 'safe_config' in content:
            print("✓ lpg_admin.py already patched")
            return
        
        # Add safety import at the beginning
        safety_import = """
# SAFETY PATCH: Prevent 0.0.0.0 binding
try:
    from safe_config import SAFE_HOST, SAFE_PORT
except ImportError:
    SAFE_HOST = '127.0.0.1'
    SAFE_PORT = 8443
"""
        
        # Replace the app.run line
        import re
        
        # Find and replace the app.run section
        pattern = r"if __name__ == '__main__':(.*?)app\.run\((.*?)\)"
        
        def replace_app_run(match):
            return f"""if __name__ == '__main__':{match.group(1)}app.run(host=SAFE_HOST, port=SAFE_PORT, debug=False)"""
        
        content = safety_import + content
        content = re.sub(pattern, replace_app_run, content, flags=re.DOTALL)
        
        # Also replace any direct host/port assignments
        content = re.sub(
            r"host\s*=\s*os\.environ\.get\('LPG_ADMIN_HOST',\s*'[^']+'\)",
            "host = SAFE_HOST",
            content
        )
        content = re.sub(
            r"port\s*=\s*int\(os\.environ\.get\('LPG_ADMIN_PORT',\s*'[^']+'\)\)",
            "port = SAFE_PORT",
            content
        )
        
        # Write patched version
        with open(original_file, 'w') as f:
            f.write(content)
        
        print("✓ Patched lpg_admin.py with safety checks")
    
    def continuous_monitor(self):
        """Continuously monitor for 0.0.0.0 binding"""
        while not self.stop_monitoring:
            try:
                # Check using ss (faster than netstat)
                result = subprocess.run(
                    ['ss', '-tlnp'],
                    capture_output=True,
                    text=True,
                    timeout=1
                )
                
                if '0.0.0.0:8443' in result.stdout or '*:8443' in result.stdout:
                    print("CRITICAL: Detected 0.0.0.0:8443 binding!")
                    
                    # Kill immediately
                    if self.lpg_process:
                        self.lpg_process.kill()
                    
                    subprocess.run(['pkill', '-9', '-f', 'lpg_admin.py'])
                    
                    # Create alert file
                    with open('/var/log/lpg_0.0.0.0_detection.log', 'a') as f:
                        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - 0.0.0.0 binding detected and killed\n")
                    
                    self.stop_monitoring = True
                    break
                
                time.sleep(0.5)  # Check every 500ms
                
            except Exception as e:
                print(f"Monitor error: {e}")
                time.sleep(1)
    
    def run_with_safety(self):
        """Run LPG admin with all safety measures"""
        print("=== Hardened LPG Admin Launcher ===")
        
        # Step 1: Validate socket
        if not self.validate_socket_binding():
            print("Failed to validate socket binding")
            return 1
        
        # Step 2: Create hardened config
        self.create_hardened_config()
        
        # Step 3: Patch lpg_admin.py
        self.patch_lpg_admin()
        
        # Step 4: Set restrictive environment
        env = os.environ.copy()
        env['LPG_ADMIN_HOST'] = '127.0.0.1'
        env['LPG_ADMIN_PORT'] = '8443'
        env['PYTHONPATH'] = '/opt/lpg/src:' + env.get('PYTHONPATH', '')
        
        # Remove any dangerous environment variables
        dangerous_vars = ['FLASK_RUN_HOST', 'FLASK_RUN_PORT', 'WERKZEUG_RUN_MAIN']
        for var in dangerous_vars:
            env.pop(var, None)
        
        # Step 5: Start monitoring thread
        self.monitor_thread = threading.Thread(target=self.continuous_monitor)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        
        # Step 6: Start LPG with safety wrapper
        print(f"Starting LPG Admin on {self.safe_host}:{self.safe_port}")
        
        try:
            self.lpg_process = subprocess.Popen(
                [sys.executable, '/opt/lpg/src/lpg_admin.py'],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Monitor output
            while True:
                output = self.lpg_process.stdout.readline()
                if output:
                    line = output.decode().strip()
                    print(line)
                    
                    # Check for dangerous patterns in output
                    if '0.0.0.0' in line:
                        print("CRITICAL: 0.0.0.0 detected in output!")
                        self.lpg_process.kill()
                        break
                
                # Check if process is still running
                if self.lpg_process.poll() is not None:
                    break
            
            return_code = self.lpg_process.wait()
            print(f"LPG Admin exited with code {return_code}")
            return return_code
            
        except Exception as e:
            print(f"Error running LPG: {e}")
            return 1
        finally:
            self.stop_monitoring = True
            if self.monitor_thread:
                self.monitor_thread.join(timeout=2)

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print(f"Received signal {signum}")
    subprocess.run(['pkill', '-f', 'lpg_admin.py'])
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Run with safety
    launcher = HardenedLPGAdmin()
    sys.exit(launcher.run_with_safety())