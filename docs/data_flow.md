# SYCORE Data Flow Diagram (SY-2139 Protocol v2.0)

This document illustrates how data flows through the SYCORE Framework under the **Zero-Trust BaaS** architecture. It highlights the "Smart SDK, Dumb Server" paradigm, ensuring strict isolation between apps (Multi-Tenancy) and enforcing undeniable security policies (Immutability).

```mermaid
graph TD
    %% Entities
    Client((Smart SDK<br/>Flutter/JS))
    API[GraphQL Gateway<br/>Graphene-Django]
    Auth{JWT Auth &<br/>Resolve User}
    PolicyGate{Policy Immutability<br/>Gate}
    E2EE[E2EE Policy<br/>Zero-Knowledge]
    PLAIN[PLAIN Policy<br/>Business Logic]
    Storage[(Universal DB<br/>PostgreSQL/JSONB)]
    Assets[Media Storage<br/>Assets Vault]

    %% Flow for Data/Resources
    Client -- 1. Mutation (ProjectID, Domain, Policy, Payload) --> API
    API -- 2. Validate JWT --> Auth
    Auth -- 3. Token Valid --> PolicyGate
    
    PolicyGate -- "Domain previously locked to E2EE" --> E2EE
    PolicyGate -- "Domain previously locked to PLAIN" --> PLAIN
    PolicyGate -.- |"Policy Mismatch (Data Poisoning Risk)"| Exception((Reject Request))

    E2EE -- 4. Store Blind Ciphertext --> Storage
    PLAIN -- 4. Store Transparent Searchable JSON --> Storage

    %% Flow for Files/Assets
    Client -- 5. Upload File (with SDK Policy) --> API
    API -- 6. Policy Check & Usages Limits --> Assets
    Assets -- 7. Save to /media/assets/ --> PhysicalDisk[[Disk/S3]]

    %% Legend/Note
    subgraph Client Authority
    Client
    end

    subgraph Backend Subsystem
    Auth
    PolicyGate
    E2EE
    PLAIN
    Storage
    end

    style E2EE fill:#f96,stroke:#333,stroke-width:2px
    style PLAIN fill:#6cf,stroke:#333,stroke-width:2px
    style Storage fill:#9f9,stroke:#333,stroke-width:4px
    style PolicyGate fill:#ff9,stroke:#333,stroke-width:2px
    style Exception fill:#f66,stroke:#333,stroke-width:2px,color:#fff
```

## Description of the Flow

1.  **Initiation (1):** The client application sends a GraphQL request (e.g., `createResource`). If the domain is `HOSN`, the SDK encrypts the data locally before transmission using X25519.
2.  **Authentication Gate (2 & 3):** The JWT Token is validated, identifying the `request.user`. Unauthorized requests are rejected immediately.
3.  **Domain Routing (DomainGate):** The request is routed based on the `domain` field.
    *   **HOSN:** Data is stored as an encrypted blob (Blind Storage). The backend cannot read the content.
    *   **SAMAM:** Data is stored as searchable JSON for business processing.
4.  **Universal Storage:** All resources are saved in the `UniversalResource` table, strictly linked to the `owner_id` to prevent data leakage.
5.  **Asset Management (5, 6, 7):** File uploads check user-specific limits (SY-2139 Limits) before saving to the unified asset storage.

## Updated Flow

The diagram and description have been updated to reflect that the server does **not** have fixed domain names, but instead has a **Policy Immutability Gate** that routes data based on the encrypted or plain pattern requested by the SDK!
