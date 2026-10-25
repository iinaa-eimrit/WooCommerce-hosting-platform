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
4. On Team, an admin can create a one-time invite link for a member. Share it out of band; the invitee sets their own password. Links expire after seven days, and the app does not send invitation email.

### Connect an external MCP client

On the dashboard's **Keys** page, generate a user-owned key and copy it immediately; the full key is only shown once. Configure Claude Code with the gateway URL and that user's key:

```sh
claude mcp add --transport http urumi http://gateway.localtest.me/mcp \
  --header "Authorization: Bearer <USER_API_KEY>"
```

The gateway exposes tools as `<server-slug>__<tool-name>` (for example, `woo__list_products`). After an admin disables an upstream, reconnect a client to refresh its tool list; calls to disabled tools are rejected server-side regardless of a stale client cache. A raw HTTP smoke test is also available as `API_KEY=urm_... ./scripts/dod-smoke.sh`.

### Provision another store

After the base cluster, store, and gateway are running, provision a second isolated WooCommerce store and register it with the gateway:

```sh
set -a
source .secrets/local.env
set +a
./scripts/provision-store.sh outlet outlet.localtest.me "Urumi Outlet"
```

The script creates namespace `store-outlet`, generates separate store/database credentials, deploys the store using the same Woo MCP image as the base store, and registers `outlet` as a Bearer-authenticated gateway upstream. The admin credentials are read from the environment loaded from the ignored local secrets file. Avoid displaying that environment or secret values while recording. Open `http://outlet.localtest.me`; the gateway exposes the new tools as `outlet__list_products`, `outlet__create_product`, and so on. Set `URUMI_GATEWAY_URL` if the dashboard uses a different address. The same chart can be used for production by adapting its values and image settings; this helper targets the existing cluster and default Secret names.

## Development and verification

```sh
npm install
npm run typecheck
API_KEY=urm_xxx ./scripts/dod-smoke.sh
```

Every service provides `/healthz` and `/readyz`. Secrets are generated in `.secrets/`, which is ignored by Git. See [DESIGN.md](docs/DESIGN.md) and [THREAT_MODEL.md](docs/THREAT_MODEL.md) for tradeoffs and security controls.

## Production-like k3s (no purchased domain required)

Use free IP-based hostnames from `sslip.io`, such as `store.203.0.113.10.sslip.io` and `gateway.203.0.113.10.sslip.io` (replace the example IP with the VPS public IPv4). They resolve to the embedded IP. The production Ingresses request `store-tls` and `gateway-tls` certificates through cert-manager and Let's Encrypt. Keep HTTP port 80 open for ACME HTTP-01 validation.

### 1. Create the VPS and connect kubectl

Create an Ubuntu VM with at least 2 vCPU and 4 GB RAM. An ARM64 VM is fine if available. Open inbound TCP ports 22, 80 and 443 in the cloud firewall. Install k3s, which includes Traefik and local-path storage:

```sh
curl -sfL https://get.k3s.io | sh -
sudo cat /etc/rancher/k3s/k3s.yaml
```

Copy the kubeconfig to your laptop as `~/.kube/urumi-vps`, replace the API server address `127.0.0.1` with the VPS public IP, and run `chmod 600 ~/.kube/urumi-vps`. Verify with `KUBECONFIG="$HOME/.kube/urumi-vps" kubectl get nodes`.

### 2. Install cert-manager and create the Let's Encrypt issuer

Run these commands from your laptop against the VPS cluster:

```sh
export KUBECONFIG="$HOME/.kube/urumi-vps"
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace --set crds.enabled=true --wait
```

Save this as `letsencrypt-issuer.yaml`, replacing the email with one you can access, then apply it with `kubectl apply -f letsencrypt-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: you@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

### 3. Publish ARM64-compatible images

Create a GitHub token with package write permission. Log Docker into GHCR interactively so the token is not stored in shell history:

```sh
docker login ghcr.io -u YOUR_GITHUB_USERNAME
```

Publish immutable tags for both common VPS architectures. Use a lowercase GHCR namespace:

```sh
export REGISTRY="ghcr.io/YOUR_GITHUB_USERNAME/urumi"
make publish REGISTRY="$REGISTRY" TAG=v1 PLATFORMS=linux/amd64,linux/arm64
```

Make the five GHCR packages public for the simplest VPS image pulls, or configure an image pull Secret in each namespace if the packages are private.

### 4. Set hostnames and production secrets

Replace `203.0.113.10` with the VPS public IPv4. Keep the IP dots in the hostname:

```sh
export IP="203.0.113.10"
export STORE_HOST="store.$IP.sslip.io"
export GATEWAY_HOST="gateway.$IP.sslip.io"
```

Generate fresh production credentials and apply Kubernetes Secrets to the VPS. The script prompts for the model API key and stores credentials in the ignored `.secrets/prod.env`; keep that file private and use a newly rotated model key:

```sh
KUBECONFIG="$HOME/.kube/urumi-vps" ./scripts/gen-secrets.sh prod
```

### 5. Deploy and verify

```sh
KUBECONFIG="$HOME/.kube/urumi-vps" make deploy ENV=prod \
  REGISTRY="$REGISTRY" TAG=v1 STORE_HOST="$STORE_HOST" GATEWAY_HOST="$GATEWAY_HOST"
KUBECONFIG="$HOME/.kube/urumi-vps" kubectl get pods,pvc,ingress -A
KUBECONFIG="$HOME/.kube/urumi-vps" kubectl get certificates -A
```

Wait until both certificates are `Ready`, then visit `https://$STORE_HOST` and `https://$GATEWAY_HOST`. Sign in using the admin credentials stored in `.secrets/prod.env`; verify the Servers page, chat and an MCP call. Keep hostnames stable after certificates are issued.

The Makefile sets image repositories for all five releases. For upgrades, publish a new immutable tag and redeploy with that tag. Use `helm history <release> -n <namespace>` and `helm rollback <release> <revision> -n <namespace>`. Back up the database and persistent volumes first: a Helm rollback does not reverse data changes. This VPS path has not yet been run for this repository.

Local-to-VPS differences are hostnames/site URL, TLS, image registry/tags, storage class/size, and externally managed Secrets.
See [DESIGN.md](docs/DESIGN.md), [THREAT_MODEL.md](docs/THREAT_MODEL.md), and [BONUS.md](docs/BONUS.md) for implementation boundaries and tradeoffs.
