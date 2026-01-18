#!/bin/bash
# ==============================================
# LAUNCHLAB HEALTH CHECK SCRIPT
# ==============================================
# Validates all services are running and accessible
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_service() {
    local service_name=$1
    local check_url=$2
    local timeout=${3:-5}

    if curl -sf --max-time $timeout "$check_url" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $service_name"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $service_name ${YELLOW}(not responding)${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

check_container() {
    local container_name=$1

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name")
        if [ "$status" == "running" ]; then
            echo -e "  ${GREEN}✓${NC} $container_name ${BLUE}(running)${NC}"
            ((PASS_COUNT++))
            return 0
        else
            echo -e "  ${YELLOW}⚠${NC} $container_name ${YELLOW}(status: $status)${NC}"
            ((WARN_COUNT++))
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} $container_name ${RED}(not found)${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Banner
echo -e "${CYAN}${BOLD}"
echo "=========================================="
echo "  LaunchLab Health Check"
echo "=========================================="
echo -e "${NC}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}${BOLD}ERROR:${NC} Docker is not running"
    exit 1
fi

# ==============================================
# Phase 1: Container Status
# ==============================================

echo -e "${BOLD}Phase 1: Container Status${NC}"
echo ""

check_container "portainer"
check_container "postgres"
check_container "redis"
check_container "immich-server"
check_container "immich-ml"
check_container "jellyfin"
check_container "paperless-ngx"
check_container "paperless-redis"
check_container "matrix-synapse"
check_container "element-web"
check_container "pihole"
check_container "wg-easy"
check_container "duckdns"

echo ""

# ==============================================
# Phase 2: HTTP Service Health
# ==============================================

echo -e "${BOLD}Phase 2: HTTP Service Health${NC}"
echo ""

check_service "Portainer UI" "http://localhost:9000"
check_service "Immich API" "http://localhost:2283/api/server-info/ping"
check_service "Jellyfin" "http://localhost:8096/health"
check_service "Paperless" "http://localhost:8000"
check_service "Matrix Synapse" "http://localhost:8008/health"
check_service "Element Web" "http://localhost:8081"
check_service "Pi-hole Web UI" "http://localhost:8053/admin"
check_service "WireGuard UI" "http://localhost:51821"

echo ""

# ==============================================
# Phase 3: Database Connectivity
# ==============================================

echo -e "${BOLD}Phase 3: Database Connectivity${NC}"
echo ""

# PostgreSQL
if docker exec postgres pg_isready -U homelab >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} PostgreSQL"
    ((PASS_COUNT++))

    # Check databases exist
    for db in immich matrix paperless; do
        if docker exec postgres psql -U homelab -lqt | cut -d \| -f 1 | grep -qw $db; then
            echo -e "    ${GREEN}✓${NC} Database: $db"
            ((PASS_COUNT++))
        else
            echo -e "    ${YELLOW}⚠${NC} Database: $db ${YELLOW}(not found)${NC}"
            ((WARN_COUNT++))
        fi
    done
else
    echo -e "  ${RED}✗${NC} PostgreSQL ${RED}(not responding)${NC}"
    ((FAIL_COUNT++))
fi

# Redis (main)
if docker exec redis redis-cli -a "$(grep REDIS_PASSWORD "$PROJECT_ROOT/.env" | cut -d= -f2)" ping 2>/dev/null | grep -q "PONG"; then
    echo -e "  ${GREEN}✓${NC} Redis (main)"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} Redis (main) ${RED}(not responding)${NC}"
    ((FAIL_COUNT++))
fi

# Redis (paperless)
if docker exec paperless-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "  ${GREEN}✓${NC} Redis (paperless)"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} Redis (paperless) ${RED}(not responding)${NC}"
    ((FAIL_COUNT++))
fi

echo ""

# ==============================================
# Phase 4: DNS Resolution
# ==============================================

echo -e "${BOLD}Phase 4: DNS Resolution (Pi-hole)${NC}"
echo ""

# Test DNS resolution via Pi-hole
if dig @127.0.0.1 -p 53 google.com +short +time=2 >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Pi-hole DNS (external resolution)"
    ((PASS_COUNT++))
else
    echo -e "  ${YELLOW}⚠${NC} Pi-hole DNS ${YELLOW}(may not be configured as system DNS)${NC}"
    ((WARN_COUNT++))
fi

# Test custom domain resolution
if dig @127.0.0.1 -p 53 homelab.local +short +time=2 | grep -q "172.20.0.1"; then
    echo -e "  ${GREEN}✓${NC} Custom DNS (homelab.local)"
    ((PASS_COUNT++))
else
    echo -e "  ${YELLOW}⚠${NC} Custom DNS ${YELLOW}(homelab.local not resolving)${NC}"
    ((WARN_COUNT++))
fi

echo ""

# ==============================================
# Summary
# ==============================================

echo -e "${BOLD}=========================================="
echo "  Health Check Summary"
echo "==========================================${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $PASS_COUNT"
echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
echo -e "  ${RED}Failed:${NC}  $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ All systems operational!${NC}"
    echo ""
    exit 0
elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠️  System operational with warnings${NC}"
    echo ""
    echo "Some non-critical checks failed. Services should work normally."
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}❌ System has failures${NC}"
    echo ""
    echo "Some critical services are not responding."
    echo "Check logs with: docker compose logs [service-name]"
    echo ""
    exit 1
fi
