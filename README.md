# Urumi MCP Gateway on Kubernetes

An authenticated MCP gateway that aggregates WooCommerce, utility, and reference MCP servers behind one namespaced tool API. It includes a React operations dashboard, API-key lifecycle, audit logging, encrypted upstream credentials, and an optional LLM chat agent.

## Architecture

`Client → Traefik → gateway (/mcp, /api) → WooCommerce / utils / everything`

The gateway exposes collision-safe names such as `woo__list_orders`, `utils__echo`, and `everything__echo`. Upstream health runs in the background; tool listing reads a cache and does not block on an unavailable server.

## Local setup

Prerequisites: Docker, Node 22+, `kubectl`, Helm 3 and k3d.

```sh
make cluster
make secrets        # enter an optional OpenAI-compatible LLM key
make up
```

Open `http://gateway.localtest.me` for the dashboard and `http://store.localtest.me` for WordPress. `localtest.me` resolves to 127.0.0.1; if DNS rebinding is blocked, map both hosts in `/etc/hosts`.

The initial dashboard credentials are printed by `make secrets`. Create an API key on the Keys page, then point an MCP client at `http://gateway.localtest.me/mcp` with `Authorization: Bearer urm_...`.

## Development and verification

```sh
npm install
npm run typecheck
API_KEY=urm_xxx ./scripts/dod-smoke.sh
```

Every service provides `/healthz` and `/readyz`. Secrets are generated in `.secrets/`, which is ignored by Git. See [DESIGN.md](docs/DESIGN.md) and [THREAT_MODEL.md](docs/THREAT_MODEL.md) for tradeoffs and security controls.

## Production

Use `values-prod.yaml` files to replace local hosts and images, and provide the same secret names through a production secret manager. The Helm charts deliberately reference existing Secrets instead of generating random values during upgrades.
