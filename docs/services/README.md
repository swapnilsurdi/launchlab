# LaunchLab Services

Detailed documentation for each service included in LaunchLab.

---

## Services Overview

| Service | Purpose | Documentation |
|---------|---------|---------------|
| **Portainer** | Docker container management UI | [portainer.md](portainer.md) |
| **Immich** | Self-hosted photo backup & management | [immich.md](immich.md) |
| **Jellyfin** | Media streaming server | [jellyfin.md](jellyfin.md) |
| **Paperless-ngx** | Document management system | [paperless.md](paperless.md) |
| **Matrix + Element** | Private chat server | [matrix.md](matrix.md) |
| **Pi-hole** | DNS-based ad blocker | [pihole.md](pihole.md) |
| **WireGuard** | VPN server | [wireguard.md](wireguard.md) |

---

## Quick Access

All services use default credentials:

- **Username:** `admin`
- **Password:** `changeme`

**Exception:** WireGuard uses your custom password set during quicksetup.

**⚠️ Change default passwords after first login!**

---

## Service URLs

Access services at these URLs (when running locally):

- **Portainer:** http://localhost:9000
- **Immich:** http://localhost:2283
- **Jellyfin:** http://localhost:8096
- **Paperless:** http://localhost:8000
- **Element:** http://localhost:8081
- **Pi-hole:** http://localhost:8053/admin
- **WireGuard:** http://localhost:51821

---

## Service Status

Check if all services are running:

```bash
docker compose ps
```

Check service health:

```bash
bash scripts/healthcheck.sh
```

---

## Individual Service Documentation

Click on service names above for detailed guides including:

- Features overview
- Configuration options
- Mobile app setup
- Advanced usage
- Troubleshooting tips

---

**More service docs coming soon!** Contributions welcome - see [CONTRIBUTING.md](../../CONTRIBUTING.md).
