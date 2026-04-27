---
applyTo: "**/schema.py"
---
# Flutter Frontend Compatibility Rules
- Use CamelCase for GraphQL field names for consistency with Flutter's `graphql_flutter`.
- Use descriptive docstrings for GraphQL types, fields, and arguments for better IDE support.
- Return descriptive standard errors with error codes that are easy for the client to handle.
- Prefer explicit mutations with clearly defined input types.
