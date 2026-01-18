#!/usr/bin/env python3
"""
Immich Admin User Initialization Script
Creates default admin user via API: admin@homelab.local / changeme
"""

import os
import time
import json
import urllib.request
import urllib.error
import sys

# Configuration
IMMICH_URL = os.environ.get('IMMICH_URL', 'http://immich-server:3001')
ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@homelab.local')
ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'changeme')
ADMIN_NAME = 'Admin'

def log(msg):
    print(f"[Immich Init] {msg}", flush=True)

def wait_for_immich(max_wait=120):
    """Wait for Immich API to be ready"""
    log("Waiting for Immich API to be ready...")
    for i in range(max_wait):
        try:
            req = urllib.request.Request(f"{IMMICH_URL}/api/server-info/ping")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    if data.get('res') == 'pong':
                        log(f"✓ Immich API ready (waited {i+1}s)")
                        return True
        except Exception:
            pass
        time.sleep(1)

    log("✗ Immich API timeout after 120s")
    return False

def check_admin_exists():
    """Check if any admin user already exists"""
    try:
        # Try to sign up - if admin exists, it will fail with 400
        return False  # Assume doesn't exist, let API call handle it
    except Exception:
        return False

def create_admin():
    """Create admin user via API"""
    log(f"Creating admin user: {ADMIN_EMAIL}")

    data = {
        "email": ADMIN_EMAIL,
        "password": ADMIN_PASSWORD,
        "name": ADMIN_NAME
    }

    req = urllib.request.Request(
        f"{IMMICH_URL}/api/auth/admin-sign-up",
        data=json.dumps(data).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 201:
                result = json.loads(response.read().decode('utf-8'))
                log(f"✓ Admin user created successfully")
                log(f"  Email: {ADMIN_EMAIL}")
                log(f"  Password: {ADMIN_PASSWORD}")
                log(f"  User ID: {result.get('id', 'N/A')}")
                return True
    except urllib.error.HTTPError as e:
        if e.code == 400:
            error_body = e.read().decode('utf-8')
            if 'Admin already exists' in error_body or 'User already exists' in error_body:
                log("ℹ Admin user already exists, skipping creation")
                return True
            else:
                log(f"✗ Bad request: {error_body}")
                return False
        else:
            log(f"✗ HTTP error {e.code}: {e.reason}")
            return False
    except Exception as e:
        log(f"✗ Failed to create admin: {str(e)}")
        return False

def main():
    log("Starting Immich admin initialization...")

    # Wait for Immich to be ready
    if not wait_for_immich():
        log("✗ Immich API not ready, exiting")
        sys.exit(1)

    # Create admin user
    if create_admin():
        log("✓ Initialization complete")
        sys.exit(0)
    else:
        log("✗ Initialization failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
