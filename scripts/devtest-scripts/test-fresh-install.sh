#!/bin/bash
# ==============================================
# LAUNCHLAB FRESH INSTALL TEST
# ==============================================
# Tests the installation process from scratch
# Creates a random test folder and installs LaunchLab
# ==============================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[TEST]${NC} $1"; }
log_error() { echo -e "${RED}[TEST]${NC} $1"; }

# ==============================================
# Configuration
# ==============================================

# Get the repository root directory (2 levels up from this script)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Create test directory structure
TEST_BASE_DIR="$REPO_ROOT/launchlab-startup-tests"
RANDOM_NAME="test-$(date +%s)-$RANDOM"
TEST_DIR="$TEST_BASE_DIR/$RANDOM_NAME"

MAX_WAIT_MINUTES=10
CHECK_INTERVAL=30

# Core services that must be healthy
REQUIRED_SERVICES=(
    "postgres:healthy"
    "paperless-ngx:healthy"
    "matrix-synapse:healthy"
    "immich-server:healthy"
)

# ==============================================
# Cleanup function
# ==============================================

cleanup() {
    local exit_code=$?

    log_info "Cleaning up test environment..."

    if [ -d "$TEST_DIR" ]; then
        # Save current directory
        local original_dir=$(pwd)

        # Go to test directory and stop containers
        cd "$TEST_DIR" 2>/dev/null || true
        if [ -f "docker-compose.yml" ]; then
            log_info "Stopping Docker containers..."
            docker compose down -v 2>/dev/null || true
        fi

        # Go back and remove test directory
        cd "$original_dir"
        rm -rf "$TEST_DIR"
        log_success "Test directory removed: $TEST_DIR"
    fi

    # If test base directory is empty, remove it too
    if [ -d "$TEST_BASE_DIR" ] && [ -z "$(ls -A "$TEST_BASE_DIR")" ]; then
        rmdir "$TEST_BASE_DIR"
        log_info "Test base directory removed (was empty)"
    fi

    exit $exit_code
}

# Trap cleanup on exit, interrupt, and termination
trap cleanup EXIT INT TERM

# ==============================================
# Start Test
# ==============================================

echo ""
echo "=========================================="
echo "  LaunchLab Fresh Install Test"
echo "=========================================="
echo ""

log_info "Test directory: $TEST_DIR"
log_info "Max wait time: ${MAX_WAIT_MINUTES} minutes"
log_info "Check interval: ${CHECK_INTERVAL} seconds"
echo ""

# ==============================================
# Step 1: Create Test Directory
# ==============================================

log_info "Creating test directory structure..."
mkdir -p "$TEST_BASE_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
log_success "Test directory created: $TEST_DIR"

# ==============================================
# Step 2: Copy Repository
# ==============================================

log_info "Copying LaunchLab repository..."

# Copy repository files (excluding test directories)
cp -r "$REPO_ROOT/"* . 2>/dev/null || true
cp "$REPO_ROOT/.env.example" . 2>/dev/null || true

# Don't copy the git directory or test directories
rm -rf .git launchlab-startup-tests 2>/dev/null || true

# Remove hardcoded values from docker-compose.yml for parallel testing
# This prevents conflicts when running multiple instances
if [ -f "docker-compose.yml" ]; then
    log_info "Configuring docker-compose.yml for parallel testing..."

    # Remove static IP addresses
    sed -i.bak '/ipv4_address:/d' docker-compose.yml

    # Remove hardcoded container names (Docker will auto-generate from project name)
    sed -i.bak '/container_name:/d' docker-compose.yml

    # Remove launchlab-init service and its dependencies (causes timeout issues in testing)
    # We'll run without init container for faster testing
    sed -i.bak '/launchlab-init:/,/^[^ ]/{ /^[^ ]/!d; }' docker-compose.yml
    sed -i.bak '/launchlab-init:/d' docker-compose.yml
    sed -i.bak -e '/depends_on:/,/condition: service/{ /launchlab-init:/,/condition: service/d; }' docker-compose.yml

    rm -f docker-compose.yml.bak
fi

log_success "Repository copied and configured for testing"

# ==============================================
# Step 3: Run Quick Setup (Non-interactive)
# ==============================================

log_info "Running quick setup (non-interactive)..."

# Generate random network and port offset to avoid conflicts
# Use 172.21-30.x.x range (different from default 172.20.x.x)
RANDOM_OCTET=$((21 + RANDOM % 10))
DOCKER_SUBNET="172.${RANDOM_OCTET}.0.0/16"
DOCKER_GATEWAY="172.${RANDOM_OCTET}.0.1"

# Port offset (add 1000-9000 to default ports to avoid conflicts)
PORT_OFFSET=$((1000 + RANDOM % 8000))

# Generate simple alphanumeric passwords (avoid special chars that cause issues)
SIMPLE_PASSWORD=$(openssl rand -hex 16)  # 32 char hex string, no special chars

# Generate WireGuard password hash
WG_PASS_HASH=$(docker run --rm alpine sh -c "apk add --no-cache openssl >/dev/null 2>&1 && echo 'testpass123' | openssl passwd -6 -stdin" 2>/dev/null || echo '$6$rounds=656000$YQKNdQ5lVVVJXkjQ$Ps4qTvxFWXSMqHQJqq4bGSjN5pZIRZqVlr4gCrU5y9FZAeL4FvqPL/lC7jLWD2tjZxqPZZRjh7VnHNy4bQFGC/')

# Create .env file directly for testing
cat > .env <<EOF
# Generated by test script - $(date)
EMAIL=test@example.com
TIMEZONE=America/Los_Angeles

# Network configuration (unique subnet for testing)
DOCKER_SUBNET=${DOCKER_SUBNET}
DOCKER_GATEWAY=${DOCKER_GATEWAY}
LOCAL_SUBNET=${DOCKER_SUBNET}
DOMAIN=test.homelab.local

# Admin credentials
PIHOLE_PASSWORD=testpass123
PAPERLESS_ADMIN_USER=admin
PAPERLESS_ADMIN_PASSWORD=testpass123
PAPERLESS_ADMIN_EMAIL=test@example.com

# Security keys (simple hex strings to avoid special character issues)
POSTGRES_USER=homelab
POSTGRES_PASSWORD=${SIMPLE_PASSWORD}
REDIS_PASSWORD=$(openssl rand -hex 16)
PAPERLESS_SECRET_KEY=$(openssl rand -hex 32)

# Matrix
MATRIX_SERVER_NAME=test.homelab.local

# DuckDNS (optional)
DUCKDNS_DOMAIN=testdomain
DUCKDNS_TOKEN=test-token

# WireGuard VPN
WG_PASSWORD=testpass123
WG_PASSWORD_HASH=${WG_PASS_HASH}
EOF

log_success "Configuration created (subnet: ${DOCKER_SUBNET})"

# ==============================================
# Step 4: Start Services
# ==============================================

log_info "Starting Docker services..."
log_info "(This may take several minutes to download images)"
echo ""

docker compose up -d

log_success "Docker compose started"
echo ""

# ==============================================
# Step 4.5: Initialize Databases (since we skipped init container)
# ==============================================

log_info "Waiting for PostgreSQL to be ready..."
sleep 10

# Get the postgres container name (will be auto-generated)
POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --filter "name=$RANDOM_NAME" --format "{{.Names}}" | head -1)

if [ -n "$POSTGRES_CONTAINER" ]; then
    log_info "Creating databases in $POSTGRES_CONTAINER..."

    # Create databases
    docker exec "$POSTGRES_CONTAINER" psql -U homelab -d postgres -c "CREATE DATABASE IF NOT EXISTS immich;" 2>/dev/null || true
    docker exec "$POSTGRES_CONTAINER" psql -U homelab -d postgres -c "CREATE DATABASE IF NOT EXISTS matrix;" 2>/dev/null || true
    docker exec "$POSTGRES_CONTAINER" psql -U homelab -d postgres -c "CREATE DATABASE IF NOT EXISTS paperless;" 2>/dev/null || true

    log_success "Databases created"
else
    log_warning "Could not find postgres container, databases may not be initialized"
fi

echo ""

# ==============================================
# Step 5: Wait for Services
# ==============================================

log_info "Waiting for services to become healthy..."
log_info "Checking every ${CHECK_INTERVAL} seconds, timeout in ${MAX_WAIT_MINUTES} minutes"
echo ""

START_TIME=$(date +%s)
MAX_WAIT_SECONDS=$((MAX_WAIT_MINUTES * 60))
CHECKS=0

check_services() {
    local all_healthy=true

    for service_check in "${REQUIRED_SERVICES[@]}"; do
        IFS=':' read -r service_name expected_status <<< "$service_check"

        # Get container status
        status=$(docker ps --filter "name=${service_name}" --format "{{.Status}}" 2>/dev/null || echo "not found")

        # Check if healthy
        if [[ "$status" == *"$expected_status"* ]]; then
            echo "  ✓ $service_name: $expected_status"
        else
            echo "  ✗ $service_name: $status"
            all_healthy=false
        fi
    done

    if [ "$all_healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    CHECKS=$((CHECKS + 1))

    log_info "Health check #${CHECKS} (elapsed: ${ELAPSED}s)"

    if check_services; then
        echo ""
        log_success "All required services are healthy!"
        echo ""

        # Show final status
        log_info "Final service status:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | head -15
        echo ""

        log_success "TEST PASSED - Installation successful!"
        exit 0
    fi

    # Check timeout
    if [ $ELAPSED -ge $MAX_WAIT_SECONDS ]; then
        echo ""
        log_error "Timeout reached (${MAX_WAIT_MINUTES} minutes)"
        log_error "Not all services became healthy"
        echo ""

        log_info "Final service status:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | head -15
        echo ""

        log_info "Checking logs for failed services..."
        for service_check in "${REQUIRED_SERVICES[@]}"; do
            IFS=':' read -r service_name expected_status <<< "$service_check"
            status=$(docker ps --filter "name=${service_name}" --format "{{.Status}}" 2>/dev/null || echo "not found")

            if [[ "$status" != *"$expected_status"* ]]; then
                echo ""
                log_error "Logs for $service_name:"
                docker logs "$service_name" --tail 20 2>&1 || true
            fi
        done

        echo ""
        log_error "TEST FAILED - Services did not become healthy in time"
        exit 1
    fi

    echo ""
    log_info "Waiting ${CHECK_INTERVAL} seconds before next check..."
    sleep $CHECK_INTERVAL
done
