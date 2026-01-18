#!/bin/bash
# ==============================================
# GITHUB REPOSITORY SETUP SCRIPT
# ==============================================
# Creates GitHub repository and pushes LaunchLab
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
  _____ _ _   _   _       _
 / ____(_) | | | | |     | |
| |  __ _| |_| |_| |_   _| |__
| | |_ | | __| __| | | | | '_ \
| |__| | | |_| |_| | |_| | |_) |
 \_____|_|\__|\__\_\\__,_|_.__/

    Repository Setup Script
EOF
echo -e "${NC}"

# ==============================================
# STEP 1: Prerequisites Check
# ==============================================

log_step "Step 1/6: Checking Prerequisites"

# Check gh CLI
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found. Install from: https://cli.github.com/"
fi
log_success "GitHub CLI found: $(gh --version | head -n1)"

# Check gh auth
if ! gh auth status &> /dev/null; then
    log_warning "Not authenticated with GitHub"
    log_info "Authenticating with GitHub..."
    gh auth login
fi
log_success "Authenticated with GitHub"

# Check git
if ! command -v git &> /dev/null; then
    log_error "Git not found. Install git first."
fi

cd "$PROJECT_ROOT"

# Check if already has remote
if git remote -v | grep -q origin; then
    EXISTING_REMOTE=$(git remote get-url origin)
    log_warning "Git remote 'origin' already exists: $EXISTING_REMOTE"
    read -p "Remove existing remote and continue? [y/N]: " -n 1 -r REMOVE
    echo ""
    if [[ $REMOVE =~ ^[Yy]$ ]]; then
        git remote remove origin
        log_info "Removed existing remote"
    else
        log_error "Cannot proceed with existing remote. Exiting."
    fi
fi

# ==============================================
# STEP 2: Repository Details
# ==============================================

log_step "Step 2/6: Repository Configuration"

echo ""
echo "Enter repository details:"
echo ""

# Repository name
read -p "Repository name [LaunchLab]: " REPO_NAME
REPO_NAME=${REPO_NAME:-LaunchLab}

# Description
DEFAULT_DESC="Self-hosted homelab platform - deployed in 10 minutes with zero manual configuration"
read -p "Description [$DEFAULT_DESC]: " REPO_DESC
REPO_DESC=${REPO_DESC:-$DEFAULT_DESC}

# Visibility
read -p "Make repository public? [Y/n]: " PUBLIC
if [[ $PUBLIC =~ ^[Nn]$ ]]; then
    VISIBILITY="private"
else
    VISIBILITY="public"
fi

# Topics
DEFAULT_TOPICS="homelab,self-hosted,docker,docker-compose,immich,jellyfin,paperless,matrix,wireguard,pihole"
read -p "Topics (comma-separated) [$DEFAULT_TOPICS]: " TOPICS
TOPICS=${TOPICS:-$DEFAULT_TOPICS}

echo ""
log_info "Repository: $REPO_NAME"
log_info "Visibility: $VISIBILITY"
log_info "Description: $REPO_DESC"
echo ""

read -p "Create repository with these settings? [Y/n]: " CONFIRM
if [[ $CONFIRM =~ ^[Nn]$ ]]; then
    log_error "Repository creation cancelled"
fi

# ==============================================
# STEP 3: Create GitHub Repository
# ==============================================

log_step "Step 3/6: Creating GitHub Repository"

# Create repo
gh repo create "$REPO_NAME" \
    --"$VISIBILITY" \
    --description "$REPO_DESC" \
    --clone=false

if [ $? -eq 0 ]; then
    log_success "Repository created on GitHub"
else
    log_error "Failed to create repository"
fi

# Get the repository URL
REPO_URL=$(gh repo view "$REPO_NAME" --json url -q .url)
log_info "Repository URL: $REPO_URL"

# ==============================================
# STEP 4: Add Remote and Push
# ==============================================

log_step "Step 4/6: Pushing to GitHub"

# Add remote
git remote add origin "$(gh repo view "$REPO_NAME" --json sshUrl -q .sshUrl)"
log_success "Added remote: origin"

# Rename branch to main if needed
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    git branch -M main
    log_info "Renamed branch to 'main'"
fi

# Push
git push -u origin main
log_success "Pushed to GitHub"

# ==============================================
# STEP 5: Configure Repository
# ==============================================

log_step "Step 5/6: Configuring Repository"

# Add topics
IFS=',' read -ra TOPIC_ARRAY <<< "$TOPICS"
gh repo edit "$REPO_NAME" --add-topic "${TOPIC_ARRAY[@]}"
log_success "Added topics"

# Enable issues
gh repo edit "$REPO_NAME" --enable-issues
log_success "Enabled issues"

# Enable discussions
gh repo edit "$REPO_NAME" --enable-discussions
log_success "Enabled discussions"

# Set homepage
gh repo edit "$REPO_NAME" --homepage "https://github.com/$REPO_NAME"

# ==============================================
# STEP 6: Create First Release
# ==============================================

log_step "Step 6/6: Creating First Release"

VERSION=$(cat "$PROJECT_ROOT/VERSION" | tr -d '\n')
log_info "Version: $VERSION"

# Create release notes
RELEASE_NOTES="# LaunchLab ${VERSION}

## 🚀 First Alpha Release

LaunchLab is a self-hosted homelab platform that deploys in 10 minutes with minimal configuration.

### ✨ What's Included

**Services:**
- 📸 Immich - Photo backup & management
- 🎬 Jellyfin - Media streaming server
- 📄 Paperless-ngx - Document management
- 💬 Matrix + Element - Private chat
- 🔒 WireGuard VPN - Secure remote access
- 🛡️ Pi-hole - Network-wide ad blocking
- 🐳 Portainer - Container management

**Features:**
- ⚡ Quick setup wizard (4 inputs only)
- 🔐 Pre-configured default credentials (\`admin\`/\`changeme\`)
- 🌐 VPN-protected access
- 📦 Official Docker images only
- 🔧 Health checks and backups included

### 📥 Quick Start

\`\`\`bash
# One-liner install
curl -sSL https://raw.githubusercontent.com/${REPO_NAME}/main/install.sh | bash

# Or manual install
git clone https://github.com/${REPO_NAME}.git
cd ${REPO_NAME}
bash scripts/quicksetup.sh
docker compose up -d
\`\`\`

### 📋 Requirements

- Linux (Ubuntu 22.04+) or macOS
- Docker 24.0+
- 8GB RAM minimum (16GB recommended)
- 50GB storage

### ⚠️ Known Limitations

- Alpha release - not production-ready
- Default passwords (change after setup!)
- Limited platform testing
- Manual Jellyfin library configuration required

### 🐛 Reporting Issues

Found a bug? [Open an issue](https://github.com/${REPO_NAME}/issues/new)

### 📚 Documentation

See [docs/installation.md](docs/installation.md) for detailed setup guide.

---

**Full Changelog:** First release - no previous versions
"

# Create release
gh release create "$VERSION" \
    --title "LaunchLab $VERSION - First Alpha Release" \
    --notes "$RELEASE_NOTES" \
    --prerelease

if [ $? -eq 0 ]; then
    log_success "Created release: $VERSION"
else
    log_warning "Failed to create release (you can do this manually later)"
fi

# ==============================================
# Summary
# ==============================================

echo ""
echo -e "${GREEN}${BOLD}✅ GitHub Repository Setup Complete!${NC}"
echo ""
echo -e "${BOLD}Repository Details:${NC}"
echo -e "  URL:        ${CYAN}$REPO_URL${NC}"
echo -e "  Visibility: $VISIBILITY"
echo -e "  Version:    $VERSION"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "  1. View repository:"
echo -e "     ${CYAN}gh repo view --web${NC}"
echo ""
echo "  2. Set up branch protection (recommended):"
echo "     - Go to Settings → Branches"
echo "     - Add rule for 'main' branch"
echo "     - Enable: Require pull request reviews"
echo ""
echo "  3. Add repository secrets (if using CI/CD):"
echo "     - Go to Settings → Secrets and variables → Actions"
echo ""
echo "  4. Share your project:"
echo -e "     ${CYAN}$REPO_URL${NC}"
echo ""
echo -e "${CYAN}Happy coding! 🚀${NC}"
echo ""
