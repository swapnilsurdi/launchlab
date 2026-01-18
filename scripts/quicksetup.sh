#!/bin/bash
# ==============================================
# LAUNCHLAB QUICK SETUP WIZARD
# ==============================================
# Interactive setup script that configures LaunchLab
# with minimal user input (4 required prompts)
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$1${NC}"; }

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
 _                       _     _           _
| |                     | |   | |         | |
| |     __ _ _   _ _ __ | |__ | |     __ _| |__
| |    / _` | | | | '_ \| '_ \| |    / _` | '_ \
| |___| (_| | |_| | | | | |_) | |___| (_| | |_) |
|______\__,_|\__,_|_| |_|_.__/|______\__,_|_.__/

    Quick Homelab Deployment - Setup Wizard
EOF
echo -e "${NC}"
echo "This wizard will configure your LaunchLab instance."
echo "You'll be asked for 4 inputs, everything else is automated."
echo ""

# ==============================================
# STEP 1: Check Prerequisites
# ==============================================

log_step "Step 1/6: Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
fi
log_success "Docker found: $(docker --version | head -n1)"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose plugin not found. Please install: https://docs.docker.com/compose/install/"
fi
log_success "Docker Compose found: $(docker compose version)"

# Check if .env already exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    log_warning "Existing .env file found"
    read -p "Overwrite existing configuration? [y/N]: " -n 1 -r OVERWRITE
    echo ""
    if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled. Existing .env file preserved."
        exit 0
    fi
    mv "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backed up existing .env file"
fi

# ==============================================
# STEP 2: VPN Selection
# ==============================================

log_step "Step 2/7: Choose VPN Solution"

echo ""
echo "LaunchLab supports two VPN options for secure remote access:"
echo ""
echo "  1. WireGuard + DuckDNS (Traditional)"
echo "     ✓ Full control over VPN server"
echo "     ✓ Works with any router"
echo "     ✗ Requires port forwarding (port 51820)"
echo "     ✗ Requires DuckDNS account"
echo "     ✗ Manual client configuration"
echo ""
echo "  2. Tailscale (Modern, Recommended)"
echo "     ✓ No port forwarding needed"
echo "     ✓ Works behind CGNAT/restrictive firewalls"
echo "     ✓ Easy client setup (install app + login)"
echo "     ✓ Built-in MagicDNS"
echo "     ✗ Requires Tailscale account (free tier: 100 devices)"
echo "     ✗ Relies on Tailscale infrastructure"
echo ""

while true; do
    read -p "Choose VPN option [1=WireGuard, 2=Tailscale]: " VPN_CHOICE
    case $VPN_CHOICE in
        1)
            VPN_TYPE="wireguard"
            COMPOSE_PROFILE="wireguard"
            log_success "Selected: WireGuard + DuckDNS"
            break
            ;;
        2)
            VPN_TYPE="tailscale"
            COMPOSE_PROFILE="tailscale"
            log_success "Selected: Tailscale"
            break
            ;;
        *)
            log_warning "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

# ==============================================
# STEP 3: User Configuration
# ==============================================

log_step "Step 3/7: User Configuration"

echo ""
echo "Please provide the following information:"
echo ""

# Admin Email
while true; do
    read -p "Admin Email: " ADMIN_EMAIL
    if [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        log_warning "Invalid email format. Please try again."
    fi
done

# ==============================================
# STEP 4: VPN-Specific Configuration
# ==============================================

log_step "Step 4/7: VPN Configuration"

if [ "$VPN_TYPE" == "wireguard" ]; then
    # WireGuard-specific prompts
    echo ""
    while true; do
        read -sp "WireGuard VPN Password (8+ characters): " WG_PASSWORD
        echo ""
        if [ ${#WG_PASSWORD} -lt 8 ]; then
            log_warning "Password must be at least 8 characters. Please try again."
            continue
        fi
        read -sp "Confirm Password: " WG_PASSWORD_CONFIRM
        echo ""
        if [ "$WG_PASSWORD" == "$WG_PASSWORD_CONFIRM" ]; then
            break
        else
            log_warning "Passwords do not match. Please try again."
        fi
    done
    
    echo ""
    echo "DuckDNS provides free dynamic DNS. Get yours at: https://duckdns.org"
    read -p "DuckDNS Domain (e.g., myhomelab): " DUCKDNS_DOMAIN
    DUCKDNS_DOMAIN=$(echo "$DUCKDNS_DOMAIN" | tr '[:upper:]' '[:lower:]' | sed 's/\.duckdns\.org//')
    
    read -sp "DuckDNS Token: " DUCKDNS_TOKEN
    echo ""
    
elif [ "$VPN_TYPE" == "tailscale" ]; then
    # Tailscale-specific prompts
    echo ""
    echo "Tailscale requires an API access token to automate setup."
    echo ""
    echo "To create an API access token:"
    echo "  1. Visit: https://login.tailscale.com/admin/settings/keys"
    echo "  2. Click 'Generate API access token'"
    echo "  3. Required scopes:"
    echo "     - Devices: Write"
    echo "     - Routes: Write"
    echo "     - DNS: Write"
    echo "     - Auth Keys: Write (for auto-generating auth key)"
    echo "  4. Copy the token (starts with 'tskey-api-')"
    echo ""

    while true; do
        read -sp "Tailscale API Token: " TAILSCALE_API_TOKEN
        echo ""
        if [[ "$TAILSCALE_API_TOKEN" =~ ^tskey-api- ]]; then
            break
        else
            log_warning "Invalid format. Should start with 'tskey-api-'"
        fi
    done

    read -p "Tailscale Tailnet (email or org name): " TAILSCALE_TAILNET

    echo ""
    log_info "Generating Tailscale auth key via API..."

    # Generate auth key using Tailscale API
    AUTH_KEY_RESPONSE=$(curl -s -X POST \
        "https://api.tailscale.com/api/v2/tailnet/${TAILSCALE_TAILNET}/keys" \
        -u "${TAILSCALE_API_TOKEN}:" \
        -H "Content-Type: application/json" \
        -d '{
            "capabilities": {
                "devices": {
                    "create": {
                        "reusable": true,
                        "ephemeral": false,
                        "preauthorized": true
                    }
                }
            },
            "expirySeconds": 7776000,
            "description": "LaunchLab auto-generated key"
        }')

    # Extract the auth key from the response
    TAILSCALE_AUTHKEY=$(echo "$AUTH_KEY_RESPONSE" | grep -o '"key":"[^"]*"' | sed 's/"key":"//;s/"//')

    if [[ "$TAILSCALE_AUTHKEY" =~ ^tskey-auth- ]]; then
        log_success "Auth key generated successfully"
    else
        log_error "Failed to generate auth key. API response: $AUTH_KEY_RESPONSE"
    fi

    echo ""
    log_info "API token will automate:"
    log_info "  ✓ Auth key generation"
    log_info "  ✓ Subnet route approval (172.20.0.0/16)"
    log_info "  ✓ Pi-hole DNS configuration"
    log_info "  ✓ Override local DNS"

    # Use default hostname
    TAILSCALE_HOSTNAME="launchlab"
fi

# ==============================================
# STEP 5: Auto-Detection (Confirmed by User)
# ==============================================

log_step "Step 5/7: Auto-Detecting System Settings"

# Detect Timezone (auto-detect only)
if command -v timedatectl &> /dev/null; then
    TIMEZONE=$(timedatectl show --value --property=Timezone 2>/dev/null || echo "America/Los_Angeles")
else
    TIMEZONE="America/Los_Angeles"
fi

echo ""
echo "Detected Timezone: $TIMEZONE"

# Detect Local Subnet automatically
if command -v ip &> /dev/null; then
    # Linux/macOS with ip command
    DETECTED_SUBNET=$(ip route | grep default | head -n1 | awk '{print $3}' | sed 's/\.[0-9]*$/\.0\/24/')
elif command -v netstat &> /dev/null; then
    # macOS fallback using netstat
    GATEWAY=$(netstat -nr | grep default | head -n1 | awk '{print $2}')
    if [ -n "$GATEWAY" ]; then
        DETECTED_SUBNET=$(echo "$GATEWAY" | sed 's/\.[0-9]*$/\.0\/24/')
    fi
fi

# Validate and fallback to default
if [ -z "$DETECTED_SUBNET" ] || [[ ! "$DETECTED_SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    DETECTED_SUBNET="192.168.1.0/24"
fi

LOCAL_SUBNET="$DETECTED_SUBNET"
log_success "Auto-detected local subnet: $LOCAL_SUBNET"

# ==============================================
# STEP 6: Generate Passwords and Keys
# ==============================================

log_step "Step 6/7: Generating Secure Credentials"

log_info "Generating backend service passwords..."

# Backend passwords (strong random, user never sees these)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Secret keys (64-char hex)
PAPERLESS_SECRET_KEY=$(openssl rand -hex 32)
WEBUI_SECRET_KEY=$(openssl rand -hex 32)

log_success "Backend passwords generated"

# Generate WireGuard bcrypt password hash (only if WireGuard selected)
if [ "$VPN_TYPE" == "wireguard" ]; then
    log_info "Generating WireGuard password hash (this may take a moment)..."
    
    # Saving password hash for wgeasy
    log_info "Using wg-easy Docker image to generate bcrypt hash..."
    WG_PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw "$WG_PASSWORD" | sed "s/PASSWORD_HASH='//;s/'//")
    
    if [ -z "$WG_PASSWORD_HASH" ]; then
        log_error "Failed to generate WireGuard password hash"
    fi
    
    log_success "WireGuard password hash generated"
fi

# ==============================================
# STEP 7: Write .env File
# ==============================================

log_step "Step 7/7: Creating Configuration File"

cat > "$PROJECT_ROOT/.env" <<EOF
# LaunchLab Environment Configuration
# Generated by quicksetup.sh on $(date)
# DO NOT COMMIT THIS FILE TO GIT

# ==============================================
# VPN CONFIGURATION
# ==============================================

VPN_TYPE=${VPN_TYPE}
COMPOSE_PROFILES=${COMPOSE_PROFILE}

# ==============================================
# USER CONFIGURATION
# ==============================================

# Admin email
EMAIL=${ADMIN_EMAIL}

EOF

# Append VPN-specific variables
if [ "$VPN_TYPE" == "wireguard" ]; then
    cat >> "$PROJECT_ROOT/.env" <<EOF
# WireGuard VPN
WG_PASSWORD=${WG_PASSWORD}
WG_PASSWORD_HASH=${WG_PASSWORD_HASH}

# DuckDNS Dynamic DNS
DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}
DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
DOMAIN=${DUCKDNS_DOMAIN}.duckdns.org

EOF
elif [ "$VPN_TYPE" == "tailscale" ]; then
    cat >> "$PROJECT_ROOT/.env" <<EOF
# Tailscale VPN
TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY}
TAILSCALE_HOSTNAME=${TAILSCALE_HOSTNAME}

EOF

    # Add API token if provided
    if [ -n "$TAILSCALE_API_TOKEN" ]; then
        cat >> "$PROJECT_ROOT/.env" <<EOF
# Tailscale API automation
TAILSCALE_API_TOKEN=${TAILSCALE_API_TOKEN}
TAILSCALE_TAILNET=${TAILSCALE_TAILNET}

EOF
    fi
fi

# Continue with common variables
cat >> "$PROJECT_ROOT/.env" <<EOF
# ==============================================
# SYSTEM SETTINGS
# ==============================================

# Timezone
TIMEZONE=${TIMEZONE}

# Local network subnet
LOCAL_SUBNET=${LOCAL_SUBNET}

# ==============================================
# BACKEND SERVICES (Auto-generated)
# ==============================================

# PostgreSQL shared database
POSTGRES_USER=homelab
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Redis shared cache
REDIS_PASSWORD=${REDIS_PASSWORD}

# ==============================================
# USER-FACING SERVICES
# ==============================================
# All services use default password: "changeme"
# CHANGE THESE AFTER FIRST LOGIN!

# Portainer
PORTAINER_ADMIN_PASSWORD=changeme

# Jellyfin
JELLYFIN_ADMIN_PASSWORD=changeme

# Paperless-ngx
PAPERLESS_ADMIN_USER=admin
PAPERLESS_ADMIN_PASSWORD=changeme
PAPERLESS_ADMIN_EMAIL=${ADMIN_EMAIL}
PAPERLESS_SECRET_KEY=${PAPERLESS_SECRET_KEY}

# Pi-hole
PIHOLE_PASSWORD=changeme

# Open WebUI (future)
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}

# ==============================================
# MATRIX CONFIGURATION
# ==============================================

MATRIX_SERVER_NAME=homelab.local
MATRIX_ENABLE_FEDERATION=false

# ==============================================
# BACKUP SETTINGS
# ==============================================

BACKUP_RETENTION_DAYS=7
BACKUP_RETENTION_WEEKS=4
BACKUP_RETENTION_MONTHS=12
EOF

chmod 600 "$PROJECT_ROOT/.env"
log_success "Configuration file created: .env"

# ==============================================
# Create VPN Client Helper Script (Automatic)
# ==============================================

log_info "Creating VPN client setup script..."

# Create helper script
cat > "$PROJECT_ROOT/create-vpn-clients.sh" <<VPN_EOF
#!/bin/bash
# LaunchLab - Create VPN Clients
# Run this after 'docker compose up -d'

echo "Creating WireGuard VPN clients..."

WG_PASSWORD='${WG_PASSWORD}' WG_URL='http://localhost:51821' python3 scripts/init-wg-easy.py

if [ \$? -eq 0 ]; then
    echo ""
    echo "✓ VPN clients created successfully!"
    echo ""
    echo "Configs saved to: data/wg-easy/clients/"
    echo "  - family-laptop.conf"
    echo "  - family-mobile.conf"
    echo "  - family-mobile-qr.svg"
    echo ""
    echo "Import the .conf files into your WireGuard client to connect!"
else
    echo "✗ Failed to create VPN clients"
    echo "You can create them manually via http://localhost:51821"
fi
VPN_EOF

chmod +x "$PROJECT_ROOT/create-vpn-clients.sh"
log_success "VPN client creation script ready: create-vpn-clients.sh"

# ==============================================
# Create Browser Opening Script (Cross-Platform)
# ==============================================

# Always create browser opening script (cross-platform)
cat > "$PROJECT_ROOT/open-services.sh" <<'BROWSER_EOF'
#!/bin/bash
# LaunchLab - Open Services in Browser (Cross-Platform)

echo "Opening services in browser..."

# Detect OS and set browser command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    BROWSER_CMD="open"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux" ]]; then
    # Linux
    BROWSER_CMD="xdg-open"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash, Cygwin, or WSL)
    BROWSER_CMD="start"
else
    echo "✗ Unsupported OS for browser opening"
    exit 1
fi

# Load VPN type from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep VPN_TYPE | xargs)
fi
VPN_TYPE=${VPN_TYPE:-wireguard}

# Open services based on VPN type
if [ "$VPN_TYPE" == "wireguard" ]; then
    $BROWSER_CMD http://vpn.ll &  # WireGuard UI
    sleep 1
fi

$BROWSER_CMD http://media.ll &       # Jellyfin
sleep 1
$BROWSER_CMD http://photos.ll &      # Immich
sleep 1
$BROWSER_CMD http://docs.ll &        # Paperless
sleep 1
$BROWSER_CMD http://portainer.ll &   # Portainer
sleep 1
$BROWSER_CMD http://element.ll &     # Element

echo "✓ Opened all services in browser"
BROWSER_EOF

chmod +x "$PROJECT_ROOT/open-services.sh"
log_success "Browser opening script created: open-services.sh"

# ==============================================
# STEP 8: Summary
# ==============================================

log_step "Step 8/8: Setup Complete!"

echo ""
echo -e "${GREEN}${BOLD}✅ LaunchLab is configured and ready to deploy!${NC}"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "  1. Start services:"
if [ "$VPN_TYPE" == "wireguard" ]; then
    echo -e "     ${CYAN}docker compose --profile wireguard -f docker-compose.yml -f docker-compose.init.yml up -d${NC}"
elif [ "$VPN_TYPE" == "tailscale" ]; then
    echo -e "     ${CYAN}docker compose --profile tailscale -f docker-compose.yml -f docker-compose.init.yml up -d${NC}"
fi
echo ""
echo "  2. Wait for services to initialize (~2-3 minutes)"
echo "     (Init containers will create admin users automatically)"
echo ""

if [ "$VPN_TYPE" == "wireguard" ]; then
    echo "  3. Configure WireGuard:"
    echo "     - Access: http://localhost:51821"
    echo "     - Create client configs for your devices"
    echo "     - Configure port forwarding on router (port 51820)"
    echo ""
elif [ "$VPN_TYPE" == "tailscale" ]; then
    echo "  3. Tailscale Configuration:"
    echo ""

    if [ -n "$TAILSCALE_API_TOKEN" ]; then
        echo "     ✓ Fully automated (no manual steps!)"
        echo "     - Subnet routes will be approved automatically"
        echo "     - Pi-hole DNS will be configured globally"
        echo "     - Override local DNS will be enabled"
        echo ""
        echo "     Client Setup:"
        echo "     1. Install Tailscale: https://tailscale.com/download"
        echo "     2. Sign in to your Tailscale account"
        echo "     3. Access services: http://media.ll, http://photos.ll, etc."
        echo ""
        echo "     Verify at: https://login.tailscale.com/admin/machines"
    else
        echo "     ⚠️  Manual configuration required:"
        echo "     1. Install Tailscale: https://tailscale.com/download"
        echo "     2. Sign in to your Tailscale account"
        echo "     3. Go to: https://login.tailscale.com/admin/machines"
        echo "     4. Approve subnet routes for '${TAILSCALE_HOSTNAME}'"
        echo "     5. Go to: https://login.tailscale.com/admin/dns"
        echo "     6. Add global nameserver: [LaunchLab's Tailscale IP]"
        echo "     7. Enable 'Override local DNS'"
        echo "     8. Access services: http://media.ll, http://photos.ll, etc."
    fi
    echo ""
fi

# Show helper scripts if created
if [ -f "$PROJECT_ROOT/create-vpn-clients.sh" ]; then
    if [ "$VPN_TYPE" == "wireguard" ]; then
        echo "  5. Create VPN clients (optional):"
    else
        echo "  5. VPN setup help (optional):"
    fi
    echo -e "     ${CYAN}bash create-vpn-clients.sh${NC}"
    echo ""
fi

if [ -f "$PROJECT_ROOT/open-services.sh" ]; then
    echo "  6. Open services in browser:"
    echo -e "     ${CYAN}bash open-services.sh${NC}"
    echo ""
fi

echo "  Access your services (via VPN):"
echo -e "     ${BOLD}Jellyfin:${NC}   http://media.ll"
echo -e "     ${BOLD}Immich:${NC}     http://photos.ll"
echo -e "     ${BOLD}Paperless:${NC}  http://docs.ll"
echo -e "     ${BOLD}Portainer:${NC}  http://portainer.ll"
echo -e "     ${BOLD}Element:${NC}    http://element.ll"
echo -e "     ${BOLD}Pi-hole:${NC}    http://pihole.ll/admin"

if [ "$VPN_TYPE" == "wireguard" ]; then
    echo -e "     ${BOLD}WireGuard:${NC}  http://vpn.ll"
fi

echo ""
echo -e "${BOLD}Default Credentials (ALL SERVICES):${NC}"
echo -e "     ${BOLD}Username:${NC} admin"
echo -e "     ${BOLD}Password:${NC} changeme"
echo ""
echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT SECURITY REMINDER:${NC}"
echo -e "${YELLOW}   Change default passwords after first login!${NC}"
echo ""

if [ "$VPN_TYPE" == "wireguard" ]; then
    echo -e "${BOLD}Your WireGuard VPN:${NC}"
    echo -e "     Access at: http://localhost:51821"
    echo -e "     Password: [your custom password]"
    echo ""
elif [ "$VPN_TYPE" == "tailscale" ]; then
    echo -e "${BOLD}Your Tailscale VPN:${NC}"
    echo -e "     Hostname: ${TAILSCALE_HOSTNAME}"
    echo -e "     Admin console: https://login.tailscale.com/admin/machines"
    echo ""
fi

echo -e "${BOLD}Documentation:${NC}"
echo "     See docs/ folder for detailed guides"
echo ""
echo -e "${CYAN}Happy homelabbing! 🚀${NC}"
echo ""
