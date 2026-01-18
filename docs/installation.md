# LaunchLab Installation Guide

Complete step-by-step installation instructions for LaunchLab.

---

## Prerequisites

Before installing LaunchLab, ensure you have:

### Required

- **Operating System:** Linux (Ubuntu 22.04+ recommended) or macOS
- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 50GB minimum for services, plus space for media/photos
- **Docker:** Version 24.0 or newer
- **Docker Compose:** Plugin version (bundled with Docker Desktop)

### Optional

- **Static IP:** Recommended for home server (configure in router)
- **Domain:** Free DuckDNS account (https://duckdns.org)
- **Router Access:** For port forwarding (VPN access)

---

## Quick Installation

For most users, the quick setup process is recommended:

```bash
# 1. Clone repository
git clone https://github.com/yourusername/LaunchLab.git
cd LaunchLab

# 2. Run setup wizard
bash scripts/quicksetup.sh

# 3. Start services
docker compose up -d

# 4. Wait for initialization (~3 minutes)
# Watch progress:
docker compose logs -f

# 5. Verify health
bash scripts/healthcheck.sh
```

**That's it!** Access services at http://localhost:[PORT]

---

## Detailed Installation Steps

### Step 1: Install Docker

#### Ubuntu/Debian

```bash
# Update package index
sudo apt update

# Install dependencies
sudo apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

#### macOS

1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
2. Install and start Docker Desktop
3. Verify: `docker --version` and `docker compose version`

### Step 2: Clone LaunchLab

```bash
# Clone from GitHub
git clone https://github.com/yourusername/LaunchLab.git
cd LaunchLab

# Verify repository
ls -la
# You should see: docker-compose.yml, scripts/, config/, docs/
```

### Step 3: Run Setup Wizard

```bash
bash scripts/quicksetup.sh
```

You'll be prompted for:

1. **Admin Email** (e.g., you@example.com)
   - Used for Immich, Paperless, notifications
   - Can be fake email if not using features requiring email

2. **WireGuard VPN Password**
   - Custom password for VPN web UI
   - Minimum 8 characters
   - This is the ONLY password you choose

3. **DuckDNS Domain** (e.g., myhomelab)
   - Free at https://duckdns.org
   - Used for VPN external access
   - Optional if only using locally

4. **DuckDNS Token**
   - Found on DuckDNS dashboard after login
   - 36-character UUID format

The wizard will auto-detect:

- **Timezone** (from system, confirm or override)
- **Local Network Subnet** (from routing table, confirm or override)

### Step 4: Start Services

```bash
# Start all services in background
docker compose up -d

# Watch logs (optional)
docker compose logs -f

# Press Ctrl+C to stop watching logs (services keep running)
```

Services will initialize in this order:

1. **PostgreSQL & Redis** (databases, ~10 seconds)
2. **DuckDNS** (dynamic DNS, ~5 seconds)
3. **Pi-hole** (DNS server, ~30 seconds)
4. **WireGuard** (VPN server, ~20 seconds)
5. **Immich, Jellyfin, Paperless** (applications, ~60 seconds)
6. **Matrix & Element** (chat, ~45 seconds)
7. **Portainer** (management UI, ~15 seconds)

Total initialization time: **2-3 minutes**

### Step 5: Verify Installation

```bash
# Run health check
bash scripts/healthcheck.sh

# Expected output:
# Phase 1: Container Status (13 containers) ✓
# Phase 2: HTTP Service Health (8 services) ✓
# Phase 3: Database Connectivity (4 databases) ✓
# Phase 4: DNS Resolution (2 tests) ✓
#
# ✅ All systems operational!
```

### Step 6: First Login

Access services and change default passwords:

#### Portainer (Container Management)
- URL: http://localhost:9000
- Login: `admin` / `changeme`
- **Action:** Change password immediately

#### Immich (Photo Backup)
- URL: http://localhost:2283
- Login: `admin@homelab.local` / `changeme`
- **Action:** Change password, upload first photos

#### Jellyfin (Media Server)
- URL: http://localhost:8096
- Login: `admin` / `changeme`
- **Action:** Change password, add media libraries

#### Paperless-ngx (Documents)
- URL: http://localhost:8000
- Login: `admin` / `changeme`
- **Action:** Change password, configure settings

#### Element (Chat Client)
- URL: http://localhost:8081
- **Action:** Register account `@admin:homelab.local` with password `changeme`

#### Pi-hole (DNS & Ad Blocking)
- URL: http://localhost:8053/admin
- Login: `changeme` (no username)
- **Action:** Change password in settings

#### WireGuard (VPN Management)
- URL: http://localhost:51821
- Login: `admin` / [your custom password from setup]
- **Action:** Already secure, add client devices

---

## Post-Installation Configuration

### Configure Jellyfin Media Libraries

1. Login to Jellyfin: http://localhost:8096
2. Dashboard → Libraries → Add Media Library
3. Select type (Movies, TV Shows, Photos, Music)
4. Add folder: Click "+" and browse to your media location
5. Configure metadata providers (default is fine)
6. Save and scan library

**Note:** You'll need to add volume mounts to `docker-compose.yml` first:

```yaml
# In docker-compose.yml under jellyfin service:
volumes:
  - ./data/jellyfin/config:/config
  - ./data/jellyfin/cache:/cache
  - /path/to/your/movies:/media/movies:ro
  - /path/to/your/tvshows:/media/tvshows:ro
```

### Configure WireGuard VPN Clients

1. Access WireGuard UI: http://localhost:51821
2. Login with your custom password
3. Click "New Client" to add devices
4. Scan QR code with WireGuard mobile app, or download config file
5. Connect from client device

**Router Port Forwarding Required:**
- Forward UDP port 51820 to your server's local IP
- Example: 192.168.1.100:51820 (find your IP with `ip addr`)

### Set Pi-hole as DNS Server

**Option 1: Router-wide (Recommended)**
1. Access router admin panel
2. Find DHCP settings
3. Set Primary DNS to your server's local IP (e.g., 192.168.1.100)
4. Save and restart router
5. All devices now use Pi-hole

**Option 2: Per-device**
1. Network settings → Advanced → DNS
2. Set DNS server to your server's local IP
3. Apply changes

### Create Matrix Admin Account

The Matrix server requires CLI registration:

```bash
# Register admin user
docker exec -it matrix-synapse register_new_matrix_user \
  -u admin \
  -p changeme \
  -a \
  http://localhost:8008

# Login via Element
# URL: http://localhost:8081
# Username: @admin:homelab.local
# Password: changeme
```

---

## Updating Services

### Update All Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Check health
bash scripts/healthcheck.sh
```

### Update Single Service

```bash
# Pull specific service image
docker compose pull jellyfin

# Recreate only that service
docker compose up -d jellyfin

# Verify
docker compose logs jellyfin
```

---

## Backups

### Create Backup

```bash
bash scripts/backup.sh
```

Backup includes:
- All service data (`data/` directory)
- Configuration (`.env` file)
- Compressed as `.tar.gz` in `backups/` folder

Backups are automatically cleaned up (keeps last 7 days).

### Restore from Backup

```bash
# 1. Stop services
docker compose down

# 2. Extract backup
tar -xzf backups/launchlab_backup_20260111_120000.tar.gz

# 3. Restart services
docker compose up -d
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
docker info

# Check specific service logs
docker compose logs [service-name]

# Common issues:
# - Port already in use: Change port in docker-compose.yml
# - Permission denied: Check file permissions on data/
# - Out of disk space: df -h
```

### Can't Access Services

```bash
# Verify containers are running
docker compose ps

# Check firewall (Ubuntu)
sudo ufw status
sudo ufw allow 9000/tcp  # Portainer
sudo ufw allow 53/tcp    # DNS
sudo ufw allow 53/udp    # DNS

# Check service health
bash scripts/healthcheck.sh
```

### Database Connection Errors

```bash
# Check PostgreSQL is ready
docker exec postgres pg_isready -U homelab

# Check databases exist
docker exec postgres psql -U homelab -c "\l"

# Restart database services
docker compose restart postgres redis
```

### Pi-hole DNS Not Working

```bash
# Test DNS resolution
dig @localhost google.com

# Check Pi-hole logs
docker compose logs pihole

# Restart Pi-hole
docker compose restart pihole
```

For more troubleshooting, see [troubleshooting.md](troubleshooting.md).

---

## Uninstall

To completely remove LaunchLab:

```bash
# Stop and remove containers
docker compose down

# Remove all data (WARNING: Deletes everything!)
rm -rf data/

# Remove configuration
rm .env

# Remove Docker images (optional)
docker compose down --rmi all

# Remove Docker volumes (optional)
docker volume prune
```

---

## Next Steps

- [Configure each service](services/) in detail
- [Set up backups](../scripts/backup.sh) automation
- [Troubleshooting guide](troubleshooting.md)
- [Contributing](../CONTRIBUTING.md) to LaunchLab

---

**Need help?** Open an issue on GitHub or check our discussions forum.
