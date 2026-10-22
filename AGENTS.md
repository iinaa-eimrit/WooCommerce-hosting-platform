# Project context for AI assistants

- Monorepo: `services/*` uses TypeScript, Node 22, ESM and NodeNext.
- MCP uses stateless Streamable HTTP with JSON responses.
- Gateway tool names are always `<slug>__<tool>`.
- Secrets come only from environment variables/Kubernetes Secrets; never commit them.
- Upstream credentials never appear in API responses or logs.
- Keep probe endpoints and resource limits on every workload.
