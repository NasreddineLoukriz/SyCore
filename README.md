# SYCORE Framework (SY-2139 Protocol) 🛡️

**SYCORE** is a next-generation "Smart SDK, Dumb Server" Backend-as-a-Service (BaaS) designed to compete with Firebase and Appwrite, but with **Zero-Trust** and **End-to-End Encryption (E2EE)** at its core.

Powered by the **Sa'ei al-Yaqeen (SY-2139) Protocol**, the backend acts as a highly secure, generic vault that enforces a compound identity (`project_id` + `domain_name` + `security_clearance`). The data privacy policies are entirely dictated by the Client SDK and immutably enforced by the backend.

## 🌟 Features

*   **Zero-Knowledge Privacy (E2EE)**: The server never knows your data. If clearance is set to `E2EE`, the payload is an encrypted blob (Blind Storage).
*   **Universal Schema**: No need to create specific tables for business entities. Everything is a `UniversalResource` or `UniversalAsset`.
*   **Policy Immutability Gate**: Trust on First Use (TOFU). Domains are locked to their initial security clearance (`E2EE`, `PLAIN`, `JAHR`, etc.).
*   **Real-Time Synergy**: Live GraphQL Subscriptions and WebSockets (Django Channels) for real-time updates without polling.
*   **Unified Cryptographic Engines**:
    *   **🏰 HOSN (1-to-1 E2EE)**: Private messaging using X25519 and ChaCha20-Poly1305.
    *   **🏢 SAMAM (Team Encryption)**: Group/Team environments using a wrapped Team Master Key (AES-GCM).
    *   **📢 JAHR (Public Signed Content)**: Public but verifiable data using Ed25519 digital signatures.

## 🏗️ Architecture & Ecosystem

*   `sycore-backend/`: The core Django application (GraphQL API, Real-Time subscriptions, Core Auth).
*   `sycore-sdk/`: Client-side SDKs (e.g., Flutter `dart_sycore_sdk`) that abstract the encryption protocol and API calls.
*   `sycore-console/`: A web-based admin dashboard for developers.
*   `sycore-cli/`: Command-line interface for deploying and managing the environment.
*   `development-docker/`: Docker Compose setup for a zero-complexity Appwrite-like deployment.

## 🚀 Getting Started

### 1. Backend Setup
```bash
cd sycore-backend
python -m venv venv
source venv/bin/activate
pip install -r ../requirements.txt
python manage.py migrate
python manage.py runserver
```

### 2. Client SDK (Flutter/Dart)
Add `dart_sycore_sdk` to your project and initialize the Maestro:

```dart
import 'package:dart_sycore_sdk/dart_sycore_sdk.dart';

final sycore = await SycoreClient.initialize(
  endpointUrl: 'http://localhost:8000/graphql/',
  projectId: 'my_awesome_project',
);

// E2EE is handled entirely seamlessly!
```

## 📚 Documentation
Check out the `/sycore-sdk/dart_sycore_sdk/docs` folder for detailed SDK usage.

## 🔒 Security
This framework enforces strict separation between the transmission layer and the cryptographic layer. The backend **cannot** attempt to parse, search, or modify E2EE payloads. Data leakage is considered a critical architecture failure.
