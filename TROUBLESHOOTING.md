# Troubleshooting Guide

## Common Issues

### Services Failing to Start (Paperless, Matrix, Immich)

**Symptoms:**
- Services in restart loop
- Logs show: `database "paperless" does not exist`
- Logs show: `database "matrix" does not exist`
- Matrix logs: `Config file '/data/homeserver.yaml' does not exist`

**Cause:**
PostgreSQL init scripts only run on **first container startup**. If you restart services when the postgres data directory already exists, databases might not be created.

**Solution:**
This should happen automatically! The `launchlab-init` container runs on every `docker compose up` and creates missing databases.

If services are still failing:
```bash
# Restart all services (init container will run again)
docker compose down
docker compose up -d

# Or check init container logs
docker logs launchlab-init
```

The init container automatically:
- Creates missing databases (immich, matrix, paperless)
- Installs required extensions (vectors for Immich)
- Runs before other services start

**Manual Fix:**
If the script doesn't work, create databases manually:

```bash
# Create immich database
docker exec postgres psql -U homelab -d postgres -c "CREATE DATABASE immich;"
docker exec postgres psql -U homelab -d immich -c "CREATE EXTENSION IF NOT EXISTS vectors;"

# Create matrix database (requires special collation)
docker exec postgres psql -U homelab -d postgres -c "CREATE DATABASE matrix OWNER homelab ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;"

# Create paperless database
docker exec postgres psql -U homelab -d postgres -c "CREATE DATABASE paperless;"

# Restart affected services
docker compose restart paperless-ngx matrix-synapse immich-server
```


## Health Check Commands

Check service status:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Check specific service logs:
```bash
docker logs paperless-ngx -f
docker logs matrix-synapse -f
docker logs immich-server -f
```

List databases in PostgreSQL:
```bash
docker exec postgres psql -U homelab -d postgres -c "\l"
```

Run full health check:
```bash
bash scripts/healthcheck.sh
```

## Prevention

The `launchlab-init` container automatically runs on every startup and creates missing databases. All affected services (immich, matrix, paperless) depend on this init container completing successfully before they start.

This ensures databases always exist before services try to connect.
