---
applyTo: "**/services.py"
---
# Business Logic & Services Rules (SY-2139)
- **Separation of Concerns:** Keep complex logic out of GraphQL Resolvers. Place writes/actions in `services.py` and complex queries/reads in `selectors.py`.
- **Resource Ownership:** Always validate the user's active ownership token before dispatching a service logic for editing a `UniversalResource` or a `UniversalAsset`.
- **File System/Storage Service:** When parsing file uploads (for Assets), utilize streaming methods to prevent memory overflow. Store large files locally or via standard Object Storage, always maintaining mapping with the user.
- **Real-Time Dispatch:** After a successful CRUD operation inside a service, dispatch an event to the websocket layer to broadcast changes to the active client.
- **Zero-Knowledge Action Constraint:** For the 'HOSN' domain, do NOT apply internal processing (e.g., image resizing or parsing) to any E2EE `UniversalAsset` or `UniversalResource` payload. Pass payloads unmodified.
