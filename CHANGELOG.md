# CHANGELOG

## [2.2.0] - 2025-08-10

### 🎯 Path Rewriting Support for Application Deployment

#### Added
- **Path Rewriting in Proxy**
  - Automatic path prefix removal for backend routing
  - Maps `/lacisstack/boards/` → `/` for backend services
  - Preserves original path in X-Original-Path header
  - Intelligent path transformation logic

- **Enhanced HTTP Method Support**
  - Added HEAD, PUT, DELETE, OPTIONS, PATCH methods
  - Proper HEAD method handling (no body transfer)
  - Full RESTful API compatibility

- **Improved Request Handling**
  - Chunked transfer encoding for large responses
  - Better timeout handling (30 seconds default)
  - Enhanced error logging with detailed messages

- **Additional Proxy Headers**
  - X-Original-Path for debugging
  - X-Real-IP for accurate client tracking
  - X-Forwarded-Proto for protocol awareness

#### Fixed
- **404 Not Found errors for proxied applications**
  - Resolved by implementing path rewriting
  - Applications can now run at root path while accessed via subpaths
  
- **501 Not Implemented for HEAD requests**
  - Added proper HEAD method support
  - Fixed method handling for all HTTP verbs

#### Technical Details
- Path transformation example: `/lacisstack/boards/api/health` → `/api/health`
- Supports applications that expect root-based routing
- Maintains backward compatibility with existing configurations

## [2.1.0] - 2025-08-10

### 🔄 Major Routing Architecture Update

#### Changed
- **BREAKING: Complete nginx configuration overhaul**
  - All traffic now routes through LPG proxy at 127.0.0.1:8443
  - Removed individual service location blocks from nginx
  - Centralized all path-based routing logic within LPG
  - nginx now serves purely as SSL terminator

#### Added
- **Enhanced WebSocket Support**
  - Extended proxy timeouts to 7 days for long-lived connections
  - Disabled proxy buffering for real-time communication
  - Proper WebSocket upgrade header handling

- **Improved Proxy Headers**
  - Added X-Forwarded-Host header
  - Added X-Forwarded-Port header
  - Better client IP tracking with complete header set

#### Fixed
- **502 Bad Gateway errors**
  - Resolved by routing all traffic through LPG
  - Eliminated direct nginx-to-service routing conflicts
  
- **WebSocket connection issues**
  - Fixed with proper upgrade headers and timeout configuration
  
- **SSL cipher compatibility**
  - Updated to modern cipher suite configuration
  - Added TLSv1.3 support

#### Architecture
```
Before: nginx → Individual Services (complex routing)
After:  nginx (SSL) → LPG (all routing) → Services
```

#### Configuration Files Updated
- `nginx/lpg-ssl` - Complete rewrite for centralized routing
- `README.md` - Version bump to 2.1.0

#### Migration Notes
- Update nginx configuration on all deployments
- Restart nginx service after configuration update
- Ensure LPG is running on 127.0.0.1:8443
- All service routing must be configured in LPG, not nginx

---

## [2.0.0] - 2025-08-09

### 🚨 Critical Security Update

#### Added
- **Enhanced Network Watchdog v2.0** - Complete rewrite with auto-recovery capabilities
  - 0.5 second interval monitoring for 0.0.0.0 binding detection
  - 6-step automatic network recovery process
  - System reboot as last resort (after 3 failed recovery attempts)
  
- **Hardened Admin Wrapper** - 7-layer defense against 0.0.0.0 binding
  - Pre-launch socket validation
  - Dynamic source code patching
  - Continuous monitoring thread (500ms intervals)
  - Environment variable sanitization
  
- **Comprehensive Documentation**
  - `docs/NETWORK_FAILURE_PREVENTION.md` - Complete incident analysis and prevention guide
  
- **Deployment Automation**
  - `scripts/deploy_enhanced_safety.sh` - One-click deployment of all safety mechanisms

#### Enhanced
- **systemd Service Configuration**
  - Hardware watchdog integration
  - Automatic restart on failure
  - System reboot on repeated failures
  - Network isolation with IPAddressDeny

#### Fixed
- **Critical: Network-wide failure on 0.0.0.0 binding**
  - Prevented by multi-layer defense system
  - Detection time reduced from 5s to 0.5s
  - Automatic recovery without manual intervention

### Technical Details

#### Performance Improvements
| Metric | Before | After |
|--------|--------|-------|
| 0.0.0.0 Detection | 5 seconds | 0.5 seconds |
| Gateway Monitoring | 5 seconds | 2 seconds |
| Recovery Time | Manual only | Automatic (< 1 minute) |
| Worst Case Recovery | Indefinite | 5 minutes (system reboot) |

#### Files Changed
- `src/enhanced_network_watchdog.py` (new)
- `src/lpg_hardened_admin.py` (new)
- `systemd/lpg-watchdog-enhanced.service` (new)
- `systemd/lpg-admin-hardened.service` (new)
- `scripts/deploy_enhanced_safety.sh` (new)
- `docs/NETWORK_FAILURE_PREVENTION.md` (new)

---

## [1.0.2] - 2025-08-08

### Fixed
- WebSocket proxy configuration
- SSL certificate auto-renewal
- Memory leak in long-running sessions

### Enhanced
- Logging system with rotation
- API response caching
- Error handling in device management

---

## [1.0.1] - 2025-08-06

### Added
- Dark theme UI
- D3.js topology visualization
- Real-time network monitoring

### Fixed
- Login redirect loop
- Session timeout issues
- CORS configuration

---

## [1.0.0] - 2025-08-05

### Initial Release
- Core reverse proxy functionality
- Web-based admin interface
- Device management
- Domain routing configuration
- Basic authentication
- SSL/TLS support with Let's Encrypt

---

*For detailed information about each release, see the corresponding documentation in `/docs/`*