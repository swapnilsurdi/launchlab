#!/bin/sh
# ==============================================
# DOCKER INIT CONTAINER SCRIPT
# ==============================================
# Runs inside an Alpine container to initialize:
# - PostgreSQL databases
# - Matrix homeserver.yaml config
# ==============================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INIT]${NC} $1"; }
log_success() { echo -e "${GREEN}[INIT]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[INIT]${NC} $1"; }
log_error() { echo -e "${RED}[INIT]${NC} $1"; exit 1; }

echo ""
echo "=========================================="
echo "  LaunchLab Initialization"
echo "=========================================="
echo ""

# ==============================================
# Wait for PostgreSQL
# ==============================================

log_info "Waiting for PostgreSQL..."
until PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d postgres -c '\q' 2>/dev/null; do
  log_info "PostgreSQL is unavailable - sleeping"
  sleep 2
done
log_success "PostgreSQL is ready"

# ==============================================
# Create Databases
# ==============================================

log_info "Checking databases..."

# Function to check if database exists
db_exists() {
    PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$1'" 2>/dev/null | grep -q 1
}

# Create immich database
if db_exists "immich"; then
    log_success "immich database exists"
else
    log_info "Creating immich database..."
    PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d postgres -c "CREATE DATABASE immich;"
    log_success "immich database created"
fi

# Install vectors extension for immich
log_info "Installing vectors extension..."
PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d immich -c "CREATE EXTENSION IF NOT EXISTS vectors;" >/dev/null 2>&1 || true
log_success "Vectors extension ready"

# Create matrix database with special collation
if db_exists "matrix"; then
    log_success "matrix database exists"
else
    log_info "Creating matrix database..."
    PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d postgres -c "CREATE DATABASE matrix OWNER ${POSTGRES_USER} ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;"
    log_success "matrix database created"
fi

# Create paperless database
if db_exists "paperless"; then
    log_success "paperless database exists"
else
    log_info "Creating paperless database..."
    PGPASSWORD=${POSTGRES_PASSWORD} psql -h postgres -U ${POSTGRES_USER} -d postgres -c "CREATE DATABASE paperless;"
    log_success "paperless database created"
fi

# ==============================================
# Generate Matrix Config
# ==============================================

log_info "Checking Matrix configuration..."

if [ -f "/matrix-data/homeserver.yaml" ]; then
    log_success "Matrix homeserver.yaml exists"
else
    log_info "Generating Matrix homeserver.yaml..."

    # Create minimal homeserver.yaml
    cat > /matrix-data/homeserver.yaml <<-EOF
# Homeserver configuration
server_name: "${MATRIX_SERVER_NAME:-homelab.local}"
pid_file: /data/homeserver.pid
log_config: /data/${MATRIX_SERVER_NAME:-homelab.local}.log.config

# Media storage
media_store_path: /data/media_store
uploads_path: /data/uploads

# Listener configuration
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['::']
    resources:
      - names: [client, federation]
        compress: false

# Database configuration
database:
  name: psycopg2
  args:
    user: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    database: matrix
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

# Registration
enable_registration: false
enable_registration_without_verification: false

# Security
suppress_key_server_warning: true
report_stats: false

# Signing key (will be auto-generated if missing)
signing_key_path: "/data/${MATRIX_SERVER_NAME:-homelab.local}.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
EOF

    # Create log config
    cat > /matrix-data/${MATRIX_SERVER_NAME:-homelab.local}.log.config <<-EOF
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
root:
  level: INFO
  handlers: [console]
EOF

    log_success "Matrix homeserver.yaml generated"
fi

# ==============================================
# Done
# ==============================================

echo ""
log_success "Initialization complete!"
echo ""
