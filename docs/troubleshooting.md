# LaunchLab Troubleshooting Guide

Common issues and solutions for LaunchLab deployment.

---

## Table of Contents

- [General Issues](#general-issues)
- [Service-Specific Issues](#service-specific-issues)
- [Network Issues](#network-issues)
- [Database Issues](#database-issues)
- [Performance Issues](#performance-issues)
- [Getting Help](#getting-help)

---

## General Issues

### Docker Not Running

**Symptoms:**
- `Cannot connect to the Docker daemon` error
- `docker compose` commands fail

**Solutions:**

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Verify Docker is working
docker run hello-world
```

### Permission Denied

**Symptoms:**
- `Permission denied while trying to connect to Docker daemon socket`
- Cannot access service URLs

**Solutions:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker

# Fix data directory permissions
cd LaunchLab
sudo chown -R $USER:$USER data/
```

### Port Already in Use

**Symptoms:**
- `bind: address already in use` error
- Service fails to start

**Solutions:**

```bash
# Find process using port (example: port 9000)
sudo lsof -i :9000
# or
sudo netstat -tulpn | grep :9000

# Kill process or change port in docker-compose.yml
# Example: Change Portainer to 9001
ports:
  - "9001:9000"  # External:Internal
```

### Out of Disk Space

**Symptoms:**
- Services fail to start
- `no space left on device` errors

**Solutions:**

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Clean up Docker
docker system prune -a --volumes  # WARNING: Removes all unused data

# Check largest directories
du -sh data/* | sort -h

# Consider moving data/ to larger drive
```

---

## Service-Specific Issues

### Portainer Won't Start

**Symptoms:**
- Cannot access http://localhost:9000
- Container exits immediately

**Solutions:**

```bash
# Check logs
docker compose logs portainer

# Common issue: Password file missing
# Recreate container
docker compose down
docker compose up -d portainer

# Verify it's running
docker compose ps portainer
```

### Immich Upload Fails

**Symptoms:**
- Mobile app can't upload photos
- "Network error" in app

**Solutions:**

```bash
# Check Immich logs
docker compose logs immich-server

# Verify ML service is running
docker compose ps immich-ml

# Check disk space in upload directory
du -sh data/immich/upload/

# Restart Immich
docker compose restart immich-server immich-ml
```

### Jellyfin No Media Showing

**Symptoms:**
- Libraries empty after scan
- "No media found" errors

**Solutions:**

```bash
# Verify media paths are mounted
docker exec jellyfin ls /media/movies

# Check permissions (files must be readable)
ls -la /path/to/media/

# Fix permissions
sudo chmod -R 755 /path/to/media/

# Rescan library in Jellyfin UI
# Dashboard → Libraries → Scan All Libraries
```

### Paperless OCR Not Working

**Symptoms:**
- Documents imported but not searchable
- OCR processing stuck

**Solutions:**

```bash
# Check Paperless logs
docker compose logs paperless-ngx

# Check Redis is running
docker compose ps paperless-redis

# Restart Paperless
docker compose restart paperless-ngx

# Check consume directory
ls -la data/paperless/consume/

# Manually trigger processing
docker exec paperless-ngx document_consumer
```

### Matrix Registration Disabled

**Symptoms:**
- Can't register new users in Element
- "Registration is disabled" error

**Solutions:**

```bash
# Enable registration temporarily
docker exec matrix-synapse sed -i 's/enable_registration: false/enable_registration: true/' /data/homeserver.yaml

# Restart Matrix
docker compose restart matrix-synapse

# Register user
docker exec -it matrix-synapse register_new_matrix_user \
  -u username \
  -p password \
  -a \  # Admin user
  http://localhost:8008

# Disable registration again (security)
docker exec matrix-synapse sed -i 's/enable_registration: true/enable_registration: false/' /data/homeserver.yaml
docker compose restart matrix-synapse
```

### Pi-hole Not Blocking Ads

**Symptoms:**
- Ads still showing on devices
- Pi-hole not being used

**Solutions:**

```bash
# Verify Pi-hole is running
docker compose ps pihole

# Check DNS is set on device
# Windows: ipconfig /all
# Linux: cat /etc/resolv.conf
# macOS: scutil --dns

# Test DNS resolution
dig @localhost google.com

# Check blocklists are updated
# Pi-hole UI → Tools → Update Gravity

# Verify device is using Pi-hole
# Pi-hole UI → Dashboard (should show queries)
```

### WireGuard VPN Not Connecting

**Symptoms:**
- VPN client shows "Handshake failed"
- Can't connect from outside network

**Solutions:**

```bash
# Verify WireGuard is running
docker compose ps wg-easy

# Check router port forwarding
# UDP port 51820 must forward to server IP

# Verify DuckDNS is updating
docker compose logs duckdns

# Check current public IP matches DuckDNS
curl https://ipinfo.io/ip
nslookup yourdomain.duckdns.org

# Regenerate client config if needed
# WireGuard UI → Delete client → Add new client
```

---

## Network Issues

### Can't Access Services Locally

**Symptoms:**
- `Connection refused` errors
- Services unreachable from browser

**Solutions:**

```bash
# Check services are listening
sudo netstat -tulpn | grep docker

# Verify firewall allows traffic
sudo ufw status
sudo ufw allow from 192.168.0.0/16 to any  # Local network

# Test with curl
curl http://localhost:9000

# Check Docker network
docker network inspect launchlab_homelab-net

# Restart Docker network
docker compose down
docker compose up -d
```

### VPN Connected But Services Inaccessible

**Symptoms:**
- VPN shows connected
- Can't access homelab.local domains

**Solutions:**

```bash
# Verify DNS is set to Pi-hole in VPN config
# WireGuard config should have: DNS = 172.20.0.4

# Test DNS resolution via VPN
dig @172.20.0.4 homelab.local

# Check Pi-hole custom.list
docker exec pihole cat /etc/pihole/custom.list

# Ping services from VPN client
ping 172.20.0.1

# Check VPN routing
# WireGuard config should have correct AllowedIPs
```

### DNS Resolution Slow

**Symptoms:**
- Websites load slowly
- Timeouts accessing services

**Solutions:**

```bash
# Check Pi-hole upstream DNS
# Pi-hole UI → Settings → DNS
# Recommended: Cloudflare (1.1.1.1, 1.0.0.1)

# Test upstream DNS speed
dig @1.1.1.1 google.com +stats

# Clear Pi-hole cache
docker exec pihole pihole restartdns

# Reduce cache size if RAM limited
# Edit docker-compose.yml pihole environment:
# CACHE_SIZE: 5000
```

---

## Database Issues

### PostgreSQL Won't Start

**Symptoms:**
- Immich, Paperless, Matrix fail to start
- Database connection errors

**Solutions:**

```bash
# Check PostgreSQL logs
docker compose logs postgres

# Common issue: Corrupted data
# Backup first!
docker compose down
mv data/postgres data/postgres.backup
docker compose up -d postgres

# Check disk space
df -h

# Verify database is ready
docker exec postgres pg_isready -U homelab
```

### Database Connection Refused

**Symptoms:**
- Services can't connect to PostgreSQL
- `Connection refused` in logs

**Solutions:**

```bash
# Check PostgreSQL is running
docker compose ps postgres

# Verify network connectivity
docker exec immich-server ping postgres

# Check PostgreSQL accepts connections
docker exec postgres psql -U homelab -c "SELECT 1"

# Restart dependent services
docker compose restart immich-server paperless-ngx matrix-synapse
```

### Redis Memory Issues

**Symptoms:**
- Redis OOM (out of memory) errors
- Immich slow to respond

**Solutions:**

```bash
# Check Redis memory usage
docker exec redis redis-cli INFO memory

# Increase max memory in docker-compose.yml
# Under redis service:
command: redis-server --maxmemory 512mb

# Clear Redis cache
docker exec redis redis-cli FLUSHALL

# Restart Redis
docker compose restart redis
```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- Server sluggish
- Fans running constantly

**Solutions:**

```bash
# Check container resource usage
docker stats

# Identify heavy processes
top -p $(docker inspect --format '{{.State.Pid}}' immich-ml)

# Limit CPU for ML services
# In docker-compose.yml under immich-ml:
deploy:
  resources:
    limits:
      cpus: '2.0'

# Disable machine learning (if not needed)
# Stop immich-ml container
docker compose stop immich-ml
```

### High Memory Usage

**Symptoms:**
- System OOM killer activating
- Containers randomly restarting

**Solutions:**

```bash
# Check memory usage
free -h
docker stats

# Limit container memory
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 1G

# Reduce PostgreSQL cache
# In docker-compose.yml postgres environment:
POSTGRES_SHARED_BUFFERS: 128MB

# Disable swap (if using SSD)
sudo swapoff -a
```

### Slow Photo Upload (Immich)

**Symptoms:**
- Photos take minutes to upload
- Mobile app times out

**Solutions:**

```bash
# Check machine learning is running
docker compose ps immich-ml

# Temporarily disable ML processing
# Immich UI → Settings → Machine Learning → Disable

# Check network bandwidth
# Test upload speed to server

# Use wired connection for initial upload
# WiFi can be slow for large libraries
```

---

## Data Recovery

### Restore from Backup

```bash
# Stop services
docker compose down

# Extract backup
tar -xzf backups/launchlab_backup_YYYYMMDD_HHMMSS.tar.gz

# Restart services
docker compose up -d

# Verify health
bash scripts/healthcheck.sh
```

### Recover After Failed Update

```bash
# Rollback to previous image
docker compose down
docker compose pull [service]:previous-version
docker compose up -d

# Check logs
docker compose logs [service]
```

### Reset Single Service

```bash
# Example: Reset Portainer
docker compose down portainer
rm -rf data/portainer/
docker compose up -d portainer

# Recreate admin user (Portainer will prompt)
```

---

## Getting Help

### Collect Debug Information

Before asking for help, collect:

```bash
# System info
uname -a
docker --version
docker compose version

# Service status
docker compose ps

# Recent logs
docker compose logs --tail=100 > debug.log

# Disk space
df -h

# Network info
docker network inspect launchlab_homelab-net > network.log
```

### Report an Issue

1. Search existing issues: https://github.com/yourusername/LaunchLab/issues
2. Create new issue with template
3. Include:
   - Operating system & version
   - Docker version
   - Service affected
   - Error messages (logs)
   - Steps to reproduce

### Community Support

- GitHub Discussions: https://github.com/yourusername/LaunchLab/discussions
- FAQ: See README.md
- Service Docs: See docs/services/

---

## Preventive Maintenance

### Weekly

```bash
# Health check
bash scripts/healthcheck.sh

# Check logs for errors
docker compose logs --tail=100 | grep -i error

# Update DuckDNS
docker compose restart duckdns
```

### Monthly

```bash
# Backup data
bash scripts/backup.sh

# Update services
docker compose pull
docker compose up -d

# Clean Docker
docker system prune -f
```

### Quarterly

```bash
# Review service versions
docker compose config

# Update base system
sudo apt update && sudo apt upgrade

# Review security settings
# Change passwords if using defaults
```

---

**Still stuck?** Open an issue on GitHub with detailed logs and we'll help troubleshoot!
