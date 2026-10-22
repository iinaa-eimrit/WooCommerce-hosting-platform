#!/usr/bin/env bash
set -euo pipefail
base="${GATEWAY_URL:-http://gateway.localtest.me}"; : "${API_KEY:?Set API_KEY to a urm_ key}"
curl -fsS "$base/api/auth/me" >/dev/null || true
curl -fsS -X POST "$base/mcp" -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
curl -fsS -X POST "$base/mcp" -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | grep -q 'woo__'
echo 'MCP list smoke test passed.'
