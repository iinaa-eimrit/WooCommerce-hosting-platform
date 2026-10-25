# Threat model

## Assets and boundaries

Assets include gateway API keys, dashboard session cookies, upstream credentials, the WooCommerce store token, customer/order data and audit records. The browser is untrusted. The gateway is the trust boundary between authenticated users and upstreams. Store and MCP services are internal ClusterIP Services; ingress exposes the store and dashboard/gateway only. NetworkPolicies restrict inbound MCP traffic to gateway pods.

## 1. What can a member do with a shared upstream credential they never see?

A member can invoke any tool exposed by an enabled upstream using the authority of that upstream's configured service identity. For WooCommerce this currently includes listing and creating products, reading orders, and changing order status using the `shop_manager` identity. Members cannot directly retrieve the credential from the dashboard or MCP responses, but the gateway remains a shared-credential deputy: hiding the credential does not limit the actions its tools allow. Each call is attributed to the member in the audit log. A compromised gateway can exercise all configured upstream authority.

Mitigations in this implementation are a dedicated least-privilege WooCommerce service account, encrypted upstream credentials at rest, server-side-only credential attachment, per-user gateway keys, immediate key revocation, and audit attribution. Per-tool authorization is not implemented; destructive tools are therefore available to members who can call the WooCommerce upstream.

Team invitation links are bearer tokens: anyone holding an unexpired link can claim that member invitation and set its password. Tokens are random, stored only as SHA-256 hashes, expire after seven days, and can be accepted once. Admins should share links only with the intended invitee and through a trusted channel.

## 2. Why are client tokens not passed through to upstreams?

A gateway API key is intended for the gateway audience, not for every upstream. Passing it along would disclose a reusable credential to an upstream that may be compromised or malicious, and could enable replay against the gateway or another service. Upstreams also do not have the gateway's user/key database and cannot validate its revocation rules. The gateway authenticates the caller, records the caller identity, and uses its own configured credential for the selected upstream. Chat uses a short-lived internal JWT scoped to the gateway's chat MCP audience and also does not forward the browser session cookie.

## 3. What if an upstream is untrusted or its tool descriptions manipulate the model?

An upstream can provide misleading tool names, descriptions, schemas, and results. A poisoned description or result could try to persuade the model to disclose data or make an unintended tool call. Namespacing prevents a tool from impersonating another server's slug, and descriptions are prefixed with the server name and capped. Tool arguments are routed only to the upstream that owns the selected name. The chat system prompt explicitly treats tool results as untrusted data and truncates each result before returning it to the model. Only admins can register or disable servers.

Residual risks remain: the model can still be influenced by malicious descriptions/results; the current prompt does not enforce a formal policy, there is no per-tool allowlist, and the gateway does not restrict outbound destinations when an admin registers a URL. An admin-added URL could therefore create an SSRF path, including toward internal services or cloud metadata endpoints, subject to the gateway's network reachability. Review server URLs/descriptions and limit egress before production use. Do not assume tool descriptions are safe merely because they are namespaced.

## 4. What can one team member do to another?

A member cannot list or revoke another member's keys: key queries and revocation are scoped to the authenticated user ID. A member's audit view is scoped to that user; admins can see all users' audit entries. A member cannot manage servers or members because those routes enforce the admin role in the backend. Disabling a user invalidates their dashboard session and API keys.

Members can still affect shared store state through enabled tools. For example, one member can create a product or change an order status that another member later sees. The audit log records who made each tool call. Admins can manage all users and upstreams, so a compromised admin account has broader impact and should use a strong password and a protected session.

## Residual risks

The gateway can use all enabled upstream credentials; audit persistence is best-effort; audit data and database backups may contain customer/order metadata; there is no rate limiting, per-tool permission system, outbound URL allowlist, or production certificate automation. Protect database/PVC backups, rotate credentials, use a production secret manager, review admin-added upstreams, and add egress controls before a public deployment.
