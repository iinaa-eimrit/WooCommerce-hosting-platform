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
apply_secret(){
  local namespace="$1" name="$2"; shift 2
  local args=()
  while (( $# )); do args+=(--from-literal "$1=$2"); shift 2; done
  kubectl -n "$namespace" create secret generic "$name" "${args[@]}" --dry-run=client -o yaml | apply
}
for ns in store gateway mcp-upstreams; do kubectl create namespace "$ns" --dry-run=client -o yaml | apply; done
apply_secret store store-secrets \
  mariadb-root-password "$MARIADB_ROOT_PASSWORD" \
  mariadb-password "$MARIADB_PASSWORD" \
  wp-admin-password "$WP_ADMIN_PASSWORD" \
  store-token "$STORE_TOKEN" \
  mcp-inbound-token "$WOO_MCP_TOKEN"
apply_secret mcp-upstreams utils-secrets token "$UTILS_TOKEN"
apply_secret gateway gateway-secrets \
  postgres-password "$POSTGRES_PASSWORD" \
  session-secret "$SESSION_SECRET" \
  credentials-key "$CREDENTIALS_KEY" \
  admin-email "$ADMIN_EMAIL" \
  admin-password "$ADMIN_PASSWORD" \
  llm-api-key "$LLM_API_KEY" \
  woo-mcp-token "$WOO_MCP_TOKEN" \
  utils-token "$UTILS_TOKEN"
echo "Secrets applied for $environment. Dashboard admin: $ADMIN_EMAIL (password remains in the ignored local secrets file)"
