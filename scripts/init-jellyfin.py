#!/usr/bin/env python3
"""
Jellyfin Admin User Initialization Script
Bypasses startup wizard and creates default admin: admin / changeme
"""

import os
import time
import json
import urllib.request
import urllib.error
import sys

# Configuration
JELLYFIN_URL = os.environ.get('JELLYFIN_URL', 'http://jellyfin:8096')
ADMIN_USER = os.environ.get('ADMIN_USER', 'admin')
ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'changeme')

def log(msg):
    print(f"[Jellyfin Init] {msg}", flush=True)

def api_request(endpoint, data=None, method='GET'):
    """Make API request to Jellyfin"""
    url = f"{JELLYFIN_URL}{endpoint}"
    headers = {'Content-Type': 'application/json'}

    if data:
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST' if method == 'GET' else method
        )
    else:
        req = urllib.request.Request(url, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 204:
                return None
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        log(f"API error {endpoint}: {e.code} {e.reason}")
        try:
            error_body = e.read().decode('utf-8')
            log(f"Response: {error_body}")
        except:
            pass
        raise

def wait_for_jellyfin(max_wait=120):
    """Wait for Jellyfin to be ready"""
    log("Waiting for Jellyfin to be ready...")
    for i in range(max_wait):
        try:
            req = urllib.request.Request(f"{JELLYFIN_URL}/System/Info/Public")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    wizard_completed = data.get('StartupWizardCompleted', False)
                    log(f"✓ Jellyfin ready (waited {i+1}s)")
                    return wizard_completed
        except Exception:
            pass
        time.sleep(1)

    log("✗ Jellyfin timeout after 120s")
    return None

def setup_jellyfin():
    """Complete Jellyfin startup wizard"""
    log("Configuring Jellyfin startup wizard...")

    # 1. Set language and region
    log("Setting language and region...")
    try:
        api_request('/Startup/Configuration', {
            "UICulture": "en-US",
            "MetadataCountryCode": "US",
            "PreferredMetadataLanguage": "en"
        })
        log("✓ Language configured")
    except Exception as e:
        log(f"Language configuration: {str(e)}")

    # 2. Create admin user
    log(f"Creating admin user: {ADMIN_USER}")
    try:
        user_data = {
            "Name": ADMIN_USER,
            "Password": ADMIN_PASSWORD
        }
        api_request('/Startup/User', user_data)
        log(f"✓ Admin user created")
        log(f"  Username: {ADMIN_USER}")
        log(f"  Password: {ADMIN_PASSWORD}")
    except Exception as e:
        log(f"User creation: {str(e)}")
        # May fail if already exists, continue anyway

    # 3. Configure remote access
    log("Configuring remote access...")
    try:
        api_request('/Startup/RemoteAccess', {
            "EnableRemoteAccess": True,
            "EnableAutomaticPortMapping": False
        })
        log("✓ Remote access configured")
    except Exception as e:
        log(f"Remote access: {str(e)}")

    # 4. Try to complete wizard
    log("Attempting to complete wizard...")
    try:
        api_request('/Startup/Complete', {})
        log("✓ Startup wizard completed")
    except Exception as e:
        log(f"Wizard completion: {str(e)}")
        log("ℹ Admin user created, remaining setup via web UI")

def main():
    log("Starting Jellyfin initialization...")

    # Wait for Jellyfin
    wizard_completed = wait_for_jellyfin()

    if wizard_completed is None:
        log("✗ Jellyfin not ready, exiting")
        sys.exit(1)

    if wizard_completed:
        log("ℹ Startup wizard already completed, skipping")
        sys.exit(0)

    # Setup Jellyfin
    try:
        setup_jellyfin()
        log("✓ Initialization complete")
        sys.exit(0)
    except Exception as e:
        log(f"✗ Initialization failed: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
