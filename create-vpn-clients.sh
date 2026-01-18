#!/bin/bash
# LaunchLab - Create VPN Clients
# Run this after 'docker compose up -d'

echo "Creating WireGuard VPN clients..."

WG_PASSWORD='' WG_URL='http://localhost:51821' python3 scripts/init-wg-easy.py

if [ $? -eq 0 ]; then
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
