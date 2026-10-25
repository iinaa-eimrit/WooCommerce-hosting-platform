#!/usr/bin/env bash
set -euo pipefail

slug="${1:?usage: scripts/provision-store.sh <slug> [hostname] [site-title]}"
host="${2:-${slug}.localtest.me}"
title="${3:-Urumi ${slug}}"

if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || (( ${#slug} > 24 )); then
  echo "slug must use lowercase letters and digits, separated by single hyphens, with a maximum length of 24" >&2
  exit 2
fi
if [[ ! "$host" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "hostname may contain only letters, digits, dots, and hyphens" >&2
  exit 2
fi

namespace="store-${slug}"
if ! kubectl get namespace store >/dev/null 2>&1 || ! kubectl -n gateway get secret gateway-secrets >/dev/null 2>&1; then
  echo "The base store and gateway must be deployed first (including gateway-secrets)." >&2
  exit 1
fi

# Reuse the base store's exact Woo MCP image so each new store runs the image
# already loaded into the local cluster (or the same registry image in prod).
woo_image="${WOO_MCP_IMAGE:-$(kubectl -n store get deployment woo-mcp -o jsonpath='{.spec.template.spec.containers[0].image}')}"
if [[ "$woo_image" != *:* ]]; then
  echo "Could not determine a tagged Woo MCP image; set WOO_MCP_IMAGE=repository:tag." >&2
  exit 1
fi
woo_repo="${woo_image%:*}"
woo_tag="${woo_image##*:}"
inbound_token="$(kubectl -n gateway get secret gateway-secrets -o jsonpath='{.data.woo-mcp-token}' | base64 -d)"
if [[ -z "$inbound_token" ]]; then
  echo "The gateway secret has no Woo MCP token." >&2
  exit 1
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if ! kubectl -n "$namespace" get secret store-secrets >/dev/null 2>&1; then
  kubectl -n "$namespace" create secret generic store-secrets \
    --from-literal=mariadb-root-password="$(openssl rand -hex 24)" \
    --from-literal=mariadb-password="$(openssl rand -hex 24)" \
    --from-literal=wp-admin-password="$(openssl rand -hex 24)" \
    --from-literal=store-token="$(openssl rand -hex 24)" \
    --from-literal=mcp-inbound-token="$inbound_token" >/dev/null
fi

helm upgrade --install "$slug" charts/store \
  --namespace "$namespace" \
  --values charts/store/values-local.yaml \
  --set-string "siteUrl=http://${host}" \
  --set-string "siteTitle=${title}" \
  --set-string "ingress.host=${host}" \
  --set-string "wooMcp.image.repository=${woo_repo}" \
  --set-string "wooMcp.image.tag=${woo_tag}" \
  --wait --wait-for-jobs --timeout 15m

echo "Store ${slug} is provisioned in namespace ${namespace} at http://${host}."
admin_email="${URUMI_ADMIN_EMAIL:-${ADMIN_EMAIL:-}}"
admin_password="${URUMI_ADMIN_PASSWORD:-${ADMIN_PASSWORD:-}}"
if [[ -n "$admin_email" && -n "$admin_password" ]]; then
  URUMI_ADMIN_EMAIL="$admin_email" URUMI_ADMIN_PASSWORD="$admin_password" \
    python3 scripts/register-store-upstream.py "$slug" "$namespace"
else
  echo "Gateway upstream registration: slug=${slug}, URL=http://woo-mcp.${namespace}.svc.cluster.local:3000/mcp"
  echo "Export ADMIN_EMAIL and ADMIN_PASSWORD (or URUMI_ADMIN_EMAIL and URUMI_ADMIN_PASSWORD) to register it automatically, or add it from the admin dashboard."
fi
kubectl -n "$namespace" get pods,pvc,ingress
