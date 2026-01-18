#!/usr/bin/env python3
"""
WireGuard Easy - Client Creation Script
Creates default VPN clients via wg-easy REST API
"""

import os
import time
import json
import urllib.request
import urllib.error
import base64
import sys
import http.cookiejar

# Configuration from environment
WG_URL = os.environ.get('WG_URL', 'http://localhost:51821')
WG_PASSWORD = os.environ.get('WG_PASSWORD', '')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', 'data/wg-easy/clients')

# Client names
CLIENTS = [
    {"name": "family-laptop", "save_qr": False},
    {"name": "family-mobile", "save_qr": True}
]

# Global session cookie storage
SESSION_COOKIE = None

def log(msg):
    print(f"[WG-Easy Init] {msg}", flush=True)

def wait_for_wg_easy(max_wait=120):
    """Wait for wg-easy to be ready"""
    log("Waiting for wg-easy to be ready...")
    for i in range(max_wait):
        try:
            req = urllib.request.Request(f"{WG_URL}/")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    log(f"✓ wg-easy ready (waited {i+1}s)")
                    return True
        except Exception:
            pass
        time.sleep(1)
    
    log("✗ wg-easy timeout after 120s")
    return False

def authenticate():
    """Authenticate with wg-easy and get session cookie"""
    global SESSION_COOKIE
    log("Authenticating with wg-easy...")
    
    url = f"{WG_URL}/api/session"
    data = json.dumps({"password": WG_PASSWORD}).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                # Extract session cookie from response
                cookie_header = response.getheader('Set-Cookie')
                if cookie_header:
                    # Extract just the session ID part
                    SESSION_COOKIE = cookie_header.split(';')[0]
                    log("✓ Authentication successful")
                    return True
                else:
                    log("✗ No session cookie received")
                    return False
    except urllib.error.HTTPError as e:
        log(f"✗ Authentication failed: {e.code} {e.reason}")
        return False

def api_request(endpoint, data=None, method='GET'):
    """Make authenticated API request to wg-easy using session cookie"""
    url = f"{WG_URL}{endpoint}"
    
    headers = {'Content-Type': 'application/json'}
    
    # Add session cookie if we have one
    if SESSION_COOKIE:
        headers['Cookie'] = SESSION_COOKIE
    
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
            if response.status in [200, 201, 204]:
                if response.status == 204:
                    return None
                content = response.read().decode('utf-8')
                if content:
                    return json.loads(content)
                return None
    except urllib.error.HTTPError as e:
        if e.code == 409:
            # Client already exists
            return {"error": "already_exists"}
        log(f"✗ API error {endpoint}: {e.code} {e.reason}")
        try:
            error_body = e.read().decode('utf-8')
            log(f"Response: {error_body}")
        except:
            pass
        raise

def create_client(client_name):
    """Create a WireGuard client"""
    log(f"Creating client: {client_name}")
    
    try:
        result = api_request('/api/wireguard/client', {"name": client_name}, 'POST')
        
        if result and result.get("error") == "already_exists":
            log(f"ℹ Client '{client_name}' already exists")
            return True
        
        log(f"✓ Client '{client_name}' created")
        return True
        
    except Exception as e:
        log(f"✗ Failed to create client '{client_name}': {str(e)}")
        return False

def download_client_config(client_name):
    """Download client configuration file"""
    log(f"Downloading config for: {client_name}")
    
    try:
        # Get client list to find ID
        clients = api_request('/api/wireguard/client')
        if not clients:
            log("✗ Could not retrieve client list")
            return False
        
        # Find client by name
        client_id = None
        for client in clients:
            if client.get('name') == client_name:
                client_id = client.get('id')
                break
        
        if not client_id:
            log(f"✗ Client '{client_name}' not found")
            return False
        
        # Download configuration using session cookie
        req = urllib.request.Request(
            f"{WG_URL}/api/wireguard/client/{client_id}/configuration",
            headers={'Cookie': SESSION_COOKIE} if SESSION_COOKIE else {}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            config = response.read().decode('utf-8')
            
            # Save to file
            os.makedirs(OUTPUT_DIR, exist_ok=True)
            config_path = os.path.join(OUTPUT_DIR, f"{client_name}.conf")
            with open(config_path, 'w') as f:
                f.write(config)
            
            log(f"✓ Saved config: {config_path}")
            return True
            
    except Exception as e:
        log(f"✗ Failed to download config: {str(e)}")
        return False

def download_client_qr(client_name):
    """Download client QR code as PNG"""
    log(f"Downloading QR code for: {client_name}")
    
    try:
        # Get client list to find ID
        clients = api_request('/api/wireguard/client')
        if not clients:
            return False
        
        # Find client by name
        client_id = None
        for client in clients:
            if client.get('name') == client_name:
                client_id = client.get('id')
                break
        
        if not client_id:
            return False
        
        # Download QR code (SVG) using session cookie
        req = urllib.request.Request(
            f"{WG_URL}/api/wireguard/client/{client_id}/qrcode.svg",
            headers={'Cookie': SESSION_COOKIE} if SESSION_COOKIE else {}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            qr_svg = response.read()
            
            # Save SVG (PNG conversion would require additional dependencies)
            os.makedirs(OUTPUT_DIR, exist_ok=True)
            qr_path = os.path.join(OUTPUT_DIR, f"{client_name}-qr.svg")
            with open(qr_path, 'wb') as f:
                f.write(qr_svg)
            
            log(f"✓ Saved QR code: {qr_path}")
            return True
            
    except Exception as e:
        log(f"✗ Failed to download QR code: {str(e)}")
        return False

def main():
    log("Starting WireGuard client creation...")
    
    # Check password
    if not WG_PASSWORD:
        log("✗ WG_PASSWORD environment variable not set")
        sys.exit(1)
    
    # Wait for wg-easy
    if not wait_for_wg_easy():
        log("✗ wg-easy not ready, exiting")
        sys.exit(1)
    
    # Authenticate and get session cookie
    if not authenticate():
        log("✗ Failed to authenticate, exiting")
        sys.exit(1)
    
    # Create clients
    success_count = 0
    for client in CLIENTS:
        client_name = client["name"]
        
        # Create client
        if create_client(client_name):
            # Download config
            if download_client_config(client_name):
                success_count += 1
                
                # Download QR code if requested
                if client.get("save_qr"):
                    download_client_qr(client_name)
    
    # Summary
    log("")
    log(f"✓ Created {success_count}/{len(CLIENTS)} clients")
    log(f"Configs saved to: {OUTPUT_DIR}/")
    
    if success_count == len(CLIENTS):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
