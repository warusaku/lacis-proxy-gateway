# LPG - Lacis Proxy Gateway

A secure Python-based reverse proxy gateway with web-based admin interface and comprehensive safety mechanisms.

## 🛡️ Safety First

**⚠️ CRITICAL**: This version includes multiple layers of network protection to prevent system-wide failures after lessons learned from production incidents.

### Safety Features:
- **Network Watchdog**: Detects and immediately kills processes binding to dangerous addresses (0.0.0.0)
- **SSH Fallback Protection**: Maintains SSH access even during network failures
- **Safe Wrapper**: Runtime monitoring and environment variable protection
- **Systemd Integration**: Proper service dependencies and safety checks

## Overview

LPG provides HTTP/HTTPS reverse proxy functionality with a web-based management interface for the LacisDrawBoards system. It routes requests to backend services based on domain and path configurations.

## Features

- **Reverse Proxy**: Domain and path-based routing
- **Web Management UI**: Dark-themed unified interface
- **Topology View**: D3.js visual representation of proxy relationships
- **Device Management**: CRUD operations for backend services
- **User Management**: Admin user creation and management
- **Logging**: Access and operation logs with timezone support
- **HTTPS Support**: Let's Encrypt integration via Nginx
- **Network Protection**: Multi-layer safety mechanisms

## ⚠️ Critical Installation Notes

**NEVER run the admin interface without environment protection!**

### Safe Installation

```bash
# 1. Clone this repository
git clone https://github.com/lacis-ai/LacisProxyGateway.git
cd LPG

# 2. Run the safe installation script
sudo ./install.sh

# 3. Test safety mechanisms (TEST ENVIRONMENT ONLY!)
sudo ./test_safety_mechanisms.sh
```

### Manual Installation (Use with caution)

```bash
# Install dependencies
pip3 install flask werkzeug requests

# CRITICAL: Set environment variables
export LPG_ADMIN_HOST=127.0.0.1  # NEVER use 0.0.0.0!
export LPG_ADMIN_PORT=8443

# Use systemd service (recommended)
sudo systemctl start lpg-admin

# OR use safe wrapper
python3 src/lpg_safe_wrapper.py
```

## Access

- Admin UI: https://[your-domain]/lpg-admin/ (via nginx)
- Direct access: http://127.0.0.1:8443 (local only)
- Default credentials: admin / lpgadmin123

## Directory Structure

```
LPG/
├── src/                    # Source code
│   ├── lpg_admin.py       # Admin interface (Flask)
│   ├── lpg-proxy.py       # Main proxy server
│   ├── lpg_safe_wrapper.py # Safety wrapper
│   ├── network_watchdog.py # Network monitor
│   ├── ssh_fallback.sh    # SSH protection
│   └── templates/         # HTML templates (unified theme)
├── systemd/               # Service files with safety
├── nginx/                 # Nginx configurations
├── scripts/               # Deployment and testing
├── docs/                  # Documentation
├── install.sh             # Safe installation script
└── test_safety_mechanisms.sh # Safety test suite
```

## 🚨 Critical Safety Rules

### ❌ NEVER DO THIS:
```python
# Will crash entire network VLAN!
app.run(host='0.0.0.0', port=8443)
```

```bash
# No environment protection!
nohup python3 lpg_admin.py &
```

### ✅ ALWAYS DO THIS:
```bash
# Use environment variables
export LPG_ADMIN_HOST=127.0.0.1
python3 src/lpg_safe_wrapper.py

# Or use systemd service
sudo systemctl start lpg-admin
```

## Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [API Reference](docs/API_REFERENCE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Network Safety Protection](docs/network-safety-protection.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Emergency Recovery

If network issues occur:

1. SSH access (protected by ssh_fallback.sh)
2. Stop service: `sudo systemctl stop lpg-admin`
3. Clear flags: `sudo rm -f /var/run/lpg_emergency_*`
4. Check logs: `sudo tail -100 /var/log/lpg_admin.log`
5. Restart safely: `sudo systemctl start lpg-admin`

## License

This project is part of the LacisDrawBoards system.
