# CHANGELOG

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