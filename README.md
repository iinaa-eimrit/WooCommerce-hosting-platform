# Urumi MCP Gateway on Kubernetes

An authenticated MCP gateway that aggregates WooCommerce, utility, and reference MCP servers behind one namespaced tool API. It includes a React operations dashboard, API-key lifecycle, audit logging, encrypted upstream credentials, and an optional LLM chat agent.

## Architecture

`Client → Traefik → gateway (/mcp, /api) → WooCommerce / utils / everything`

The gateway exposes collision-safe names such as `woo__list_orders`, `utils__echo`, and `everything__echo`. Upstream health runs in the background; tool listing reads a cache and does not block on an unavailable server.

## Local setup

Prerequisites: Docker, Node 22+, `kubectl`, Helm 3 and k3d.

```sh
make cluster
make secrets        # optionally enter a Gemini/OpenAI-compatible LLM API key
make up
```

Open `http://gateway.localtest.me` for the dashboard and `http://store.localtest.me` for WordPress. `localtest.me` resolves to 127.0.0.1; if DNS rebinding is blocked, map both hosts in `/etc/hosts`.

The dashboard email is shown by `make secrets`; its password and the optional LLM key stay in the ignored `.secrets/local.env` file. Keep that file private. Rerun `make secrets` after changing credentials so Kubernetes Secrets are refreshed. The local chart is configured for Gemini's OpenAI-compatible endpoint; enter a Gemini API key at setup to enable chat.

### Try the store and chat

1. In the storefront, open **Shop**, add the Urumi Hoodie to the cart, and check out with **Cash on delivery**. Use test contact details; the local store has no real payment processor.
2. In the dashboard, sign in with the credentials from `.secrets/local.env`. The Servers page should show WooCommerce, Utils and Everything.
3. On the Chat page, ask it to create a product, then ask what orders arrived today. The response includes the MCP tools called. Chat is unavailable if no `LLM_API_KEY` is configured.
4. On Team, an admin can add a member with a temporary password. This starter implementation creates the account directly; it does not send invitation email.

### Connect an external MCP client

On the dashboard's **Keys** page, generate a user-owned key and copy it immediately; the full key is only shown once. Configure Claude Code with the gateway URL and that user's key:

```sh
claude mcp add --transport http urumi http://gateway.localtest.me/mcp \
  --header "Authorization: Bearer <USER_API_KEY>"
```

The gateway exposes tools as `<server-slug>__<tool-name>` (for example, `woo__list_products`). After an admin disables an upstream, reconnect a client to refresh its tool list; calls to disabled tools are rejected server-side regardless of a stale client cache. A raw HTTP smoke test is also available as `API_KEY=urm_... ./scripts/dod-smoke.sh`.

## Development and verification

```sh
npm install
npm run typecheck
API_KEY=urm_xxx ./scripts/dod-smoke.sh
```

Every service provides `/healthz` and `/readyz`. Secrets are generated in `.secrets/`, which is ignored by Git. See [DESIGN.md](docs/DESIGN.md) and [THREAT_MODEL.md](docs/THREAT_MODEL.md) for tradeoffs and security controls.

## Production-like k3s

The `values-prod.yaml` files set example public hosts and opt into TLS using existing `store-tls` and `gateway-tls` Secrets. Point DNS at a k3s VPS with Traefik, provision those TLS Secrets (for example, with cert-manager), and provide every required Secret in the namespace that consumes it. Do not commit production credentials or certificate data.

Build and push the five images to a registry reachable by the VPS, then deploy the same charts with registry overrides. For example, set the `wooMcp.image`, `backend.image` and `dashboard.image` repositories/tags on the store and gateway releases, and `image.repository`/`image.tag` on the utils/everything MCP releases. Keep image tags immutable. Ensure the VPS storage class supports the MariaDB, WordPress and Postgres PVCs. The charts reference pre-created Kubernetes Secrets rather than generating credentials during upgrades.

Local-to-VPS differences are values and infrastructure: hostnames/site URL, TLS Secrets, image registry/tags, storage class/size, and externally managed Secrets. No VPS deployment has been performed for this repository yet. For an upgrade, apply the new image tag with `helm upgrade`; inspect the rollout before proceeding to the next release. Roll back a release with `helm rollback <release> <previous-revision> -n <namespace>`. Back up persistent volumes and the database before upgrades; Helm rollback does not undo database or WordPress content changes.

See [DESIGN.md](docs/DESIGN.md), [THREAT_MODEL.md](docs/THREAT_MODEL.md), and [BONUS.md](docs/BONUS.md) for implementation boundaries and tradeoffs.
