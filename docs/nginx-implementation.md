# Nginx Reverse Proxy Implementation - Summary

## What Was Implemented

Added Nginx reverse proxy to LaunchLab to enable clean URLs without port numbers.

## Changes Made

### 1. Created Nginx Configuration
**File:** `config/nginx/nginx.conf`

- Configured 8 server blocks for all LaunchLab services
- Added WebSocket support for services that need it (Jellyfin, Immich, Portainer, WireGuard)
- Optimized settings for media streaming (disabled buffering)
- Set unlimited client body size for photo/media uploads
- Added helpful 404 message listing all available services

### 2. Updated Docker Compose
**File:** `docker-compose.yml`

- Added `nginx` service with Alpine Linux image (nginx:1.27-alpine)
- Assigned static IP: 172.20.0.2
- Mapped host port 80 to container port 80
- Added dependencies on all web services
- Configured health check using `nginx -t`

### 3. Updated Documentation
**File:** `README.md`

- Updated service table to show VPN URLs (e.g., http://media.homelab.local)
- Updated architecture diagram to include Nginx layer
- Added "How Routing Works" explanation
- Added comprehensive "Adding New Services" section with step-by-step instructions
- Updated AI assistant development guide

**File:** `docs/reverse-proxy.md` (NEW)

- Complete reverse proxy documentation
- Architecture explanation with diagrams
- Service routing table
- Step-by-step guide for adding new services
- Troubleshooting section
- Advanced configuration examples
- Future enhancements (SSL/TLS, authentication)

## Service Routing

| Service | Domain | Container IP | Port | Backend |
|---------|--------|--------------|------|---------|
| Jellyfin | media.homelab.local | 172.20.0.21 | 8096 | Media streaming |
| Immich | photos.homelab.local | 172.20.0.20 | 2283 | Photo management |
| Paperless | docs.homelab.local | 172.20.0.50 | 8000 | Document management |
| Portainer | portainer.homelab.local | 172.20.0.10 | 9000 | Container management |
| Element | element.homelab.local | 172.20.0.31 | 80 | Matrix chat client |
| Matrix | matrix.homelab.local | 172.20.0.30 | 8008 | Chat server |
| Pi-hole | pihole.homelab.local | 172.20.0.4 | 80 | DNS & ad blocking |
| WireGuard | vpn.homelab.local | 172.20.0.5 | 51821 | VPN management |

## How It Works

```
User → http://media.homelab.local
  ↓
Pi-hole DNS → 172.20.0.21 (Jellyfin's IP)
  ↓
Browser → 172.20.0.21:80 (default HTTP port)
  ↓
Nginx → Receives request, checks server_name
  ↓
Nginx → Proxies to 172.20.0.21:8096 (Jellyfin's actual port)
  ↓
Jellyfin → Responds
  ↓
User → Sees Jellyfin without typing port numbers!
```

## Key Benefits

✅ **Clean URLs** - No port numbers needed (http://media.homelab.local instead of http://media.homelab.local:8096)
✅ **No Pi-hole changes** - Existing DNS entries work as-is
✅ **Backward compatible** - Direct port access still works (http://localhost:8096)
✅ **Scalable** - Easy to add new services
✅ **Professional** - Industry standard approach
✅ **Future-proof** - Easy to add SSL/TLS later

## Testing

### Validate Configuration
```bash
# Check docker-compose syntax
docker-compose config

# Test Nginx configuration (after starting)
docker-compose exec nginx nginx -t
```

### Start Services
```bash
# Start all services including Nginx
docker-compose up -d

# Check Nginx is running
docker ps | grep nginx

# View Nginx logs
docker-compose logs nginx
```

### Test Access (from VPN-connected device)
```bash
# Test each service
curl -I http://media.homelab.local          # Jellyfin
curl -I http://photos.homelab.local         # Immich
curl -I http://docs.homelab.local           # Paperless
curl -I http://portainer.homelab.local      # Portainer
curl -I http://element.homelab.local        # Element
curl -I http://matrix.homelab.local         # Matrix
curl -I http://pihole.homelab.local         # Pi-hole
curl -I http://vpn.homelab.local            # WireGuard

# All should return HTTP 200 OK or 302 redirect
```

### Browser Test
Open browser and navigate to:
- http://media.homelab.local → Should show Jellyfin
- http://photos.homelab.local → Should show Immich
- http://docs.homelab.local → Should show Paperless

## Adding New Services (Quick Reference)

When adding a new service:

1. **docker-compose.yml** - Add service with static IP
2. **config/pihole/custom.list** - Add DNS entry
3. **config/nginx/nginx.conf** - Add server block
4. **Restart** - `docker-compose restart nginx`
5. **Test** - `curl -I http://newservice.homelab.local`

See `docs/reverse-proxy.md` for detailed instructions.

## Troubleshooting

**502 Bad Gateway**
- Service not running: `docker ps`
- Check logs: `docker-compose logs service-name`

**404 Not Found**
- Missing Nginx server block
- Check `config/nginx/nginx.conf`
- Restart Nginx: `docker-compose restart nginx`

**DNS Not Resolving**
- Check Pi-hole custom list
- Verify client using Pi-hole DNS
- Test: `nslookup service.homelab.local 172.20.0.4`

## Files Modified/Created

### Created
- `config/nginx/nginx.conf` - Nginx reverse proxy configuration
- `docs/reverse-proxy.md` - Comprehensive documentation

### Modified
- `docker-compose.yml` - Added Nginx service
- `README.md` - Updated service table, architecture, and instructions

### Unchanged (No Changes Needed)
- `config/pihole/custom.list` - DNS entries already correct!
- `config/pihole/02-homelab.conf` - No changes needed
- All service configurations - Work as-is

## Next Steps

1. **Deploy** - Start services with `docker-compose up -d`
2. **Test** - Verify all services accessible via clean URLs
3. **Document** - Update any internal documentation
4. **Consider SSL** - Add HTTPS in the future (see docs/reverse-proxy.md)

---

**Implementation Date:** 2026-01-13
**Status:** ✅ Complete and ready for deployment
