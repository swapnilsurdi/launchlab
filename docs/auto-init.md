# Automatic Admin User Creation

LaunchLab includes optional init containers that automatically create admin users with default credentials on first startup.

---

## Overview

By default, LaunchLab requires some manual steps after deployment:
- Login to Portainer and create admin account
- Login to Immich and create first admin user
- Login to Jellyfin and complete startup wizard
- Register Matrix admin user via CLI

The **init containers** eliminate these manual steps by automatically creating admin users via each service's API.

---

## How It Works

Init containers are one-time setup containers that:
1. Wait for the main service to be healthy
2. Check if admin user already exists
3. Create admin user via API if needed
4. Exit with success

**Default credentials created:**
- Portainer: `admin` / `changeme`
- Immich: `admin@homelab.local` / `changeme`
- Jellyfin: `admin` / `changeme`
- Matrix: `@admin:homelab.local` / `changeme`

---

## Usage

### Option 1: Use Compose Override (Recommended)

```bash
# Start services with init containers
docker compose -f docker-compose.yml -f docker-compose.init.yml up -d

# Watch init containers create admin users
docker compose -f docker-compose.yml -f docker-compose.init.yml logs -f portainer-init immich-init jellyfin-init matrix-init

# Once complete, access services (no manual setup needed!)
```

### Option 2: Merge into Main Compose File

Copy the init container definitions from `docker-compose.init.yml` into your main `docker-compose.yml` file.

Then just run:
```bash
docker compose up -d
```

---

## What Gets Created

### Portainer
- **Admin User:** `admin`
- **Password:** `changeme`
- **Access:** http://localhost:9000

No manual initialization page - logs you straight in.

### Immich
- **Admin Email:** Value from `.env` `EMAIL` variable (default: `admin@homelab.local`)
- **Password:** `changeme`
- **Access:** http://localhost:2283

First user is automatically created as admin. No signup page shown.

### Jellyfin
- **Username:** `admin`
- **Password:** `changeme`
- **Access:** http://localhost:8096

Startup wizard is bypassed. You'll still need to add media libraries manually.

### Matrix
- **User ID:** `@admin:homelab.local`
- **Password:** `changeme`
- **Access:** http://localhost:8081 (Element client)

Admin user pre-registered. Login immediately via Element.

---

## Verification

Check if init containers ran successfully:

```bash
# View init container logs
docker compose logs portainer-init
docker compose logs immich-init
docker compose logs jellyfin-init
docker compose logs matrix-init

# Check container exit codes
docker ps -a --filter name=init
```

**Expected output:**
- Exit code 0 (success)
- Logs show "✓ Initialization complete" or "ℹ Admin already exists"

---

## Troubleshooting

### Init Container Failed

**Check logs:**
```bash
docker compose logs [service]-init
```

**Common issues:**
- Main service not healthy yet → Wait longer, restart init container
- Admin already exists → Not an error, init container skips creation
- Network connectivity → Ensure init container is on `homelab-net`

**Restart init container:**
```bash
docker compose up -d portainer-init
```

### Admin User Not Created

**Manually run init script:**
```bash
# Portainer
docker run --rm --network homelab-net -v $(pwd)/scripts:/scripts python:3.9-alpine python3 /scripts/init-portainer.py

# Immich
docker run --rm --network homelab-net -v $(pwd)/scripts:/scripts -e ADMIN_EMAIL=admin@homelab.local python:3.9-alpine python3 /scripts/init-immich.py

# Jellyfin
docker run --rm --network homelab-net -v $(pwd)/scripts:/scripts python:3.9-alpine python3 /scripts/init-jellyfin.py

# Matrix
docker exec matrix-synapse register_new_matrix_user -u admin -p changeme -a http://localhost:8008
```

### Clean Slate (Reset Admin Users)

```bash
# Stop services
docker compose down

# Remove data directories
rm -rf data/portainer data/immich data/jellyfin data/matrix

# Restart with init containers
docker compose -f docker-compose.yml -f docker-compose.init.yml up -d
```

---

## Security Considerations

**⚠️ Default Passwords:**
- Init containers create admin users with password `changeme`
- **You MUST change these passwords after first login!**
- Default passwords are acceptable because:
  - Services are VPN-protected (not publicly exposed)
  - Target audience is family homelabs, not enterprises
  - First login forces password change (Portainer)

**Idempotency:**
- Init scripts check if admin already exists before creating
- Safe to run multiple times
- Won't overwrite existing admin users

**Credentials in Logs:**
- Init container logs show default credentials
- Logs are NOT persisted if you use `docker compose down --volumes`
- Production deployments should avoid logging credentials

---

## Manual Alternative

If you prefer manual setup (no init containers):

1. **Portainer:**
   - Visit http://localhost:9000
   - Create admin user on first visit

2. **Immich:**
   - Visit http://localhost:2283
   - Click "Sign up" and create first admin user

3. **Jellyfin:**
   - Visit http://localhost:8096
   - Complete startup wizard (language, user, libraries)

4. **Matrix:**
   ```bash
   docker exec -it matrix-synapse register_new_matrix_user \
     -u admin -p your_password -a http://localhost:8008
   ```

---

## Scripts Reference

Init scripts are located in `scripts/`:

| Script | Service | Language | API Used |
|--------|---------|----------|----------|
| `init-portainer.py` | Portainer | Python | `/api/users/admin/init` |
| `init-immich.py` | Immich | Python | `/api/auth/admin-sign-up` |
| `init-jellyfin.py` | Jellyfin | Python | `/Startup/*` |
| `init-matrix.sh` | Matrix | Bash | `register_new_matrix_user` CLI |

All scripts are idempotent and safe to run multiple times.

---

## Disabling Auto-Init

If you want to disable auto-init after it's been set up:

**Option 1: Don't include init compose file**
```bash
# Just use main compose file (no -f docker-compose.init.yml)
docker compose up -d
```

**Option 2: Remove init containers from merged file**
```bash
# Edit docker-compose.yml
# Delete sections: portainer-init, immich-init, jellyfin-init, matrix-init
```

**Option 3: Stop and remove init containers**
```bash
docker compose stop portainer-init immich-init jellyfin-init matrix-init
docker compose rm portainer-init immich-init jellyfin-init matrix-init
```

---

## Contributing

Improvements to init scripts are welcome! Guidelines:

- Maintain idempotency (check if admin exists)
- Use service APIs (don't manipulate databases directly)
- Log clearly (success, warning, error)
- Exit with proper codes (0 = success, 1 = failure)
- Handle timeouts gracefully

---

**Questions?** See [troubleshooting.md](troubleshooting.md) or open an issue.
