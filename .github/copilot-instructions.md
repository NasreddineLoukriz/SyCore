# SYCORE Core-API Custom Instructions (v3.0 - Zero-Trust BaaS)

## 1. High-Level Project Summary
- **Identity:** SYCORE Framework (Powered by Sa'ei al-Yaqeen SY-2139 Protocol).
- **Core Principle:** A "Smart SDK, Dumb Server" Backend-as-a-Service (BaaS). The backend is a generic, highly secure vault enforcing a compound identity (`project_id` + `domain_name` + `security_clearance`).
- **Goal:** Compete with Appwrite/Firebase by providing zero-complexity generic storage where Data Privacy policies (E2EE vs. PLAIN) are strictly dictated by the SDK and enforced immutably by the backend.

## 2. Tech Stack Requirements
- **Backend:** Django 6.0.4 (Strictly).
- **API Layer:** GraphQL via graphene-django 3.2.3.
- **Security:** X25519 Encryption for Client-Side E2EE. Backend enforces "Policy Immutability Gate".
- **Frontend Compatibility:** Flutter (graphql_flutter).

## 3. Mandatory Architectural Pillars (THE SY-2139 PROTOCOL)
- **Universal Schema (Database):** CRITICAL: Never create separate tables for business entities. Use the `UniversalResource` model with a `JSONField` for all dynamic data. Data MUST be scoped to a `project_id` (Multi-Tenancy) and `owner` (User).
- **Policy Immutability Gate (Trust on First Use):** The backend does NOT hardcode domain names (like HOSN or SAMAM). When a domain is requested via the SDK for the first time, the backend locks it to the requested `security_clearance` (`E2EE` or `PLAIN`). Future mismatches trigger a Data Poisoning Exception.
- **Universal Storage (Files):** Treat file uploads as generic resources using a single `UniversalAsset` model, enforcing the exact same policy immutability as standard data resources.
- **Unified Auth:** Use Token-based authentication (e.g., SimpleJWT). Every operation (Read, Write, Upload, WebSocket) must strictly be scoped to `request.user`. Data leakage is a critical failure.
- **Real-Time Synergy:** Emulate Appwrite's real-time capabilities using GraphQL Subscriptions (via Django Channels). Emit events on resource creation/update/deletion.
- **Zero-Knowledge Privacy (E2EE):** If the clearance is requested as `E2EE` by the SDK, the payload is an encrypted blob (Blind Storage). The backend MUST NOT attempt to parse, search, or modify E2EE payloads. `PLAIN` payloads are stored as searchable JSONB.

## 4. Coding & Logic Standards
- **Clean Architecture:** Move business logic to services.py (for writes) or selectors.py (for reads). Keep schema.py for definition only.
- **Type Hinting:** Mandatory Python type hints for all functions and methods.
- **Error Handling:** Use custom GraphQL error classes to return descriptive, user-friendly error messages.
- **Naming Convention:** Refer to internal logic as "SY-2139 Protocol" when handling sensitive data operations.

## 5. Reference Documentation
- Django 6.0: https://docs.djangoproject.com/en/6.0/
- Graphene-Django: https://docs.graphene-python.org/projects/django/en/latest/

## 6. Ecosystem & Directory Structure
- **`sycore-backend/`**: The core Django application powering the Unified Standard Backend (GraphQL API, Real-Time subscriptions, Core Auth).
- **`sycore-sdk/`**: Client-side SDKs (e.g., Flutter, JS) that abstract the SY-2139 encryption protocol and API calls.
- **`sycore-console/`**: A web-based admin dashboard for developers to manage users, domains (SAMAM/HOSN), and resources.
- **`sycore-cli/`**: Command-line interface for deploying, migrating, and managing the SYCORE environment.
- **`development-docker/`**: Containerization setup (docker-compose) for easy deployment of the entire stack (PostgreSQL, Redis, Django) mimicking Appwrite's zero-complexity setup.
- **`docs/`**: Developer documentation, guiding the usage of the SY-2139 protocol and the framework features.

## 7. Knowledge Graph Reference
When questions are about architecture/structure:
- Primary source: `/graphify-out/graph.json` (786 nodes, 1,048 edges)
- Quick reference: `/graphify-out/GRAPH_REPORT.md` (God nodes, communities)
- Visualization: `/graphify-out/graph.html`

Query pattern: For any "how do X and Y relate?" use graph instead of file searches.