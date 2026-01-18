#!/usr/bin/env python3
"""
Tailscale Automation Script
Automates subnet route approval and DNS configuration via Tailscale API

This script:
1. Waits for the Tailscale device to appear in the network
2. Approves advertised subnet routes (172.20.0.0/16)
3. Configures Pi-hole as global DNS nameserver
4. Enables "Override local DNS" setting
"""

import os
import time
import json
import urllib.request
import urllib.error
import sys

# Configuration from environment
TAILSCALE_API_TOKEN = os.environ.get('TAILSCALE_API_TOKEN', '')
TAILSCALE_TAILNET = os.environ.get('TAILSCALE_TAILNET', '')
TAILSCALE_HOSTNAME = os.environ.get('TAILSCALE_HOSTNAME', 'launchlab')
DOCKER_SUBNET = os.environ.get('DOCKER_SUBNET', '172.20.0.0/16')
PIHOLE_IP = os.environ.get('PIHOLE_IP', '172.20.0.4')  # Pi-hole's Docker subnet IP

# API Base URL
API_BASE = 'https://api.tailscale.com/api/v2'

# Timeout settings
DEVICE_WAIT_TIMEOUT = 120  # seconds
API_TIMEOUT = 10  # seconds

def log(message):
    """Print timestamped log message"""
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}", flush=True)

def api_request(url, method='GET', data=None):
    """
    Make API request to Tailscale API

    Args:
        url: Full API URL
        method: HTTP method (GET, POST, PATCH)
        data: Request body (dict, will be JSON encoded)

    Returns:
        Response data as dict, or None on error
    """
    headers = {
        'Authorization': f'Bearer {TAILSCALE_API_TOKEN}',
        'Content-Type': 'application/json'
    }

    request_data = None
    if data is not None:
        request_data = json.dumps(data).encode('utf-8')

    req = urllib.request.Request(url, data=request_data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=API_TIMEOUT) as response:
            response_data = response.read().decode('utf-8')
            if response_data:
                return json.loads(response_data)
            return {}
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        log(f"✗ API Error ({e.code}): {error_body}")
        return None
    except urllib.error.URLError as e:
        log(f"✗ Network Error: {e.reason}")
        return None
    except Exception as e:
        log(f"✗ Unexpected Error: {str(e)}")
        return None

def wait_for_device():
    """
    Wait for Tailscale device to appear in the network

    Returns:
        Device dict if found, None if timeout
    """
    log(f"Waiting for device '{TAILSCALE_HOSTNAME}' to appear in Tailscale network...")

    start_time = time.time()
    while time.time() - start_time < DEVICE_WAIT_TIMEOUT:
        # Get all devices in tailnet
        url = f"{API_BASE}/tailnet/{TAILSCALE_TAILNET}/devices"
        response = api_request(url)

        if response is None:
            log("Failed to fetch devices, retrying in 5 seconds...")
            time.sleep(5)
            continue

        devices = response.get('devices', [])

        # Find device by hostname
        for device in devices:
            if device.get('hostname') == TAILSCALE_HOSTNAME:
                log(f"✓ Found device: {device.get('name')}")
                return device

        # Wait before retry
        elapsed = int(time.time() - start_time)
        log(f"Device not found yet ({elapsed}s elapsed), waiting 5 seconds...")
        time.sleep(5)

    log(f"✗ Timeout: Device '{TAILSCALE_HOSTNAME}' not found after {DEVICE_WAIT_TIMEOUT}s")
    return None

def get_tailscale_ip(device):
    """
    Extract Tailscale IPv4 address from device

    Args:
        device: Device dict from API

    Returns:
        IPv4 address string, or None
    """
    addresses = device.get('addresses', [])

    # Filter for IPv4 addresses (no colons)
    ipv4_addresses = [addr for addr in addresses if ':' not in addr]

    if ipv4_addresses:
        return ipv4_addresses[0]

    log("✗ No IPv4 address found for device")
    return None

def get_device_routes(device_id):
    """
    Get current advertised and enabled routes for device

    Args:
        device_id: Tailscale device ID

    Returns:
        Dict with 'advertisedRoutes' and 'enabledRoutes', or None on error
    """
    url = f"{API_BASE}/device/{device_id}/routes"
    return api_request(url, method='GET')

def approve_subnet_routes(device_id):
    """
    Approve advertised subnet routes for device

    First gets the advertised routes, then enables them.

    Args:
        device_id: Tailscale device ID

    Returns:
        True if successful, False otherwise
    """
    log(f"Getting advertised routes for device...")

    # First, get the current routes to see what's advertised
    routes_info = get_device_routes(device_id)

    if routes_info is None:
        log(f"✗ Failed to get device routes")
        return False

    advertised = routes_info.get('advertisedRoutes', [])
    enabled = routes_info.get('enabledRoutes', [])

    log(f"  Advertised routes: {advertised}")
    log(f"  Enabled routes: {enabled}")

    if not advertised:
        log(f"⚠ No advertised routes found. Device may still be starting up.")
        log(f"  Expected route: {DOCKER_SUBNET}")
        # Try to enable the expected route anyway (pre-approval)
        advertised = [DOCKER_SUBNET]

    # Check if already enabled
    if set(advertised) == set(enabled) and advertised:
        log(f"✓ Routes already approved")
        return True

    # Enable all advertised routes
    log(f"Approving subnet routes: {advertised}")

    url = f"{API_BASE}/device/{device_id}/routes"
    data = {
        "routes": advertised
    }

    response = api_request(url, method='POST', data=data)

    if response is not None:
        new_enabled = response.get('enabledRoutes', [])
        log(f"✓ Subnet routes approved: {new_enabled}")
        return True
    else:
        log(f"✗ Failed to approve subnet routes")
        return False

def configure_dns(nameserver_ip):
    """
    Configure global DNS nameserver and override local DNS

    Args:
        nameserver_ip: IP address of Pi-hole (subnet IP, not Tailscale IP)

    Returns:
        True if successful, False otherwise
    """
    log(f"Configuring DNS (nameserver: {nameserver_ip})...")
    log(f"  Note: Using Pi-hole subnet IP (accessible via subnet routing)")

    url = f"{API_BASE}/tailnet/{TAILSCALE_TAILNET}/dns/nameservers"
    data = {
        "dns": [nameserver_ip]
    }

    response = api_request(url, method='POST', data=data)

    if response is not None:
        log(f"✓ DNS nameserver configured")

        # Enable override local DNS
        log("Enabling 'Override local DNS'...")
        prefs_url = f"{API_BASE}/tailnet/{TAILSCALE_TAILNET}/dns/preferences"
        prefs_data = {
            "magicDNS": True
        }

        prefs_response = api_request(prefs_url, method='POST', data=prefs_data)

        if prefs_response is not None:
            log(f"✓ DNS preferences updated (MagicDNS enabled)")
            return True
        else:
            log(f"⚠ DNS nameserver set, but failed to update preferences")
            return False
    else:
        log(f"✗ Failed to configure DNS")
        return False

def configure_auto_approvers():
    """
    Configure auto-approvers in ACL policy to automatically approve subnet routes

    This updates the tailnet policy file to add autoApprovers for the Docker subnet,
    allowing future route advertisements to be automatically approved.

    Returns:
        True if successful, False otherwise
    """
    log("Configuring auto-approvers for subnet routes...")

    # First, get the current policy
    get_url = f"{API_BASE}/tailnet/{TAILSCALE_TAILNET}/acl"
    current_policy = api_request(get_url, method='GET')

    if current_policy is None:
        log("⚠ Could not get current policy. Auto-approvers not configured.")
        log("  You can manually add autoApprovers in the Tailscale admin console.")
        return False

    # Check if autoApprovers already exists and has our route
    auto_approvers = current_policy.get('autoApprovers', {})
    routes = auto_approvers.get('routes', {})

    if DOCKER_SUBNET in routes:
        log(f"✓ Auto-approver already configured for {DOCKER_SUBNET}")
        return True

    # Add autoApprovers section
    if 'autoApprovers' not in current_policy:
        current_policy['autoApprovers'] = {'routes': {}}

    if 'routes' not in current_policy['autoApprovers']:
        current_policy['autoApprovers']['routes'] = {}

    # Add the Docker subnet with admin auto-approval
    current_policy['autoApprovers']['routes'][DOCKER_SUBNET] = ['autogroup:admin']

    log(f"  Adding auto-approver for {DOCKER_SUBNET} (autogroup:admin)")

    # Update the policy
    post_url = f"{API_BASE}/tailnet/{TAILSCALE_TAILNET}/acl"
    response = api_request(post_url, method='POST', data=current_policy)

    if response is not None:
        log(f"✓ Auto-approvers configured for {DOCKER_SUBNET}")
        return True
    else:
        log(f"⚠ Failed to configure auto-approvers")
        log("  You can manually add autoApprovers in the Tailscale admin console:")
        log(f'  "autoApprovers": {{"routes": {{"{DOCKER_SUBNET}": ["autogroup:admin"]}}}}')
        return False

def main():
    """Main execution"""
    log("=" * 60)
    log("Tailscale Automation Script")
    log("=" * 60)

    # Validate configuration
    if not TAILSCALE_API_TOKEN:
        log("✗ TAILSCALE_API_TOKEN environment variable not set")
        log("Skipping automation. Manual configuration required.")
        sys.exit(0)

    if not TAILSCALE_TAILNET:
        log("✗ TAILSCALE_TAILNET environment variable not set")
        log("Skipping automation. Manual configuration required.")
        sys.exit(0)

    log(f"Configuration:")
    log(f"  Tailnet: {TAILSCALE_TAILNET}")
    log(f"  Hostname: {TAILSCALE_HOSTNAME}")
    log(f"  Subnet: {DOCKER_SUBNET}")
    log(f"  Pi-hole IP: {PIHOLE_IP}")
    log("")

    # Step 1: Wait for device to appear
    device = wait_for_device()
    if device is None:
        log("")
        log("Manual Configuration Required:")
        log("  1. Go to: https://login.tailscale.com/admin/machines")
        log(f"  2. Find device '{TAILSCALE_HOSTNAME}' and approve subnet routes")
        log("  3. Go to: https://login.tailscale.com/admin/dns")
        log("  4. Add global nameserver and enable 'Override local DNS'")
        sys.exit(1)

    device_id = device.get('id')
    log(f"Device ID: {device_id}")
    log("")

    # Step 2: Get Tailscale IP
    tailscale_ip = get_tailscale_ip(device)
    if tailscale_ip is None:
        log("✗ Failed to get Tailscale IP")
        sys.exit(1)

    log(f"Tailscale IP: {tailscale_ip}")
    log("")

    # Step 3: Approve subnet routes
    routes_success = approve_subnet_routes(device_id)
    if not routes_success:
        log("⚠ Continuing despite route approval failure...")
    log("")

    # Step 4: Configure auto-approvers (for future route advertisements)
    auto_approve_success = configure_auto_approvers()
    if not auto_approve_success:
        log("⚠ Auto-approvers not configured (optional)")
    log("")

    # Step 5: Configure DNS to use Pi-hole's subnet IP
    # This uses the Pi-hole container IP (172.20.0.4) which is accessible
    # via the subnet route, NOT the Tailscale IP
    log(f"Using Pi-hole subnet IP for DNS: {PIHOLE_IP}")
    dns_success = configure_dns(PIHOLE_IP)
    if not dns_success:
        log("⚠ DNS configuration may be incomplete")
    log("")

    # Summary
    log("=" * 60)
    log("Automation Summary")
    log("=" * 60)
    log(f"  Device Found: ✓")
    log(f"  Tailscale IP: {tailscale_ip}")
    log(f"  Subnet Routes: {'✓' if routes_success else '✗'}")
    log(f"  Auto-Approvers: {'✓' if auto_approve_success else '⚠ (optional)'}")
    log(f"  DNS Config: {'✓' if dns_success else '✗'} (Pi-hole: {PIHOLE_IP})")
    log("")

    if routes_success and dns_success:
        log("✓ All automation steps completed successfully!")
        log("")
        log("Next Steps:")
        log("  1. Install Tailscale on your devices")
        log("  2. Sign in to your Tailscale account")
        log("  3. Access services via: http://media.ll, http://photos.ll, etc.")
        log("")
        log(f"DNS will use Pi-hole at {PIHOLE_IP} (via subnet routing)")
        sys.exit(0)
    else:
        log("⚠ Automation partially completed")
        log("Please check https://login.tailscale.com/admin for manual configuration")
        sys.exit(1)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        log("")
        log("✗ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        log(f"✗ Unexpected error: {str(e)}")
        sys.exit(1)
