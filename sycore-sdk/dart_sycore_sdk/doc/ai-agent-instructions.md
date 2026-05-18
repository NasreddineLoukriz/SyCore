# SYCORE Dart SDK AI Agent Instructions

These instructions guide an AI agent on how to integrate and use the SYCORE Dart SDK following the SY-2139 Protocol.

## 1. High-Level Concepts
- **Smart SDK, Dumb Server:** The server stores blobs. The SDK handles all encryption/decryption.
- **Protocol (SY-2139):** Dictates three security clearances:
    - **HOSN (E2EE):** 1-to-1 strict encryption. Requires Sender/Receiver Key Pairs and Vault Keys.
    - **SAMAM (Master Key):** Group/Team encryption using a shared `MasterKey`.
    - **JAHR (Public):** Plaintext content but digitally signed for integrity.
- **Identity:** Compound of `project_id` + `domain_name` + `security_clearance`. Clearance is locked on first use for a domain.

## 2. Initialization & User Setup

### Initialize Client
```dart
final client = await SycoreClient.initialize(
  endpointUrl: 'https://api.sycore.io/graphql',
  projectId: 'YOUR_PROJECT_ID',
);
```

### Full Signup & Vault Generation
Initializes the account, obtains a token, derives the vault master key from the password, and uploads public keys to the server.
```dart
await client.signupAndSetupVault(
  username: 'alice',
  password: 'securePassword123',
  email: 'alice@example.com',
);
```

### Standard Login
Reconnects to an existing vault using the password (to derive the master key) and the received JWT token.
```dart
await client.login(
  password: 'securePassword123',
  token: 'jwt_token_from_server',
  userIdSalt: 'unique_user_id_as_salt',
);
```

## 3. Vault & Key Management
- Access the `SycoreVault` via `client.vault`.
- **Vault Key:** Used to wrap personal message keys (for device sync) and encrypt local secrets.
- **ECC Key Pair:** Used for `X25519` key exchange (HOSN).
- **Ed25519 Key Pair:** Used for digital signatures (JAHR).

```dart
final vaultKey = await client.vault.getVaultKey();
final myEccKeyPair = await client.vault.generateEccMessagingKeyPair();
```

## 4. Working with HOSN (1-to-1 E2EE)
HOSN uses a hybrid encryption approach: content is encrypted with a one-time AES key, and that key is wrapped for both the sender (using their vault key) and receiver (using shared secret via ECC).

### Sending a HOSN Message
```dart
await client.sendHosnMessage(
  targetUserId: 'RECEIVER_USER_ID',
  domain: 'chat.private',
  message: 'Hello, this is E2EE!',
);
```

### Fetching & Decrypting HOSN Messages
```dart
List<String> messages = await client.fetchAndDecryptHosnMessages(
  domain: 'chat.private',
);
```

## 5. Working with SAMAM (Group/Team Shared Key)
SAMAM uses a shared `SecretKey` (Master Key) distributed among team members.

### Sending a SAMAM Message
```dart
// The team master key should be securely stored or unwrapped
final messages = await client.sendSamamMessage(
  domain: 'team.marketing',
  message: 'Confidential strategy update.',
  companyMasterKey: teamKey,
);
```

## 6. Working with JAHR (Public Signed Content)
JAHR content is stored in plaintext on the server but contains a signature to verify the author.

### Publishing JAHR Content
```dart
// Implementation in sycore_client.dart (verify if method exists or use engine directly)
final yearEngine = client.jahr;
final signedPayload = await yearEngine.preparePublicContent(
  contentBytes: utf8.encode("Public Announcement"),
  senderKeyPair: myEdKeyPair,
);

await client.network.createResource(
  domain: 'news.public',
  resourceType: 'Post',
  securityClearance: 'JAHR',
  data: signedPayload,
);
```

## 7. Direct Network API (GraphQL)
For custom operations, use `client.network`:
- `createResource`: Send data to server.
- `fetchResources`: Retrieve resources by domain/type.
- `uploadPublicKey`: Inform server of your public keys.

## 8. Development Constraints
- **Multi-Tenancy & Compound Identity:** 
    - Always provide the `projectId` during initialization (Tenant Layer).
    - The `owner_id` is automatically extracted by the server from the JWT token (User Layer).
    - The `domain_name` is required for every operation to enforce the Policy Immutability Gate.
- **Token Persistence:** `SycoreVault` handles master key persistence via `FlutterSecureStorage`.
- **Debugging:** Use `kDebugMode` checks for sensitive logging as seen in the SDK.
