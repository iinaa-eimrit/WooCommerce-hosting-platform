#!/usr/bin/env python3
"""Register a provisioned Woo MCP service with the Urumi gateway."""
import http.cookiejar
import json
import os
import subprocess
import sys
import time
import urllib.request

slug, namespace = sys.argv[1:3]
base = os.environ.get('URUMI_GATEWAY_URL', 'http://gateway.localtest.me').rstrip('/')
email = os.environ.get('URUMI_ADMIN_EMAIL') or os.environ.get('ADMIN_EMAIL')
password = os.environ.get('URUMI_ADMIN_PASSWORD') or os.environ.get('ADMIN_PASSWORD')
if not email or not password:
    raise SystemExit('Set URUMI_ADMIN_EMAIL and URUMI_ADMIN_PASSWORD to register the store automatically.')

encoded = subprocess.check_output([
    'kubectl', '-n', 'gateway', 'get', 'secret', 'gateway-secrets',
    '-o', 'jsonpath={.data.woo-mcp-token}',
], text=True).strip()
import base64
credential = base64.b64decode(encoded).decode()
url = f'http://woo-mcp.{namespace}.svc.cluster.local:3000/mcp'
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

def request(path, method='GET', body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base + path, data=data, method=method,
        headers={'Content-Type': 'application/json'},
    )
    with opener.open(req, timeout=30) as response:
        raw = response.read()
        return response.status, json.loads(raw) if raw else None

request('/api/auth/login', 'POST', {'email': email, 'password': password})
_, current = request('/api/servers')
registered = next((server for server in current['servers'] if server['slug'] == slug), None)
if registered:
    if registered['url'] != url:
        raise SystemExit(f'Gateway already has slug {slug} with a different URL; remove or rename that server first.')
else:
    request('/api/servers', 'POST', {
        'slug': slug, 'name': f'Store {slug}', 'url': url,
        'authType': 'bearer', 'credential': credential,
    })

deadline = time.monotonic() + 90
while time.monotonic() < deadline:
    request('/api/servers/refresh', 'POST', {})
    _, current = request('/api/servers')
    registered = next(server for server in current['servers'] if server['slug'] == slug)
    if registered['status'] == 'connected':
        print(f"Gateway registered {slug}: connected, {len(registered['tools'])} tools discovered.")
        break
    time.sleep(3)
else:
    raise SystemExit(f"Gateway registered {slug} but it is {registered['status']}: {registered.get('lastError') or 'no details'}")
