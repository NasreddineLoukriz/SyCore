## 0.0.1+1

* Initial release of the SYCORE Dart SDK.
* Implementation of SY-2139 Protocol cryptographic engines:
    * **HOSN**: End-to-End Encryption (E2EE) using X25519 and ChaCha20-Poly1305.
    * **SAMAM**: Team/Group encryption using AES-GCM and Master Key wrapping.
    * **JAHR**: Public content with Ed25519 digital signatures.
* Secure local storage via `SycoreVault` (using `flutter_secure_storage`).
* Integrated GraphQL client for seamless backend communication.
* Real-time update support via WebSockets (`listenToDomain`).
* Comprehensive documentation for all security modules.
