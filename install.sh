#!/bin/bash
# ==============================================
# LAUNCHLAB ONE-LINER INSTALLER
# ==============================================
# Quick installation script for LaunchLab
# Usage: curl -sSL https://raw.githubusercontent.com/USER/LaunchLab/main/install.sh | bash
# ==============================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$1${NC}"; }

# Configuration
REPO_URL="https://github.com/swapnilsurdi/LaunchLab.git"
# Use current directory if running locally, otherwise use $HOME
if [ -t 0 ]; then
    # Running interactively (not piped)
    INSTALL_DIR="$(pwd)/LaunchLab"
else
    # Running via pipe (curl | bash)
    INSTALL_DIR="$HOME/LaunchLab"
fi

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
 _                       _     _          _
| |                     | |   | |        | |
| |     __ _ _   _ _ __ | |__ | |     __ _| |__
| |    / _` | | | | '_ \| '_ \| |    / _` | '_ \
| |___| (_| | |_| | | | | |_) | |___| (_| | |_) |
|______\__,_|\__,_|_| |_|_.__/|______\__,_|_.__/

         One-Liner Installer
EOF
echo -e "${NC}"
echo "This script will install LaunchLab on your system."
echo ""
echo -e "${BOLD}${YELLOW}📦 Automatic Dependency Installation${NC}"
echo "This installer will automatically install required dependencies if missing:"
echo "  • Homebrew (macOS package manager)"
echo "  • Docker (containerization platform)"
echo "  • WireGuard (VPN software)"
echo ""
echo "Supported platforms: macOS, Linux (Debian/Ubuntu, RHEL/Fedora, Arch)"
echo ""

# ==============================================
# INSTALLATION FUNCTIONS
# ==============================================

install_homebrew_macos() {
    log_info "Installing Homebrew..."
    # Use official Homebrew installation script
    # The official script handles PATH configuration automatically
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installed successfully"
    log_info "You may need to restart your terminal for brew to be available in PATH"
}

install_docker_macos() {
    log_info "Installing Docker via Homebrew..."
    brew install --cask docker
    
    log_info "Starting Docker Desktop..."
    open -a Docker
    
    log_warning "Docker Desktop is starting. This may take a minute..."
    log_info "Waiting for Docker to be ready..."
    
    # Wait for Docker to start (max 2 minutes)
    for i in {1..24}; do
        if docker info &> /dev/null; then
            log_success "Docker is ready"
            return 0
        fi
        sleep 5
    done
    
    log_warning "Docker may still be starting. Please ensure Docker Desktop is running."
}

install_wireguard_macos() {
    # Check what WireGuard installations exist
    HAS_WG_APP=false
    HAS_WG_TOOLS=false

    if [ -d "/Applications/WireGuard.app" ]; then
        HAS_WG_APP=true
        log_success "WireGuard application is already installed"
    fi

    if command -v wg &> /dev/null; then
        HAS_WG_TOOLS=true
        log_success "WireGuard CLI tools are already installed"
    fi

    # If both are installed, nothing to do
    if [ "$HAS_WG_APP" = true ] && [ "$HAS_WG_TOOLS" = true ]; then
        log_info "Both WireGuard app and CLI tools are available"
        return 0
    fi

    # If only tools are installed
    if [ "$HAS_WG_TOOLS" = true ] && [ "$HAS_WG_APP" = false ]; then
        log_info "WireGuard CLI tools detected - VPN configs will be added to CLI tools"
        log_info "You can also install the GUI app from: https://www.wireguard.com/install/"
        return 0
    fi

    # If only app is installed
    if [ "$HAS_WG_APP" = true ] && [ "$HAS_WG_TOOLS" = false ]; then
        log_info "WireGuard GUI app detected - VPN configs will be imported to the app"
        log_info "CLI tools not needed when GUI app is installed"
        return 0
    fi

    # Nothing is installed - ask user what they want
    log_info "WireGuard can be installed in two ways:"
    log_info "  1. GUI Application (recommended for most users)"
    log_info "  2. CLI Tools only (for advanced users)"
    echo ""
    read -p "Install WireGuard? [Y/n]: " -n 1 -r INSTALL_WG
    echo ""

    if [[ ! $INSTALL_WG =~ ^[Nn]$ ]]; then
        read -p "Install GUI app (Y) or CLI tools only (n)? [Y/n]: " -n 1 -r INSTALL_GUI
        echo ""

        if [[ ! $INSTALL_GUI =~ ^[Nn]$ ]]; then
            # Try to install GUI app via cask
            log_info "Attempting to install WireGuard GUI application..."

            # Try the cask installation
            if brew install --cask wireguard-tools 2>/dev/null; then
                log_success "WireGuard GUI application installed via Homebrew"
            else
                # Cask might not be available, provide manual instructions
                log_warning "Homebrew cask installation not available"
                echo ""
                echo -e "${YELLOW}${BOLD}Please install WireGuard GUI manually:${NC}"
                echo -e "  1. Download from: ${CYAN}https://www.wireguard.com/install/${NC}"
                echo -e "  2. Open the downloaded .pkg file"
                echo -e "  3. Follow the installation wizard"
                echo ""
                read -p "Press Enter once you've installed WireGuard (or skip to continue)..."

                # Check if it was installed
                if [ ! -d "/Applications/WireGuard.app" ]; then
                    log_warning "WireGuard app not detected, continuing with CLI tools only"
                fi
            fi

            # Also install CLI tools for convenience
            if ! command -v wg &> /dev/null; then
                log_info "Installing WireGuard CLI tools..."
                brew install wireguard-tools
                log_success "WireGuard CLI tools installed"
            fi

            # Final check
            if [ -d "/Applications/WireGuard.app" ]; then
                log_success "WireGuard GUI application is ready"
                log_info "VPN configs will be imported to the app after setup"
            fi
        else
            log_info "Installing WireGuard CLI tools only..."
            brew install wireguard-tools
            log_success "WireGuard CLI tools installed successfully"
        fi
    else
        log_info "WireGuard installation skipped"
    fi
}

install_docker_linux() {
    log_info "Installing Docker for Linux..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        log_info "Detected Debian/Ubuntu system"
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ -f /etc/redhat-release ]; then
        # RHEL/Fedora/CentOS
        log_info "Detected RHEL/Fedora system"
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        log_info "Detected Arch Linux system"
        sudo pacman -Sy --noconfirm docker docker-compose
        
    else
        log_error "Unsupported Linux distribution. Please install Docker manually: https://docs.docker.com/engine/install/"
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    log_warning "You may need to log out and back in for Docker group permissions to take effect"
}

install_wireguard_linux() {
    log_info "Installing WireGuard for Linux..."
    
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y wireguard wireguard-tools
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y wireguard-tools
    elif [ -f /etc/arch-release ]; then
        sudo pacman -Sy --noconfirm wireguard-tools
    else
        log_warning "Could not auto-install WireGuard. Please install manually."
        return 1
    fi
    
    log_success "WireGuard installed successfully"
}

install_docker_windows() {
    log_info "Installing Docker for Windows..."
    log_warning "For Windows, please install Docker Desktop manually from:"
    log_info "  https://docs.docker.com/desktop/install/windows-install/"
    log_info ""
    log_info "After installation, ensure WSL 2 backend is enabled."
    log_error "Please install Docker Desktop and run this script again."
}

install_wireguard_windows() {
    log_info "Installing WireGuard for Windows..."
    log_warning "For Windows, please install WireGuard manually from:"
    log_info "  https://www.wireguard.com/install/"
    log_warning "WireGuard installation is optional for the server setup."
}

# ==============================================
# STEP 1: Check Prerequisites & Auto-Install
# ==============================================

log_step "Step 1/4: Checking Prerequisites & Installing Dependencies"

# Detect OS with enhanced detection
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    log_success "OS: Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    log_success "OS: macOS"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    log_success "OS: Windows (WSL/Git Bash detected)"
else
    log_error "Unsupported OS: $OSTYPE. LaunchLab requires Linux, macOS, or Windows with WSL."
fi

# Check for Homebrew on macOS
if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew not found"
        read -p "Install Homebrew now? [Y/n]: " -n 1 -r INSTALL_BREW
        echo ""
        if [[ ! $INSTALL_BREW =~ ^[Nn]$ ]]; then
            install_homebrew_macos
            log_warning "Please restart your terminal and run this script again"
            exit 0
        else
            log_error "Homebrew is required on macOS. Please install it from https://brew.sh"
        fi
    else
        log_success "Homebrew: $(brew --version | head -n1)"
    fi
fi

# Check and install Git
if ! command -v git &> /dev/null; then
    log_warning "Git not found"
    if [[ "$OS" == "macos" ]]; then
        log_info "Installing Git via Homebrew..."
        brew install git
    elif [[ "$OS" == "linux" ]]; then
        log_info "Installing Git..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y git
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y git
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Sy --noconfirm git
        fi
    else
        log_error "Please install Git manually and run this script again"
    fi
fi
log_success "Git: $(git --version | head -n1)"

# Check and install Docker
if ! command -v docker &> /dev/null; then
    log_warning "Docker not found"
    read -p "Install Docker now? [Y/n]: " -n 1 -r INSTALL_DOCKER
    echo ""
    if [[ ! $INSTALL_DOCKER =~ ^[Nn]$ ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_docker_macos
        elif [[ "$OS" == "linux" ]]; then
            install_docker_linux
        elif [[ "$OS" == "windows" ]]; then
            install_docker_windows
        fi
    else
        log_error "Docker is required. Please install Docker and run this script again."
    fi
else
    log_success "Docker: $(docker --version | head -n1)"
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose plugin not found. Please ensure Docker is properly installed."
fi
log_success "Docker Compose: $(docker compose version --short)"

# Check for WireGuard installations (optional but recommended)
HAS_WG_APP=false
HAS_WG_TOOLS=false

# Check for WireGuard app (macOS only)
if [[ "$OS" == "macos" ]] && [ -d "/Applications/WireGuard.app" ]; then
    HAS_WG_APP=true
fi

# Check for WireGuard CLI tools
if command -v wg &> /dev/null; then
    HAS_WG_TOOLS=true
fi

# Show status or prompt for installation
if [ "$HAS_WG_TOOLS" = true ]; then
    log_success "WireGuard CLI tools: $(wg --version 2>&1 | head -n1)"
    if [ "$HAS_WG_APP" = true ]; then
        log_success "WireGuard GUI app: Installed"
    fi
elif [ "$HAS_WG_APP" = true ]; then
    log_success "WireGuard GUI app: Installed"
    log_info "WireGuard CLI tools not installed (GUI app is sufficient)"
else
    # Neither installation exists - prompt user
    log_warning "WireGuard not found (optional but recommended for VPN access)"
    read -p "Install WireGuard? [Y/n]: " -n 1 -r INSTALL_WG
    echo ""
    if [[ ! $INSTALL_WG =~ ^[Nn]$ ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_wireguard_macos
        elif [[ "$OS" == "linux" ]]; then
            install_wireguard_linux
        elif [[ "$OS" == "windows" ]]; then
            install_wireguard_windows
        fi
    else
        log_info "WireGuard installation skipped (not required for server setup)"
    fi
fi

# Check minimum disk space (5GB)
AVAILABLE_SPACE=$(df -BG "$HOME" | tail -n1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    log_warning "Low disk space: ${AVAILABLE_SPACE}GB available (5GB+ recommended)"
    read -p "Continue anyway? [y/N]: " -n 1 -r CONTINUE
    echo ""
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        log_error "Installation cancelled due to low disk space"
    fi
fi

# ==============================================
# STEP 2: Clone Repository
# ==============================================

log_step "Step 2/4: Downloading LaunchLab"

# Check if directory exists
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Directory already exists: $INSTALL_DIR"
    read -p "Remove existing directory? [y/N]: " -n 1 -r REMOVE
    echo ""
    if [[ $REMOVE =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        log_info "Removed existing directory"
    else
        # Try to use existing directory
        log_info "Using existing directory"
        cd "$INSTALL_DIR"

        # Check if it's a git repo
        if [ -d ".git" ]; then
            log_info "Updating existing repository..."
            git pull origin main || log_warning "Could not update repository"
        else
            log_error "Existing directory is not a git repository. Please remove it manually."
        fi
    fi
else
    # Clone fresh
    log_info "Cloning from: $REPO_URL"
    git clone "$REPO_URL" "$INSTALL_DIR"

    if [ $? -eq 0 ]; then
        log_success "Repository cloned successfully"
        cd "$INSTALL_DIR"
    else
        log_error "Failed to clone repository"
    fi
fi

# ==============================================
# STEP 3: Run Quick Setup
# ==============================================

log_step "Step 3/4: Running Quick Setup Wizard"

echo ""
log_info "You'll be prompted for 4 inputs:"
log_info "  1. Admin email"
log_info "  2. WireGuard VPN password"
log_info "  3. DuckDNS domain (get free at https://duckdns.org)"
log_info "  4. DuckDNS token"
echo ""
read -p "Ready to start setup? [Y/n]: " -n 1 -r START_SETUP
echo ""

if [[ $START_SETUP =~ ^[Nn]$ ]]; then
    log_warning "Setup wizard skipped"
    log_info "Run manually later with: cd $INSTALL_DIR && bash scripts/quicksetup.sh"
else
    bash scripts/quicksetup.sh

    if [ $? -eq 0 ]; then
        log_success "Configuration complete"
    else
        log_error "Setup wizard failed"
    fi
fi

# ==============================================
# STEP 4: Start Services
# ==============================================

log_step "Step 4/4: Starting Services"

# Check if .env exists
if [ ! -f ".env" ]; then
    log_warning ".env file not found (setup was skipped)"
    log_info "Complete setup manually:"
    log_info "  cd $INSTALL_DIR"
    log_info "  bash scripts/quicksetup.sh"
    log_info "  docker compose up -d"
    exit 0
fi

echo ""
read -p "Start all services now? [Y/n]: " -n 1 -r START_SERVICES
echo ""

if [[ $START_SERVICES =~ ^[Nn]$ ]]; then
    log_warning "Services not started"
    log_info "Start manually with: cd $INSTALL_DIR && docker compose -f docker-compose.yml -f docker-compose.init.yml up -d"
else
    log_info "Starting services with automatic initialization (this may take 2-3 minutes)..."
    docker compose -f docker-compose.yml -f docker-compose.init.yml up -d

    if [ $? -eq 0 ]; then
        log_success "All services started"

        # Wait for services to initialize
        log_info "Waiting for services to initialize (45 seconds)..."
        log_info "(Init containers are creating admin users automatically)"
        sleep 45

        # Run health check
        log_info "Running health check..."
        if bash scripts/healthcheck.sh; then
            log_success "Health check passed"
        else
            log_warning "Some services may still be starting. Run health check again in a few minutes:"
            log_info "  cd $INSTALL_DIR && bash scripts/healthcheck.sh"
        fi

        # Create VPN clients automatically
        echo ""
        log_info "Creating WireGuard VPN clients..."
        VPN_CREATED=false
        LAPTOP_CONFIG_PATH=""
        
        if [ -f "create-vpn-clients.sh" ]; then
            if bash create-vpn-clients.sh; then
                log_success "VPN clients created successfully"
                LAPTOP_CONFIG_PATH="$INSTALL_DIR/data/wg-easy/clients/family-laptop.conf"
                VPN_CREATED=true
            else
                log_warning "VPN client creation failed - you can create them manually at http://localhost:51821"
            fi
        else
            log_warning "VPN client creation script not found (was setup wizard completed?)"
        fi
        
        # Import VPN config into WireGuard app
        if [ "$VPN_CREATED" = true ] && [ -f "$LAPTOP_CONFIG_PATH" ]; then
            echo ""
            log_step "Setting up WireGuard VPN on this device"
            
            read -p "Import VPN config into WireGuard app and connect? [Y/n]: " -n 1 -r SETUP_VPN
            echo ""
            
            if [[ ! $SETUP_VPN =~ ^[Nn]$ ]]; then
                # Try to import config based on OS
                if [[ "$OS" == "macos" ]]; then
                    # Check what WireGuard installations are available
                    HAS_WG_APP=false
                    HAS_WG_TOOLS=false

                    if [ -d "/Applications/WireGuard.app" ]; then
                        HAS_WG_APP=true
                    fi

                    if command -v wg-quick &> /dev/null; then
                        HAS_WG_TOOLS=true
                    fi

                    # Handle GUI app
                    if [ "$HAS_WG_APP" = true ]; then
                        log_info "Setting up VPN with WireGuard GUI application..."

                        # Open WireGuard app
                        open -a WireGuard
                        sleep 2

                        # Try to import the config using URL scheme
                        log_info "Importing VPN configuration into WireGuard app..."

                        # Convert absolute path to file:// URL for better compatibility
                        FILE_URL="file://$LAPTOP_CONFIG_PATH"

                        # Try URL scheme first
                        open "wireguard://import-from-file?path=$LAPTOP_CONFIG_PATH" 2>/dev/null || {
                            # Fallback: open the file directly with WireGuard
                            open -a WireGuard "$LAPTOP_CONFIG_PATH" 2>/dev/null || {
                                log_warning "Automatic import may have failed"
                            }
                        }

                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo -e "${YELLOW}${BOLD}📱 WireGuard GUI Setup:${NC}"
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""
                        echo -e "${BOLD}1.${NC} WireGuard app should now be open"
                        echo ""
                        echo -e "${BOLD}2.${NC} If the config wasn't imported automatically:"
                        echo -e "   • Click ${BOLD}'Import tunnel(s) from file'${NC}"
                        echo -e "   • Navigate to: ${CYAN}$LAPTOP_CONFIG_PATH${NC}"
                        echo -e "   • Select ${BOLD}family-laptop.conf${NC}"
                        echo ""
                        echo -e "${BOLD}3.${NC} ${GREEN}${BOLD}Enable the 'family-laptop' tunnel${NC}"
                        echo -e "   • Click the toggle switch next to 'family-laptop'"
                        echo ""
                        echo -e "${YELLOW}${BOLD}⚠️  macOS will ask for permission to add VPN configurations${NC}"
                        echo -e "${YELLOW}   Click 'Allow' and enter your password when prompted${NC}"
                        echo ""
                        echo -e "${BOLD}4.${NC} Once connected, you can access all homelab services remotely!"
                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""

                        read -p "Press Enter once you've enabled the VPN connection..."

                    # Handle CLI tools only
                    elif [ "$HAS_WG_TOOLS" = true ]; then
                        log_info "Setting up VPN with WireGuard CLI tools..."

                        # Copy config to WireGuard directory
                        sudo mkdir -p /etc/wireguard
                        sudo cp "$LAPTOP_CONFIG_PATH" /etc/wireguard/family-laptop.conf
                        sudo chmod 600 /etc/wireguard/family-laptop.conf

                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo -e "${YELLOW}${BOLD}📱 WireGuard CLI Setup:${NC}"
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""
                        echo -e "${BOLD}Configuration installed to:${NC} ${CYAN}/etc/wireguard/family-laptop.conf${NC}"
                        echo ""
                        echo -e "${BOLD}To connect to your homelab VPN:${NC}"
                        echo -e "  ${CYAN}sudo wg-quick up family-laptop${NC}"
                        echo ""
                        echo -e "${BOLD}To disconnect:${NC}"
                        echo -e "  ${CYAN}sudo wg-quick down family-laptop${NC}"
                        echo ""
                        echo -e "${BOLD}To check connection status:${NC}"
                        echo -e "  ${CYAN}sudo wg show${NC}"
                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""

                        read -p "Connect to VPN now? [Y/n]: " -n 1 -r CONNECT_NOW
                        echo ""
                        if [[ ! $CONNECT_NOW =~ ^[Nn]$ ]]; then
                            sudo wg-quick up family-laptop && log_success "VPN connected!" || log_warning "Failed to connect. Try manually with: sudo wg-quick up family-laptop"
                        fi

                    else
                        # Neither is installed
                        log_warning "WireGuard is not installed"
                        echo ""
                        echo -e "${YELLOW}${BOLD}To use the VPN, install WireGuard:${NC}"
                        echo ""
                        echo -e "${BOLD}Option 1 - GUI App (recommended):${NC}"
                        echo -e "  ${CYAN}brew install --cask wireguard-tools${NC}"
                        echo -e "  Then import: ${CYAN}$LAPTOP_CONFIG_PATH${NC}"
                        echo ""
                        echo -e "${BOLD}Option 2 - CLI Tools:${NC}"
                        echo -e "  ${CYAN}brew install wireguard-tools${NC}"
                        echo -e "  ${CYAN}sudo cp $LAPTOP_CONFIG_PATH /etc/wireguard/family-laptop.conf${NC}"
                        echo -e "  ${CYAN}sudo wg-quick up family-laptop${NC}"
                        echo ""
                    fi
                    
                elif [[ "$OS" == "linux" ]]; then
                    log_info "Setting up WireGuard on Linux..."
                    
                    # Check if WireGuard is installed
                    if command -v wg-quick &> /dev/null; then
                        log_info "Installing VPN configuration..."
                        sudo cp "$LAPTOP_CONFIG_PATH" /etc/wireguard/family-laptop.conf
                        
                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo -e "${YELLOW}${BOLD}📱 VPN Setup Instructions (Linux):${NC}"
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""
                        echo -e "${BOLD}To connect to your homelab VPN:${NC}"
                        echo -e "  ${CYAN}sudo wg-quick up family-laptop${NC}"
                        echo ""
                        echo -e "${BOLD}To disconnect:${NC}"
                        echo -e "  ${CYAN}sudo wg-quick down family-laptop${NC}"
                        echo ""
                        echo -e "${BOLD}To enable on boot:${NC}"
                        echo -e "  ${CYAN}sudo systemctl enable wg-quick@family-laptop${NC}"
                        echo ""
                        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                        echo ""
                        
                        read -p "Connect to VPN now? [Y/n]: " -n 1 -r CONNECT_NOW
                        echo ""
                        if [[ ! $CONNECT_NOW =~ ^[Nn]$ ]]; then
                            sudo wg-quick up family-laptop
                            log_success "VPN connected!"
                        fi
                    else
                        log_warning "WireGuard not installed. Install with:"
                        log_info "  sudo apt install wireguard  # Debian/Ubuntu"
                        log_info "  sudo yum install wireguard  # RHEL/Fedora"
                        log_info "Then manually import: $LAPTOP_CONFIG_PATH"
                    fi
                    
                elif [[ "$OS" == "windows" ]]; then
                    log_info "Opening WireGuard config location..."
                    
                    echo ""
                    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${YELLOW}${BOLD}📱 VPN Setup Instructions (Windows):${NC}"
                    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    echo -e "${BOLD}1.${NC} Open WireGuard app"
                    echo -e "${BOLD}2.${NC} Click 'Import tunnel(s) from file'"
                    echo -e "${BOLD}3.${NC} Select: ${CYAN}$LAPTOP_CONFIG_PATH${NC}"
                    echo -e "${BOLD}4.${NC} Click 'Activate' to connect"
                    echo ""
                    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                fi
            else
                log_info "VPN setup skipped. You can manually import later:"
                log_info "  Config file: $LAPTOP_CONFIG_PATH"
            fi
        fi

        # Ask to open services in browser
        echo ""
        read -p "Open services in browser? [Y/n]: " -n 1 -r OPEN_BROWSER
        echo ""
        
        if [[ ! $OPEN_BROWSER =~ ^[Nn]$ ]]; then
            if [ -f "open-services.sh" ]; then
                log_info "Opening services in browser..."
                bash open-services.sh
            else
                # Fallback: open manually
                log_info "Opening services in browser..."
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    BROWSER_CMD="open"
                elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                    BROWSER_CMD="xdg-open"
                fi
                
                if [ -n "$BROWSER_CMD" ]; then
                    $BROWSER_CMD http://localhost:51821 &  # WireGuard
                    sleep 1
                    $BROWSER_CMD http://localhost:8096 &   # Jellyfin
                    sleep 1
                    $BROWSER_CMD http://localhost:2283 &   # Immich
                    sleep 1
                    $BROWSER_CMD http://localhost:8000 &   # Paperless
                    sleep 1
                    $BROWSER_CMD http://localhost:8081 &   # Element
                    log_success "Services opened in browser"
                fi
            fi
        fi
    else
        log_error "Failed to start services"
    fi
fi

# ==============================================
# Summary
# ==============================================

echo ""
echo -e "${GREEN}${BOLD}✅ LaunchLab Installation Complete!${NC}"
echo ""
echo -e "${BOLD}Installation Directory:${NC}"
echo -e "  ${CYAN}$INSTALL_DIR${NC}"
echo ""
echo -e "${BOLD}Access Your Services:${NC}"
echo ""
echo -e "  ${BOLD}Portainer:${NC}  http://localhost:9000"
echo -e "  ${BOLD}Immich:${NC}     http://localhost:2283"
echo -e "  ${BOLD}Jellyfin:${NC}   http://localhost:8096"
echo -e "  ${BOLD}Paperless:${NC}  http://localhost:8000"
echo -e "  ${BOLD}Element:${NC}    http://localhost:8081"
echo -e "  ${BOLD}Pi-hole:${NC}    http://localhost:8053/admin"
echo -e "  ${BOLD}WireGuard:${NC}  http://localhost:51821"
echo ""
echo -e "${BOLD}Default Credentials (ALL SERVICES):${NC}"
echo -e "  ${BOLD}Username:${NC} admin"
echo -e "  ${BOLD}Password:${NC} changeme"
echo ""
echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT:${NC}"
echo -e "${YELLOW}   Change default passwords after first login!${NC}"
echo ""
echo -e "${BOLD}Useful Commands:${NC}"
echo ""
echo "  View logs:"
echo -e "    ${CYAN}cd $INSTALL_DIR && docker compose logs -f${NC}"
echo ""
echo "  Stop services:"
echo -e "    ${CYAN}cd $INSTALL_DIR && docker compose down${NC}"
echo ""
echo "  Restart services:"
echo -e "    ${CYAN}cd $INSTALL_DIR && docker compose restart${NC}"
echo ""
echo "  Health check:"
echo -e "    ${CYAN}cd $INSTALL_DIR && bash scripts/healthcheck.sh${NC}"
echo ""
echo "  Backup data:"
echo -e "    ${CYAN}cd $INSTALL_DIR && bash scripts/backup.sh${NC}"
echo ""
echo -e "${BOLD}Documentation:${NC}"
echo -e "  ${CYAN}$INSTALL_DIR/docs/${NC}"
echo ""
echo -e "${CYAN}Happy homelabbing! 🚀${NC}"
echo ""
