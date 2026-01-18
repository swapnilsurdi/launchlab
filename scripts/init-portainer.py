#!/usr/bin/env python3
"""
Portainer Admin User Initialization Script
Creates default admin user: admin / changeme
"""

import os
import time
import json
import urllib.request
import urllib.error
import sys

# Configuration
PORTAINER_URL = os.environ.get('PORTAINER_URL', 'http://portainer:9000')
ADMIN_USER = os.environ.get('ADMIN_USER', 'admin')
ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'changeme')

def log(msg):
    print(f"[Portainer Init] {msg}", flush=True)

def wait_for_portainer(max_wait=120):
    """Wait for Portainer API to be ready"""
    log("Waiting for Portainer API to be ready...")
    for i in range(max_wait):
        try:
            req = urllib.request.Request(f"{PORTAINER_URL}/api/status")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    log(f"✓ Portainer API ready (waited {i+1}s)")
                    return True
        except Exception:
            pass
        time.sleep(1)

    log("✗ Portainer API timeout after 120s")
    return False

def check_admin_exists():
    """Check if admin user already exists"""
    try:
        req = urllib.request.Request(f"{PORTAINER_URL}/api/users/admin/check")
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                exists = json.loads(response.read().decode('utf-8'))
                return exists  # Returns True if admin exists
    except Exception:
        return False

def create_admin():
    """Create admin user"""
    log(f"Creating admin user: {ADMIN_USER}")

    data = {
        "Username": ADMIN_USER,
        "Password": ADMIN_PASSWORD
    }

    req = urllib.request.Request(
        f"{PORTAINER_URL}/api/users/admin/init",
        data=json.dumps(data).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                result = json.loads(response.read().decode('utf-8'))
                log(f"✓ Admin user created successfully")
                log(f"  Username: {ADMIN_USER}")
                log(f"  Password: {ADMIN_PASSWORD}")
                log(f"  User ID: {result.get('Id', 'N/A')}")
                return True
    except urllib.error.HTTPError as e:
        if e.code == 409:
            log("ℹ Admin user already exists")
            return True
        else:
            log(f"✗ HTTP error {e.code}: {e.reason}")
            error_body = e.read().decode('utf-8')
            log(f"Response: {error_body}")
            return False
    except Exception as e:
        log(f"✗ Failed to create admin: {str(e)}")
        return False

def main():
    log("Starting Portainer admin initialization...")

    # Wait for Portainer
    if not wait_for_portainer():
        log("✗ Portainer API not ready, exiting")
        sys.exit(1)

    # Check if admin exists
    if check_admin_exists():
        log("ℹ Admin user already exists, skipping creation")
        sys.exit(0)

    # Create admin user
    if create_admin():
        log("✓ Initialization complete")
        sys.exit(0)
    else:
        log("✗ Initialization failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
