#!/bin/bash
# ==============================================
# LAUNCHLAB BACKUP SCRIPT
# ==============================================
# Creates compressed backup of all service data
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="launchlab_backup_${TIMESTAMP}.tar.gz"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Banner
echo -e "${BLUE}${BOLD}"
echo "=========================================="
echo "  LaunchLab Backup Utility"
echo "=========================================="
echo -e "${NC}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if services are running
log_info "Checking service status..."
RUNNING_SERVICES=$(docker compose ps --services --filter "status=running" | wc -l)
if [ $RUNNING_SERVICES -gt 0 ]; then
    log_warning "Services are running. For best results, stop services first:"
    log_warning "  docker compose down"
    read -p "Continue anyway? [y/N]: " -n 1 -r CONTINUE
    echo ""
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        log_info "Backup cancelled"
        exit 0
    fi
fi

# Start backup
log_info "Creating backup: $BACKUP_NAME"
log_info "This may take several minutes depending on data size..."

cd "$PROJECT_ROOT"

# Create tarball of data directory and .env file
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='data/immich/upload/thumbs' \
    --exclude='data/immich/upload/encoded-video' \
    --exclude='data/jellyfin/cache' \
    --exclude='data/*/logs' \
    data/ .env 2>/dev/null || true

if [ -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    log_success "Backup created successfully!"
    echo ""
    echo -e "  ${BOLD}File:${NC} $BACKUP_DIR/$BACKUP_NAME"
    echo -e "  ${BOLD}Size:${NC} $BACKUP_SIZE"
    echo ""

    # Cleanup old backups
    log_info "Cleaning up old backups..."

    # Keep last 7 days
    find "$BACKUP_DIR" -name "launchlab_backup_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

    REMAINING_BACKUPS=$(find "$BACKUP_DIR" -name "launchlab_backup_*.tar.gz" | wc -l)
    log_info "Kept $REMAINING_BACKUPS recent backup(s)"

    echo ""
    echo -e "${GREEN}${BOLD}✅ Backup complete!${NC}"
    echo ""
    echo "To restore from this backup:"
    echo "  1. Stop services: docker compose down"
    echo "  2. Extract: tar -xzf $BACKUP_DIR/$BACKUP_NAME"
    echo "  3. Start services: docker compose up -d"
    echo ""
else
    log_error "Backup failed"
fi
