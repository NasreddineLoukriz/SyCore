---
applyTo: "**/schema.py,**/mutations.py,**/queries.py"
---
# GraphQL Standards for Graphene 3.2.3
- **Primary Data Schema:** Always use `graphene.JSONString` (or a custom scalar) for the `data` input in mutations/queries to manage `UniversalResource`.
- **Real-Time Data (Subscriptions):** Design `Subscription` classes using Django Channels and Redis to notify the client (via GraphQL websockets) whenever a resource is created, updated, or deleted, mimicking Appwrite's real-time events.
- **Unified Authentication:** Ensure all mutations, queries, and websocket subscriptions validate the Auth Token (e.g. JWT) via `info.context.user.is_authenticated` and reject unauthenticated requests.
- **Scope Filtering:** CRITICAL: Filter all returned querysets strictly by `owner=info.context.user`.
- **Mutation Standards:** Use consistent naming conventions (`CreateUniversalResource`, `UploadUniversalAsset`). Keep Resolvers clean and move logic to `services.py`.