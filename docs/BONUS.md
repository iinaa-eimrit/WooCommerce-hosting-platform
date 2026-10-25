# Bonus and standout features

Core functionality was prioritized over optional platform features.

Implemented security-hardening items from the brief:

- Upstream credentials are encrypted at rest with AES-256-GCM and omitted from API responses.
- API keys are stored as hashes and can be revoked per user.
- NetworkPolicies restrict inbound access to WooCommerce MCP and the reference MCP services to gateway pods.
- Non-root container security contexts and read-only root filesystems are used for the Node gateway/dashboard/upstream workloads.
- Local and production Helm values can opt into Ingress TLS using externally provisioned Secrets.

## Multi-store provisioning

`scripts/provision-store.sh <slug> [hostname] [site-title]` provisions an isolated WooCommerce store in its own Kubernetes namespace, with a separate MariaDB database, WordPress PVC, random store credentials, Ingress, and Woo MCP service. It reuses the deployed Woo MCP image and the gateway's inbound MCP token. If `ADMIN_EMAIL` and `ADMIN_PASSWORD` (or `URUMI_ADMIN_EMAIL` and `URUMI_ADMIN_PASSWORD`) are set in the environment, it also registers the new MCP service with the gateway and waits for tool discovery; otherwise, the store is deployed and the upstream can be added from the admin dashboard.

The local flow was verified end to end on k3d: the second storefront returned HTTP 200, its Woo MCP readiness check passed, the gateway connected and discovered five tools, and `bonus__list_products` returned products from the second store. Calls to both `bonus__list_products` and `woo__list_products` succeeded and returned product links on their respective store hosts. The gateway registration is a separate upstream entry, so tools are namespaced by the chosen store slug. Removing a Helm release does not delete its PVCs automatically; review retained data before cleaning up a store namespace.

Still not implemented: per-tool/member authorization, OAuth, hosted MCP server deployment, tool-search for very large catalogues, gateway horizontal-scaling validation, per-user rate limiting, metrics dashboards, outbound egress/SSRF protection, or automatic certificate issuance. The production-like k3s deployment has not been performed; see the README for the remaining infrastructure steps.
