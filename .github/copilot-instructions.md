# SYCORE Core-API Custom Instructions (v2.0)

## 1. High-Level Project Summary
- **Identity:** SYCORE Framework (Powered by Sa'ei al-Yaqeen SY-2139 Algorithm).
- **Core Principle:** A Unified Standard Backend (Infrastructure-as-a-Service) that acts as a single source of truth for diverse domains: SAMAM (Business Management) and HOSN (Sovereign Family Cloud).
- **Goal:** Compete with Appwrite by providing a zero-complexity backend using a Generic Resource-Based architecture.

## 2. Tech Stack Requirements
- **Backend:** Django 6.0.4 (Strictly).
- **API Layer:** GraphQL via graphene-django 3.2.3.
- **Security:** X25519 Encryption standards for HOSN domain (Sovereign Privacy).
- **Frontend Compatibility:** Flutter (graphql_flutter).

## 3. Mandatory Architectural Pillars (THE SY-2139 PROTOCOL)
- **Universal Schema (Database):** CRITICAL: Never create separate tables for business entities. Use the `UniversalResource` model with a `JSONField` for all dynamic data.
- **Universal Storage (Files):** Treat file uploads as generic resources using a single `UniversalAsset` model. Like JSON, HOSN domain files are End-to-End Encrypted (E2EE) blobs.
- **Unified Auth:** Use Token-based authentication (e.g., SimpleJWT). Every operation (Read, Write, Upload, WebSocket) must strictly be scoped to `request.user`. Data leakage is a critical failure.
- **Real-Time Synergy:** Emulate Appwrite's real-time capabilities using GraphQL Subscriptions (via Django Channels). Emit events on resource creation/update/deletion.
- **Zero-Knowledge Privacy:** If the resource/asset belongs to the HOSN domain, treat it as E2EE by the client using X25519. The backend MUST NOT attempt to parse or modify encrypted payloads.

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