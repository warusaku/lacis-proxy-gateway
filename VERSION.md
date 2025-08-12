# LPG Version v2.31

## Release Date
2025-08-12

## Changes
- Unified config.json between lpg-proxy and lpg_admin  
- Added LacisDrawBoards routing support with basePath
- Fixed devices.json to show all services in admin UI
- Updated nginx proxy configuration for proper routing
- Support for /lacisstack/boards/ prefix

## Configuration Files
- `/etc/lpg/config.json` - Main configuration (symlinked to /opt/lpg/src/config.json)
- `/opt/lpg/src/devices.json` - Device definitions for admin UI
- `/etc/nginx/sites-enabled/lpg-proxy` - Nginx proxy configuration

## Important Notes
- All LPG configuration changes should be made through the admin UI
- Do not modify nginx configurations directly from other projects
- LacisDrawBoards no longer contains any nginx-related code
