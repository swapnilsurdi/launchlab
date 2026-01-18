# Nginx Reverse Proxy Documentation

## Overview

LaunchLab uses **Nginx as a reverse proxy** to enable clean URLs without port numbers. This means you can access services via `http://media.homelab.local` instead of `http://media.homelab.local:8096`.

## Why Use a Reverse Proxy?

### The Problem

When you navigate to a URL without specifying a port, browsers default to port 80 for HTTP. However, most services run on non-standard ports:
- Jellyfin: 8096
- Immich: 2283
- Paperless: 8000
- Portainer: 9000

Without a reverse proxy, users would need to remember and type port numbers for every service.

### The Solution

Nginx listens on port 80 for each service's domain name and forwards requests to the appropriate service port. This provides:

✅ **Clean URLs** - No port numbers needed  
✅ **Centralized routing** - Single entry point for all services  
✅ **Future extensibility** - Easy to add SSL/TLS later  
✅ **Professional setup** - Industry standard approach  

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User types: http://media.homelab.local                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Pi-hole DNS resolves: media.homelab.local → 172.20.0.21  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Browser connects to: 172.20.0.21:80 (default HTTP port)  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Nginx receives request on port 80                        │
│    - Checks server_name: media.homelab.local                │
│    - Matches Jellyfin server block                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Nginx proxies to: http://172.20.0.21:8096               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Jellyfin responds, Nginx forwards response to user       │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Structure

### Nginx Configuration File

Location: `config/nginx/nginx.conf`

The configuration file contains:
1. **Global settings** - Worker processes, logging, compression
2. **Server blocks** - One per service, defining routing rules
3. **Proxy headers** - Forward client information to backend services

### Example Server Block

```nginx
server {
    listen 80;
    server_name media.homelab.local jellyfin.homelab.local;
    
    location / {
        proxy_pass http://172.20.0.21:8096;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Disable buffering for streaming
        proxy_buffering off;
    }
    
    # WebSocket support
    location /socket {
        proxy_pass http://172.20.0.21:8096;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Service Routing Table

| Domain | Container IP | Service Port | Backend Service |
|--------|--------------|--------------|-----------------|
| media.homelab.local | 172.20.0.21 | 8096 | Jellyfin |
| photos.homelab.local | 172.20.0.20 | 2283 | Immich |
| docs.homelab.local | 172.20.0.50 | 8000 | Paperless |
| portainer.homelab.local | 172.20.0.10 | 9000 | Portainer |
| element.homelab.local | 172.20.0.31 | 80 | Element Web |
| matrix.homelab.local | 172.20.0.30 | 8008 | Matrix Synapse |
| pihole.homelab.local | 172.20.0.4 | 80 | Pi-hole |
| vpn.homelab.local | 172.20.0.5 | 51821 | WireGuard |

## Adding a New Service

Follow these steps when adding a new service to LaunchLab:

### Step 1: Add Service to Docker Compose

Edit `docker-compose.yml`:

```yaml
my-service:
  image: myservice/myservice:latest
  container_name: my-service
  restart: unless-stopped
  ports:
    - "8888:80"  # Optional: for direct access
  networks:
    homelab-net:
      ipv4_address: 172.20.0.99  # Choose an unused IP
```

### Step 2: Add DNS Entry

Edit `config/pihole/custom.list`:

```
172.20.0.99 myservice.homelab.local
```

### Step 3: Add Nginx Server Block

Edit `config/nginx/nginx.conf` and add before the default server block:

```nginx
# ==============================================
# MY SERVICE - Description
# ==============================================
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

**For services requiring WebSocket support**, add:

```nginx
location / {
    proxy_pass http://172.20.0.99:80;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### Step 4: Validate and Restart

```bash
# Test Nginx configuration syntax
docker-compose exec nginx nginx -t

# If valid, restart Nginx to apply changes
docker-compose restart nginx

# Start the new service
docker-compose up -d my-service
```

### Step 5: Test Access

```bash
# From VPN-connected device
curl -I http://myservice.homelab.local

# Should return HTTP 200 OK
```

## Troubleshooting

### Service Returns 404

**Symptom:** Accessing `http://service.homelab.local` returns "Service not found"

**Cause:** Nginx doesn't have a server block for that domain

**Solution:**
1. Check if server block exists in `config/nginx/nginx.conf`
2. Verify `server_name` matches the domain you're accessing
3. Restart Nginx: `docker-compose restart nginx`

### Service Returns 502 Bad Gateway

**Symptom:** Nginx returns "502 Bad Gateway"

**Cause:** Backend service is not running or not reachable

**Solution:**
1. Check if service is running: `docker ps | grep service-name`
2. Verify service is healthy: `docker-compose logs service-name`
3. Check IP address in `proxy_pass` matches container IP
4. Verify port number in `proxy_pass` matches service port

### DNS Not Resolving

**Symptom:** Browser says "Server not found"

**Cause:** Pi-hole doesn't have DNS entry or client not using Pi-hole

**Solution:**
1. Verify entry in `config/pihole/custom.list`
2. Check client is using Pi-hole as DNS server
3. Flush DNS cache on client device
4. Test with: `nslookup service.homelab.local 172.20.0.4`

### WebSocket Connection Fails

**Symptom:** Real-time features don't work (chat, live updates)

**Cause:** Nginx not configured for WebSocket proxying

**Solution:**
Add WebSocket headers to the location block:

```nginx
location / {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    # ... other headers
}
```

### Configuration Syntax Error

**Symptom:** Nginx won't start after config change

**Solution:**
```bash
# Test configuration
docker-compose exec nginx nginx -t

# View detailed error
docker-compose logs nginx

# Common issues:
# - Missing semicolon at end of line
# - Unclosed { } braces
# - Duplicate server_name entries
```

## Advanced Configuration

### Custom Headers

Add custom headers for specific services:

```nginx
location / {
    proxy_pass http://172.20.0.99:80;
    
    # Custom headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
}
```

### URL Rewriting

Rewrite URLs before proxying:

```nginx
location /api/ {
    rewrite ^/api/(.*)$ /$1 break;
    proxy_pass http://172.20.0.99:80;
}
```

### Rate Limiting

Protect services from abuse:

```nginx
http {
    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;
    
    server {
        location / {
            limit_req zone=mylimit burst=20;
            proxy_pass http://172.20.0.99:80;
        }
    }
}
```

### Client Body Size

Allow large file uploads:

```nginx
server {
    # Allow unlimited upload size (for media/photos)
    client_max_body_size 0;
    
    location / {
        proxy_pass http://172.20.0.99:80;
    }
}
```

## Future Enhancements

### Adding SSL/TLS (HTTPS)

To add HTTPS support in the future:

1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update Nginx to listen on port 443
3. Add SSL configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name media.homelab.local;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # ... rest of config
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name media.homelab.local;
    return 301 https://$server_name$request_uri;
}
```

### Authentication Layer

Add basic authentication for extra security:

```nginx
server {
    location / {
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://172.20.0.99:80;
    }
}
```

## Best Practices

1. **Always test configuration** before restarting: `nginx -t`
2. **Use meaningful server names** that match DNS entries
3. **Keep proxy headers consistent** across all server blocks
4. **Comment your configuration** for future reference
5. **Monitor Nginx logs** for errors: `docker-compose logs nginx`
6. **Version control** your `nginx.conf` file
7. **Document custom changes** in this file

## References

- [Nginx Official Documentation](https://nginx.org/en/docs/)
- [Nginx Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [WebSocket Proxying](https://nginx.org/en/docs/http/websocket.html)
- [Pi-hole Documentation](https://docs.pi-hole.net/)

---

**Last Updated:** 2026-01-13  
**Maintained By:** LaunchLab Contributors
