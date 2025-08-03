# LacisProxyGateway (LPG)

LacisProxyGateway (LPG) is a reverse proxy component for the LacisDrawBoards system.

## Overview

LPG provides HTTP/HTTPS reverse proxy functionality with a web-based management interface. It routes requests to backend services based on domain and path configurations.

## Features

- **Reverse Proxy**: Domain and path-based routing
- **Web Management UI**: Dark-themed interface for configuration
- **Topology View**: Visual representation of proxy relationships
- **Device Management**: CRUD operations for backend services
- **User Management**: Admin user creation and management
- **Logging**: Access and internal operation logs with JST timezone support
- **HTTPS Support**: Let's Encrypt integration via Nginx

## Installation

1. Clone this repository
2. Install Python dependencies:
   ```bash
   pip3 install flask werkzeug requests
   ```
3. Copy `config.json.sample` to `config.json` and adjust settings
4. Run the proxy server:
   ```bash
   python3 src/lpg-proxy.py
   ```
5. Run the admin interface:
   ```bash
   python3 src/lpg_admin.py
   ```

## Access

- Admin UI: http://[your-ip]:8443
- Default credentials: admin / lpgadmin123

## Directory Structure

```
LPG/
├── src/              # Python source files
│   ├── lpg-proxy.py  # Main proxy server
│   └── lpg_admin.py  # Admin UI Flask app
├── templates/        # HTML templates
├── docs/            # Documentation
├── config.json      # Configuration file
└── README.md        # This file
```

## Documentation

See the `docs/` directory for detailed documentation:
- `FINAL_IMPLEMENTATION_SPEC.md` - Complete implementation specification
- `橙派部署指南.md` - Deployment guide for Orange Pi

## License

This project is part of the LacisDrawBoards system.
EOF < /dev/null
