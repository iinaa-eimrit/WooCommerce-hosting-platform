# Design

The gateway is the sole caller of upstream MCP servers. A background manager owns long-lived upstream clients and refreshes a cached tool catalogue. `tools/list` uses this cache, so one unavailable upstream never delays all clients. Calls are routed using reversible names: `<slug>__<tool>`.

The public MCP endpoint is stateless Streamable HTTP. Authentication is evaluated on every request, which makes API-key revocation immediate and allows horizontal scaling without sticky sessions. The dashboard agent intentionally loops back through the same gateway tool path so authorization, audit records, naming and timeouts remain consistent.

Credentials are AES-256-GCM encrypted at rest; decryption occurs only while constructing the upstream HTTP auth header. Kubernetes Secrets supply all root secrets and are never included in chart values.
