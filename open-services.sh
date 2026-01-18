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
