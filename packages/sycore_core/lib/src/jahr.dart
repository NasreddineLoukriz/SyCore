/// JAHR — public content, signed. Everyone may read; nobody may forge.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'envelope.dart';
import 'identity.dart';

/// Canonical bytes that get signed. Built from the **stored row**, never from
/// the payload, so a replayed signature cannot be moved to another
/// project/domain/resource (SPEC.md §7).
Uint8List jahrCanonicalWithDigest({
  required String projectId,
  required String domain,
  required String resourceId,
  required String ownerId,
  required Uint8List digest,
}) =>
    utf8b('sycore/v1|jahr|$projectId|$domain|$resourceId|$ownerId|${b64u(digest)}');

/// Publish public content. The payload is stored in clear; the signature is
/// the only integrity mechanism.
Future<Envelope> publishPublic({
  required String projectId,
  required String domain,
  required String resourceId,
  required String ownerId,
  required Identity owner,
  required List<int> content,
  int version = 1,
}) async {
  final digest = Uint8List.fromList((await Sha256().hash(content)).bytes);
  final canonical = jahrCanonicalWithDigest(
    projectId: projectId,
    domain: domain,
    resourceId: resourceId,
    ownerId: ownerId,
    digest: digest,
  );
  final sig = await Ed25519().sign(canonical, keyPair: owner.signing);
  return Envelope(
    id: resourceId,
    projectId: projectId,
    domain: domain,
    ownerId: ownerId,
    version: version,
    nonce: '',
    ciphertext: b64u(content),
    wraps: const [],
    signature: b64u(sig.bytes),
  );
}

/// Verify against the **identity directory** — the trusted key source.
///
/// A verifier that uses a public key shipped inside the payload verifies
/// nothing: anyone can generate a key, sign their own content, and ship the
/// key. That is why this method takes the directory, not the payload.
Future<bool> verifyPublic({
  required Envelope envelope,
  required List<int> content,
  required IdentityDirectory directory,
}) async {
  final sig = envelope.signature;
  if (sig == null) return false;
  if (!directory.contains(envelope.ownerId)) return false;

  final digest = Uint8List.fromList((await Sha256().hash(content)).bytes);
  final canonical = jahrCanonicalWithDigest(
    projectId: envelope.projectId,
    domain: envelope.domain,
    resourceId: envelope.id,
    ownerId: envelope.ownerId,
    digest: digest,
  );

  final publicKey = directory.signingKeyOf(envelope.ownerId);
  return Ed25519().verify(
    canonical,
    signature: Signature(
      unb64u(sig),
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
    ),
  );
}

/// Deliberately wrong helper, used only to *demonstrate* the attack in the
/// demo: verifying with a key supplied by the payload always succeeds.
Future<bool> verifyWithPayloadKey({
  required Envelope envelope,
  required List<int> content,
  required Uint8List attackerPublicKey,
}) async {
  final sig = envelope.signature;
  if (sig == null) return false;
  final digest = Uint8List.fromList((await Sha256().hash(content)).bytes);
  final canonical = jahrCanonicalWithDigest(
    projectId: envelope.projectId,
    domain: envelope.domain,
    resourceId: envelope.id,
    ownerId: envelope.ownerId,
    digest: digest,
  );
  return Ed25519().verify(
    canonical,
    signature: Signature(
      unb64u(sig),
      publicKey: SimplePublicKey(attackerPublicKey, type: KeyPairType.ed25519),
    ),
  );
}
