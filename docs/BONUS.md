# Bonus and standout features

Core functionality was prioritized over optional platform features.

Implemented security-hardening items from the brief:

- Upstream credentials are encrypted at rest with AES-256-GCM and omitted from API responses.
- API keys are stored as hashes and can be revoked per user.
- NetworkPolicies restrict inbound access to WooCommerce MCP and the reference MCP services to gateway pods.
- Non-root container security contexts and read-only root filesystems are used for the Node gateway/dashboard/upstream workloads.
- Local and production Helm values can opt into Ingress TLS using externally provisioned Secrets.

Not implemented: multi-store provisioning, per-tool/member authorization, OAuth, hosted MCP server deployment, tool-search for very large catalogues, gateway horizontal-scaling validation, per-user rate limiting, metrics dashboards, outbound egress/SSRF protection, or automatic certificate issuance. The production-like k3s deployment has not been performed; see the README for the remaining infrastructure steps.
