#!/usr/bin/env bash
set -euo pipefail
environment="${1:-local}"; file=".secrets/${environment}.env"; mkdir -p .secrets
random(){ openssl rand -hex 24; }
if [[ ! -f "$file" ]]; then
  read -r -s -p 'LLM API key (optional): ' llm; echo
  cat > "$file" <<EOF
MARIADB_ROOT_PASSWORD=$(random)
MARIADB_PASSWORD=$(random)
WP_ADMIN_PASSWORD=$(random)
STORE_TOKEN=$(random)
WOO_MCP_TOKEN=$(random)
UTILS_TOKEN=$(random)
POSTGRES_PASSWORD=$(random)
SESSION_SECRET=$(openssl rand -hex 32)
CREDENTIALS_KEY=$(openssl rand -base64 32)
ADMIN_EMAIL=admin@urumi.local
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
LLM_API_KEY=$llm
EOF
  chmod 600 "$file"
fi
set -a; source "$file"; set +a
apply(){ kubectl apply -f - >/dev/null; }
for ns in store gateway mcp-upstreams; do kubectl create namespace "$ns" --dry-run=client -o yaml | apply; done
kubectl -n store create secret generic store-secrets --from-literal=mariadb-root-password="$MARIADB_ROOT_PASSWORD" --from-literal=mariadb-password="$MARIADB_PASSWORD" --from-literal=wp-admin-password="$WP_ADMIN_PASSWORD" --from-literal=store-token="$STORE_TOKEN" --from-literal=mcp-inbound-token="$WOO_MCP_TOKEN" --dry-run=client -o yaml | apply
kubectl -n mcp-upstreams create secret generic utils-secrets --from-literal=token="$UTILS_TOKEN" --dry-run=client -o yaml | apply
kubectl -n gateway create secret generic gateway-secrets --from-literal=postgres-password="$POSTGRES_PASSWORD" --from-literal=session-secret="$SESSION_SECRET" --from-literal=credentials-key="$CREDENTIALS_KEY" --from-literal=admin-email="$ADMIN_EMAIL" --from-literal=admin-password="$ADMIN_PASSWORD" --from-literal=llm-api-key="$LLM_API_KEY" --from-literal=woo-mcp-token="$WOO_MCP_TOKEN" --from-literal=utils-token="$UTILS_TOKEN" --dry-run=client -o yaml | apply
echo "Secrets applied for $environment. Dashboard admin: $ADMIN_EMAIL / $ADMIN_PASSWORD"
