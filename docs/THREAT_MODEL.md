# Threat model

**Assets:** API keys, session cookies, upstream credentials, store token, customer/order data and audit trail.

**Controls:** API keys are high-entropy values stored only as SHA-256 hashes. Sessions use httpOnly cookies. Upstream credentials are encrypted at rest and omitted from API responses. WooCommerce uses a scoped `shop_manager` service identity rather than an admin account.

**Network boundary:** Woo MCP and utility MCP services are ClusterIP-only. In a production installation, NetworkPolicies restrict ingress to gateway pods. Only the storefront and gateway ingress hosts are public.

**Residual risks:** a compromised gateway can call enabled upstreams; mitigate with namespace isolation, credential rotation, least-privilege accounts, image scanning and central audit shipping. Tool calls are not retried automatically because writes may not be idempotent.
