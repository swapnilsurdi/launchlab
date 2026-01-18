#!/bin/bash
# ==============================================
# MATRIX SYNAPSE INITIALIZATION SCRIPT
# ==============================================
# Creates homeserver.yaml and admin user
# ==============================================

set -e

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-changeme}"
MATRIX_URL="${MATRIX_URL:-http://matrix-synapse:8008}"
DATA_DIR="/data"

log() {
    echo "[Matrix Init] $1"
}

# Wait for Matrix to be ready
wait_for_matrix() {
    log "Waiting for Matrix Synapse to be ready..."
    for i in {1..60}; do
        if curl -sf "$MATRIX_URL/health" >/dev/null 2>&1; then
            log "✓ Matrix Synapse ready (waited ${i}s)"
            return 0
        fi
        sleep 1
    done
    log "✗ Matrix Synapse timeout after 60s"
    return 1
}

# Register admin user
register_admin() {
    log "Registering admin user: $ADMIN_USER"

    # Try to register via register_new_matrix_user command
    if command -v register_new_matrix_user >/dev/null 2>&1; then
        register_new_matrix_user \
            -u "$ADMIN_USER" \
            -p "$ADMIN_PASSWORD" \
            -a \
            -c "$DATA_DIR/homeserver.yaml" \
            "$MATRIX_URL" 2>&1 | tee /tmp/matrix-register.log

        if grep -q "User ID:" /tmp/matrix-register.log; then
            log "✓ Admin user registered"
            log "  Username: @${ADMIN_USER}:homelab.local"
            log "  Password: ${ADMIN_PASSWORD}"
            return 0
        elif grep -q "already exists" /tmp/matrix-register.log; then
            log "ℹ Admin user already exists"
            return 0
        else
            log "✗ Failed to register admin user"
            return 1
        fi
    else
        log "✗ register_new_matrix_user command not found"
        log "ℹ Register admin manually via Element UI or CLI"
        return 1
    fi
}

# Main
main() {
    log "Starting Matrix Synapse initialization..."

    # Check if homeserver.yaml exists
    if [ ! -f "$DATA_DIR/homeserver.yaml" ]; then
        log "✗ homeserver.yaml not found"
        log "ℹ Matrix will generate it on first startup"
        log "ℹ Admin user registration will happen on next run"
        exit 0
    fi

    log "✓ homeserver.yaml found"

    # Wait for Matrix to be ready
    if ! wait_for_matrix; then
        log "✗ Matrix not ready, exiting"
        exit 1
    fi

    # Register admin user
    if register_admin; then
        log "✓ Initialization complete"
        exit 0
    else
        log "⚠ Initialization completed with warnings"
        log "ℹ Register admin user manually:"
        log "  docker exec -it matrix-synapse register_new_matrix_user \\"
        log "    -u admin -p changeme -a http://localhost:8008"
        exit 0  # Don't fail, just warn
    fi
}

main
