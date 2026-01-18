# LaunchLab

**Self-hosted family homelab platform - deployed in 10 minutes with zero manual configuration.**

LaunchLab is a batteries-included Docker Compose stack for running essential self-hosted services on your home network. One command, four inputs, and you're online with:

- 📸 **Immich** - Google Photos alternative
- 🎬 **Jellyfin** - Media streaming server
- 📄 **Paperless-ngx** - Document management
- 💬 **Matrix + Element** - Private chat server
- 🔒 **WireGuard VPN** - Secure remote access | Tailscale available
- 🛡️ **Pi-hole** - Network-wide ad blocking
- 🐳 **Portainer** - Docker container management

All services pre-configured with default admin accounts. Accessible via VPN for secure remote access.

---

## Quick Start

Direct install with one-liner:

Mac/Linux user can run this directly. 
Windows Users must run it in bash. I recommend using Git Bash since most of us have Git installed already.
```bash
bash <(curl -s https://raw.githubusercontent.com/swapnilsurdi/launchlab/main/install.sh)
```

Or manual:
```bash
# Clone repository
git clone https://github.com/yourusername/LaunchLab.git
cd LaunchLab

# Run setup wizard (prompts for 4 inputs)
bash scripts/quicksetup.sh

# Start all services
docker compose -f docker-compose.yml -f docker-compose.init.yml up -d

# Optional: Create VPN clients (if you chose this during setup)
bash create-vpn-clients.sh

# Optional: Open all services in browser (if you chose this during setup)
bash open-services.sh
```

**You'll be asked for:**
1. Admin email address
2. WireGuard VPN password
3. DuckDNS domain name
4. DuckDNS token (free at https://duckdns.org)

**Optional features (prompted during setup):**
- **VPN Client Creation** - Automatically creates 2 VPN configs (laptop + mobile) with QR code
- **Browser Opening** - Helper script to open all service UIs in your browser

Everything else is auto-configured with sensible defaults.

---

## Default Credentials

All services use the same default credentials:

- **Username:** `admin`
- **Password:** `changeme` or `changeme12345`

**WireGuard VPN** uses the custom password you set during setup.

⚠️ **IMPORTANT:** Change default passwords after first login! All services are behind VPN, but good security practices still apply.

---

## System Requirements

- **OS:** Linux (Ubuntu 22.04+ recommended) or macOS
- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 50GB minimum for services, additional space for media/photos
- **Docker:** 24.0+ with Docker Compose plugin
- **Network:** Static local IP recommended, **port forwarding** for VPN

---

## Included Services

| Service | Port (Direct) | VPN URL | Purpose | Default Login |
|---------|---------------|---------|---------|---------------|
| **Portainer** | 9000 | http://portainer.ll | Container management UI | admin / changeme |
| **Immich** | 2283 | http://photos.ll | Photo backup & management | admin@homelab.local / changeme |
| **Jellyfin** | 8096 | http://media.ll | Media streaming (movies/TV) | admin / changeme |
| **Paperless-ngx** | 8000 | http://docs.ll | Document management system | admin / changeme |
| **Element Web** | 8081 | http://element.ll | Matrix chat client | Register: @admin:homelab.local |
| **Pi-hole** | 8053 | http://pihole.ll | DNS ad blocker web UI | admin / changeme |
| **WireGuard** | 51821 | http://vpn.ll | VPN management UI | admin / [your password] |
| **PostgreSQL** | 5432 | - | Shared database (internal) | - |
| **Redis** | 6379 | - | Shared cache (internal) | - |

**Access Methods:**
- **Via VPN (Recommended):** Use clean URLs like `http://media.ll` (no port numbers needed!)
- **Local Direct Access:** Use `http://localhost:[PORT]` for direct access without VPN

---

## Next Steps After Setup

1. **Access Portainer** → http://localhost:9000 (change admin password)
2. **Configure Jellyfin libraries** → Point to your media folders
3. **Upload photos to Immich** → Install mobile app, connect to server
4. **Set up WireGuard VPN** → Add client devices for remote access
5. **Configure Pi-hole** → Set as DNS server on your router
6. **Start using Paperless** → Drop PDFs in consume folder

See `docs/` folder for detailed service guides.

---

## Architecture Overview

LaunchLab uses Docker Compose with:
- **Official Docker images** (no custom builds, easy updates)
- **Pre-seeded configuration files** (admin users, settings)
- **Persistent volumes** (data survives container restarts)
- **Shared PostgreSQL database** (Immich, Paperless, Matrix)
- **Internal Docker network** (services communicate securely)
- **Nginx reverse proxy** (clean URLs without port numbers)

```
┌─────────────────────────────────────────────────────┐
│  VPN (WireGuard)                                    │
│  ↓                                                   │
│  Pi-hole (DNS + Ad Blocking)                        │
│  ↓                                                   │
│  Nginx Reverse Proxy (Port 80 Router)               │
│  ↓                                                   │
│  [Portainer] [Immich] [Jellyfin] [Paperless] ...   │
│              ↓         ↓          ↓                  │
│           [PostgreSQL] [Redis]                      │
└─────────────────────────────────────────────────────┘
```

**How Routing Works:**
1. User navigates to `http://media.ll` (via VPN)
2. Pi-hole DNS resolves to nginx's container IP (172.20.0.2)
3. Nginx intercepts the request on port 80
4. Nginx proxies to Jellyfin on port 8096
5. User sees Jellyfin without typing port numbers!

---

## Security Model

LaunchLab prioritizes **simplicity over enterprise-grade security**. It's designed for family homelabs, not production environments.

**Security layers:**
1. **VPN-only access** - Services not exposed to public internet
2. **DuckDNS dynamic DNS** - Secure domain without static IP
3. **Default passwords** - Simple to remember, easy to change
4. **Docker network isolation** - Services can't access host directly
5. **Pi-hole DNS filtering** - Blocks malicious domains

**What this is NOT:**
- ❌ Hardened for hostile networks
- ❌ Multi-tenant secure
- ❌ Compliance-ready (HIPAA, SOC2, etc.)

For family use behind WireGuard VPN, this security model is adequate. Change default passwords and keep Docker updated.

---

## Updating Services

Pull latest images and restart:

```bash
docker-compose pull
docker-compose up -d
```

Your data persists in `./data/` volumes. Backups recommended before major updates.

---

## Troubleshooting

See `docs/troubleshooting.md` for more help.

---

## FAQ

**Q: Do I need a domain name?**
A: No! DuckDNS provides free dynamic DNS. Just register at https://duckdns.org. Make sure you have port 51820 forwarding from your router to the device where LaunchLab is running

**Q: Can I run this on Raspberry Pi?**
A: Yes, but 4GB+ RAM recommended. Some services (Immich ML) may be slow.

**Q: What about backups?**
A: Not included yet. Manually backup `./data/` folder or use external backup tools.

**Q: Can I add more services?**
A: Yes!

**Q: Is this better than Nextcloud/Synology?**
A: Different use case. LaunchLab is modular (best-in-class apps) vs all-in-one solutions.

**Q: Production ready?**
A: For home use, yes. For business/production, use Kubernetes and proper security hardening.

---

## License

MIT License - see [LICENSE](LICENSE) file.

Free to use, modify, and distribute. No warranty provided.

---

## Acknowledgments

Built with these excellent open source projects:
- [Immich](https://immich.app) - Photo management
- [Jellyfin](https://jellyfin.org) - Media server
- [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) - Document management
- [Matrix](https://matrix.org) + [Element](https://element.io) - Secure chat
- [Pi-hole](https://pi-hole.net) - Ad blocking
- [WireGuard](https://www.wireguard.com) + [wg-easy](https://github.com/wg-easy/wg-easy) - VPN
- [Portainer](https://www.portainer.io) - Container management

---

# For AI Assistants: Repository Structure & Development Guide

This section provides context for LLMs working on this codebase.

## Project Philosophy

LaunchLab follows these core principles:

1. **Simplicity over features** - Minimal configuration, sane defaults
2. **Official images only** - No custom Docker image builds
3. **Pre-seeded configs** - Admin users created via volume data, not API calls
4. **Family-first design** - Target audience: non-technical home users
5. **Security through isolation** - VPN-only access, not public exposure

## Key Implementation Details

### Pre-seeded Admin Accounts

Services use different authentication backends.

### Password Strategy

Unlike production systems, LaunchLab uses a **default password approach**:

- **All services:** `admin` / `changeme` or  `changeme12345`
- **WireGuard only:** Custom password set during quicksetup
- **Backend services (PostgreSQL, Redis):** Auto-generated strong passwords

Rationale:
- Services behind VPN (not public)
- Easier to remember for family members
- Users warned to change after setup
- Complexity adds friction for target audience

## Development Workflow

### Adding a New Service

1. Add service definition to `docker-compose.yml`
2. Use official image (pin specific version tag)
3. Create volume mounts in `./data/[service]/`
4. Add environment variables to `.env.template`
5. **Add DNS entry to `config/pihole/custom.list`**
6. **Add Nginx server block to `config/nginx/nginx.conf`** (see docs/reverse-proxy.md)
7. Document in `docs/services/[service].md`
8. Update README.md service table
9. Test fresh deployment
10. Update healthcheck.sh validation

**Important:** Every web-accessible service MUST have:
- A DNS entry in Pi-hole custom list
- An Nginx reverse proxy server block for port 80 access
- Proper proxy headers configured (see existing examples)

### Testing Changes

```bash
# Clean environment test
rm -rf data/ .env
bash scripts/quicksetup.sh
docker-compose up -d
bash scripts/healthcheck.sh
```

### Version Pinning

All images use explicit version tags (no `latest`):

```yaml
image: jellyfin/jellyfin:10.9.11  # ✅ Good
image: jellyfin/jellyfin:latest   # ❌ Bad
```

Update quarterly or when security patches released.

## Code Patterns

### Script Logging

Use consistent colored output:

```bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
```

### Service Health Checks

Wait for services with timeout:

```bash
wait_for_service() {
    local service=$1
    local url=$2
    local timeout=60

    for i in $(seq 1 $timeout); do
        if curl -sf "$url" >/dev/null 2>&1; then
            log_success "$service is ready"
            return 0
        fi
        sleep 1
    done
    log_warning "$service timeout"
    return 1
}
```

### Database Initialization

PostgreSQL init scripts in `config/postgres/`:

```sql
-- Create databases
CREATE DATABASE immich;
CREATE DATABASE paperless;
CREATE DATABASE matrix;

-- Seed admin users
\c immich;
INSERT INTO users (email, password, name, "isAdmin")
VALUES ('admin@homelab.local', '$2b$10$...', 'Admin', true);
```

## Common Pitfalls

**❌ Don't:**
- Use `latest` tags (breaks reproducibility)
- Hardcode secrets in docker-compose.yml
- Create custom Docker images
- Add complex setup wizards
- Over-engineer security

**✅ Do:**
- Pin specific versions
- Use environment variables
- Leverage official images
- Keep setup simple (< 5 minutes)
- Document everything

## Testing Checklist

Before committing changes:

- [ ] Fresh install works (clean VM)
- [ ] All services start without errors
- [ ] Health checks pass
- [ ] Default credentials work
- [ ] Documentation updated
- [ ] No secrets in committed files
- [ ] .gitignore covers all user data

## Release Process

1. Test on clean Ubuntu 24.04 VM
2. Update version in README
3. Create git tag: `git tag v1.0.0`
4. Push: `git push origin main --tags`
5. GitHub release with changelog
6. Announce to community

## Support Philosophy

LaunchLab is **community-supported best-effort**:

- No SLA or guaranteed response times
- GitHub Issues for bug reports
- Discussions for questions/features
- Pull requests reviewed within 1 week
- Breaking changes require major version bump

Focus on helping users help themselves through clear documentation.

---

**End of LLM Guide**

When working on this codebase, prioritize simplicity and user experience over technical purity. The goal is to get families self-hosting quickly, not to build enterprise infrastructure.
