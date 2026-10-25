# Demo recording runbook

Target length: 12-15 minutes. Record the real local k3d deployment and explain each action in your own words. Do not show secret values or reuse a production key in the recording. This runbook assumes the local release is named `urumi` and the local URLs are `gateway.localtest.me` and `store.localtest.me`.

## Before recording

1. Start the local cluster and confirm the application is ready:

   ```sh
   kubectl config use-context k3d-urumi
   kubectl get pods -A
   kubectl get pvc -A
   ```

2. Open a clean browser window at `http://gateway.localtest.me`; sign in as the admin. Keep a second browser profile ready for the invited member. Open `http://store.localtest.me` in a tab.
3. Open a terminal at the repository root. Increase its font size. Have another terminal or tab ready for the external MCP client.
4. Test the flow once before recording. Use a test email and Cash on Delivery. The local gateway has a Gemini key configured; do not display the Kubernetes Secret or `.secrets/local.env` contents.
5. On macOS, start a screen recording with **Shift-Command-5**, choose the screen/window, select a microphone if you want narration, and start recording. The assignment asks you to explain the system, so narrate in your own voice.

## Recording outline

### 0:00-1:15 — What the system does

Show the Servers page with WooCommerce, Utils, and Everything connected. Say that the gateway is the one MCP entry point for external clients and dashboard chat; it is the only component that calls upstream MCP servers. Briefly identify WordPress/WooCommerce, the custom Woo MCP service, gateway/Postgres, dashboard, and chat agent.

### 1:15-3:00 — Kubernetes layout and boundaries

Show these commands:

```sh
kubectl get namespaces
kubectl get pods,pvc,ingress -A
kubectl get networkpolicy -A
kubectl get secrets -n gateway
```

Explain the `store`, `gateway`, and `mcp-upstreams` namespaces, persistent storage, and the two public local Ingress hosts. Show only Secret names; never decode or print Secret data. Point out probes and resource requests/limits in the Helm templates. Explain that the upstream MCP services are ClusterIP-only and NetworkPolicies admit the gateway.

### 3:00-7:45 — Definition-of-done flow with two users

1. As admin, open **Team** and create a one-time invitation for User B. Open the link in the second browser profile and set B's password. Invite links are single-use and expire after seven days.
2. As User A, open **Chat** and ask: “Create a product called Urumi Demo Mug priced 299.” Show the trace containing `woo__create_product`, then show the product on the store.
3. In the store, add the Mug to the cart and check out with Cash on Delivery using test contact details. Show the order confirmation and, if time allows, the order in WooCommerce admin.
4. As User A, ask Chat: “What orders came in today?” Show the `woo__list_orders` trace and the Mug order in the response.
5. As User B, create a personal API key. Add the gateway URL and key to Claude Code (or another supported MCP client):

   ```sh
   claude mcp add --transport http urumi http://gateway.localtest.me/mcp \
     --header "Authorization: Bearer <USER_B_API_KEY>"
   ```

   Keep the key out of the video frame and revoke it after the demo. Show the client listing namespaced tools and asking the same orders question. Then ask for a task requiring two upstreams, such as converting an order total, and show the WooCommerce and Utils tools in the call.
6. As admin, revoke B's key. Show that B's next MCP request is rejected. Disable Utils and refresh the client's tool list; show Utils tools disappear. Re-enable Utils after capturing the evidence.
7. Simulate an upstream outage and show isolation:

   ```sh
   kubectl -n mcp-upstreams scale deployment/everything --replicas=0
   ```

   Refresh the Servers page, show Everything as unreachable, and demonstrate that a WooCommerce call still works. Restore it afterward:

   ```sh
   kubectl -n mcp-upstreams scale deployment/everything --replicas=1
   ```

8. Open **Audit** and show entries attributed to the correct users and sources (`chat` for A, `mcp` for B), including the failed revoked-key call if present.

### 7:45-10:30 — MCP routing and security

Show the code for tool naming, cached tool listing, and call routing. Explain that `<slug>__<tool>` prevents name collisions, the cache keeps listing responsive during upstream failures, and calls have per-server timeouts. Show the same-named `echo` tools under `utils__` and `everything__` if visible.

Explain that user API keys are stored as hashes, revocation is checked on every stateless MCP request, and upstream credentials stay server-side and are encrypted at rest. Members use shared upstream permissions through the gateway, so tool actions are audited under each member. Mention the residual risk from malicious tool descriptions and that only admins can register upstreams.

### 10:30-11:30 — Chat agent

Show the Chat page and one tool trace. Explain that the backend issues a short-lived chat token for the logged-in user and routes chat tool calls through the same `/mcp` gateway endpoint. This is why chat actions share the same routing and audit behavior as external MCP calls.

### 11:30-14:30 — Production story without a purchased domain

Show `charts/store/values-local.yaml` vs `charts/store/values-prod.yaml`, `charts/gateway/values-local.yaml` vs `charts/gateway/values-prod.yaml`, and the production section in README. Say:

> “The production setup uses the same Helm charts. The values change the public hosts and store URL, TLS, image registry and tags, and storage settings; production Secrets are applied to the cluster and are not committed. I prepared the k3s deployment path and IP-based `sslip.io` hosts, so a purchased domain is not required. I could not provision a free public VPS because the provider required credit-card verification, so I have not claimed a live VPS deployment. The local k3d deployment is running, and these are the documented production steps.”

Show the GHCR publish/deploy commands from README. Explain that before a real upgrade you would back up persistent data, publish a new immutable image tag, run `helm upgrade`, check `helm history`, and use `helm rollback` if needed. Be clear that Helm rollback does not reverse database or store-content changes.

## After recording

1. Re-enable Utils if it is disabled, restore Everything to one replica, and verify all three upstreams show Connected.
2. Revoke any demo API keys and remove or disable the temporary invitee.
3. Watch the recording once to confirm the text is legible, no secret was shown, and all six required topics are covered.
4. Upload as an unlisted video or shareable Drive link, then submit the video and public repository links at <https://forms.gle/nftwgyNeenSDmiRb6>.
