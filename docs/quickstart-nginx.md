# 🚀 Nginx Reverse Proxy - Quick Start

## ✅ What Changed

**Before:** `http://media.homelab.local:8096` ❌ (port required)  
**After:** `http://media.homelab.local` ✅ (clean URL!)

## 📋 Files Added/Modified

### ✨ New Files
```
config/nginx/nginx.conf           # Reverse proxy configuration
docs/reverse-proxy.md             # Complete documentation
NGINX_IMPLEMENTATION.md           # This implementation summary
```

### 📝 Modified Files
```
docker-compose.yml                # Added nginx service
README.md                         # Updated URLs and instructions
```

### ✅ No Changes Needed
```
config/pihole/custom.list         # DNS already correct!
config/pihole/02-homelab.conf     # No changes needed
```

## 🎯 Service URLs (via VPN)

| Old URL (with port) | New URL (clean) |
|---------------------|-----------------|
| http://media.homelab.local:8096 | http://media.homelab.local |
| http://photos.homelab.local:2283 | http://photos.homelab.local |
| http://docs.homelab.local:8000 | http://docs.homelab.local |
| http://portainer.homelab.local:9000 | http://portainer.homelab.local |
| http://element.homelab.local:8081 | http://element.homelab.local |
| http://pihole.homelab.local:8053 | http://pihole.homelab.local |
| http://vpn.homelab.local:51821 | http://vpn.homelab.local |

## 🚀 Deploy Now

```bash
# Navigate to LaunchLab directory
cd C:\Users\swapnil\Documents\swapnil\projects\LaunchLab

# Start all services (including new Nginx)
docker-compose up -d

# Check Nginx is running
docker ps | grep nginx

# View logs
docker-compose logs -f nginx
```

## 🧪 Test It

From a device connected to your WireGuard VPN:

```bash
# Test Jellyfin
curl -I http://media.homelab.local

# Test Immich
curl -I http://photos.homelab.local

# Test Paperless
curl -I http://docs.homelab.local
```

Or open in browser:
- http://media.homelab.local
- http://photos.homelab.local
- http://docs.homelab.local

## ➕ Adding New Services

**3-Step Process:**

1. **Add to docker-compose.yml**
   ```yaml
   my-service:
     networks:
       homelab-net:
         ipv4_address: 172.20.0.99
   ```

2. **Add to config/pihole/custom.list**
   ```
   172.20.0.99 myservice.homelab.local
   ```

3. **Add to config/nginx/nginx.conf**
   ```nginx
   server {
       listen 80;
       server_name myservice.homelab.local;
       location / {
           proxy_pass http://172.20.0.99:80;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

4. **Restart Nginx**
   ```bash
   docker-compose restart nginx
   ```

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| 502 Bad Gateway | Service not running: `docker-compose logs service-name` |
| 404 Not Found | Missing Nginx config: Check `config/nginx/nginx.conf` |
| DNS not resolving | Check Pi-hole: `nslookup service.homelab.local 172.20.0.4` |
| Config error | Test syntax: `docker-compose exec nginx nginx -t` |

## 📚 Documentation

- **Full Guide:** `docs/reverse-proxy.md`
- **Implementation Details:** `NGINX_IMPLEMENTATION.md`
- **Main README:** `README.md`

## ✨ Benefits

✅ Clean URLs without port numbers  
✅ Professional setup  
✅ Easy to add new services  
✅ Future-proof (SSL/TLS ready)  
✅ No Pi-hole changes needed  
✅ Backward compatible (direct ports still work)

---

**Ready to deploy!** 🎉
