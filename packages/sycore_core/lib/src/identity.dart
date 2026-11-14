/// Identities and the public key directory.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';

/// A user's device-held key material: X25519 (key agreement) + Ed25519 (signing).
class Identity {
  Identity._(this.id, this.dh, this.signing);

  /// Wrap existing key pairs. Used by conformance tests and by callers that
  /// load keys from a platform keystore.
  factory Identity.fromKeyPairs(
    String id, {
    required SimpleKeyPair dh,
    required SimpleKeyPair signing,
  }) =>
      Identity._(id, dh, signing);

  final String id;
  final SimpleKeyPair dh;
  final SimpleKeyPair signing;

  /// Deterministic when [seed] is given, random otherwise.
  static Future<Identity> create(String id, {Uint8List? seed}) async {
    final base = seed ?? randomBytes(32);
    final dhSeed = await _label(base, ':dh');
    final signSeed = await _label(base, ':sign');
    return Identity._(
      id,
      await X25519().newKeyPairFromSeed(dhSeed),
      await Ed25519().newKeyPairFromSeed(signSeed),
    );
  }

  static Future<Uint8List> _label(Uint8List seed, String label) async {
    final h = await Sha256().hash([...seed, ...utf8b(label)]);
    return Uint8List.fromList(h.bytes);
  }

  Future<Uint8List> dhPublic() async =>
      Uint8List.fromList((await dh.extractPublicKey()).bytes);

  Future<Uint8List> signingPublic() async =>
      Uint8List.fromList((await signing.extractPublicKey()).bytes);

  /// Short human-readable fingerprint of the signing key.
  Future<String> fingerprint() async {
    final pub = await signingPublic();
    final h = await Sha256().hash(pub);
    return b64u(h.bytes.sublist(0, 9));
  }
}

/// The **trusted** source of public keys.
///
/// A verifier must never take a public key from the payload it is verifying —
/// otherwise anyone can sign their own content with their own key and pass.
/// This directory is the answer: it is populated out of band (in production by
/// a signed JAHR entry, see SPEC.md §7).
class IdentityDirectory {
  final Map<String, Uint8List> _dh = {};
  final Map<String, Uint8List> _signing = {};

  Future<void> register(Identity identity) async {
    _dh[identity.id] = await identity.dhPublic();
    _signing[identity.id] = await identity.signingPublic();
  }

  Uint8List dhKeyOf(String id) {
    final k = _dh[id];
    if (k == null) throw StateError('unknown identity: $id');
    return k;
  }

  Uint8List signingKeyOf(String id) {
    final k = _signing[id];
    if (k == null) throw StateError('unknown identity: $id');
    return k;
  }

  bool contains(String id) => _dh.containsKey(id);
}
