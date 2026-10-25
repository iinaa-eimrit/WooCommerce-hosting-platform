# System design and tradeoffs

## Architecture

The platform has four in-cluster layers: WordPress/WooCommerce and MariaDB; a custom WooCommerce MCP server; a gateway backend with PostgreSQL; and a static React dashboard. Traefik exposes only the storefront and gateway/dashboard. MCP upstream Services are ClusterIP-only. NetworkPolicies allow the gateway backend to reach WooCommerce MCP and the reference upstreams.

The WooCommerce MCP service is our own Streamable HTTP MCP server. It uses WooCommerce's REST API for products and orders, authenticated by a store-only token checked by a small WordPress must-use plugin. This keeps business validation in WooCommerce instead of writing directly to the database. The MCP inbound token is a separate credential used only between the gateway and WooCommerce MCP.

The gateway is an MCP client to each registered upstream and exposes one stateless Streamable HTTP endpoint. It stores API-key hashes, encrypted upstream credentials, team records and audit entries in PostgreSQL. Dashboard sessions use signed, httpOnly cookies. The dashboard's chat agent creates a short-lived internal JWT and loops tool calls through the same gateway endpoint, so chat calls use the logged-in user's identity and receive the same routing and audit behavior as external MCP calls.

## Aggregation, naming and failures

Each upstream has a unique slug. Exposed tool names use the reversible form `<slug>__<tool-name>`, so duplicate upstream tool names do not collide. The gateway keeps a cached catalogue refreshed in the background; `tools/list` reads that cache instead of waiting for every upstream. Disabled or unreachable servers contribute no tools. Calls are routed by the slug prefix, and an individual call is bounded by the configured upstream timeout (20 seconds by default). The gateway does not automatically retry tool calls because writes may not be idempotent.

The gateway opens one MCP client connection per configured upstream per backend replica. Health refreshes currently check servers sequentially, so refresh latency can grow with the number of slow upstreams. The public MCP transport is stateless and authenticates every request, but upstream connections and cached catalogues are local to each replica; horizontal scaling therefore needs validation and does not provide catalogue push notifications. Clients must reconnect or refresh after tool-list changes.

Audit writes are best-effort: a tool result is returned even if PostgreSQL rejects its audit insert, with the failure logged by the gateway. Member and chat tool results are not automatically retried. Admins create seven-day, single-use invitation links; invitees set their own password. Invitation email delivery is not implemented, so links must be shared out of band.

## Credential flow

API keys are returned once at creation and stored as SHA-256 hashes. The gateway authenticates the caller, then applies its own configured upstream credential. It does not forward a caller's gateway key to an upstream. Upstream credentials are AES-256-GCM encrypted in PostgreSQL and decrypted only to construct the upstream request header. Root secrets, including the LLM API key, are sourced from Kubernetes Secrets; chart values contain only Secret references.

## Production changes

The local and production Helm charts share the same templates. Values change the public hosts and WordPress site URL, enable Ingress TLS, select image registry/tags, and tune storage. A production cluster must provide reachable immutable images, a StorageClass, routable hostnames, cert-manager with a ClusterIssuer (or pre-created TLS Secrets), and Kubernetes Secrets from an external secret manager. Production Ingress annotations request certificates from the `letsencrypt` ClusterIssuer; certificate issuance depends on public HTTP access for ACME validation. The VPS path is documented but has not yet been deployed or tested here.

Before upgrades, back up PostgreSQL and the WordPress/MariaDB persistent volumes. Helm rollback restores Kubernetes manifests and image references; it does not reverse database migrations or store content changes.
