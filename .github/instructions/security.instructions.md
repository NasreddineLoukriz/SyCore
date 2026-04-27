---
applyTo: "**/*.py"
---
# Security & Multi-tenancy Rules (THE SY-2139 PROTOCOL)
- **Zero-Knowledge Privacy:** For 'HOSN' resources (data or files), assume payloads are E2EE using X25519. The backend must treat `UniversalAsset` blobs and `UniversalResource` JSON fields as opaque data structures.
- **Unified Auth Validations:** CRITICAL: Every HTTP query, WebSocket subscription, and file manipulation MUST validate the JWT Token and resolve the `request.user` / scope before execution.
- **Strict Tenancy Isolation:** Every database update, delete, view, or file fetch MUST be filtered by `.filter(owner=user)`. Data leakage is a catastrophic failure.
- **Protocol Naming:** Refer to internal logic handling sensitive multi-tenant limits and E2EE as the "SY-2139 Protocol".
