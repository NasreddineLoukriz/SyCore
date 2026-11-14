/// Pure data model. **This file imports no cryptography.**
///
/// The server only ever touches these types, which is why it cannot read
/// anything: it has no code capable of it.
library;

import 'dart:typed_data';

/// One wrapped copy of the content key.
class WrappedKey {
  const WrappedKey({
    required this.to,
    required this.kind,
    required this.epk,
    required this.nonce,
    required this.ct,
  });

  final String to;

  /// `owner` or `recipient`.
  final String kind;

  /// Sender's X25519 public key (base64url).
  final String epk;
  final String nonce;
  final String ct;

  Map<String, Object> toJson() =>
      {'to': to, 'kind': kind, 'epk': epk, 'nonce': nonce, 'ct': ct};

  factory WrappedKey.fromJson(Map<String, dynamic> j) => WrappedKey(
        to: j['to'] as String,
        kind: j['kind'] as String,
        epk: j['epk'] as String,
        nonce: j['nonce'] as String,
        ct: j['ct'] as String,
      );
}

/// A reader: user id + their X25519 public key.
class Recipient {
  const Recipient(this.id, this.dhPublic);

  final String id;
  final Uint8List dhPublic;
}

/// The universal resource envelope.
class Envelope {
  const Envelope({
    required this.id,
    required this.projectId,
    required this.domain,
    required this.ownerId,
    required this.version,
    required this.nonce,
    required this.ciphertext,
    required this.wraps,
    this.signature,
  });

  final String id;
  final String projectId;
  final String domain;
  final String ownerId;
  final int version;
  final String nonce;
  final String ciphertext;
  final List<WrappedKey> wraps;
  final String? signature;

  Map<String, Object?> toJson() => {
        'v': 1,
        'id': id,
        'project_id': projectId,
        'domain': domain,
        'owner_id': ownerId,
        'version': version,
        'alg': 'A256GCM',
        'nonce': nonce,
        'ciphertext': ciphertext,
        'wraps': wraps.map((w) => w.toJson()).toList(),
        'signature': signature,
      };

  factory Envelope.fromJson(Map<String, dynamic> j) => Envelope(
        id: j['id'] as String,
        projectId: j['project_id'] as String,
        domain: j['domain'] as String,
        ownerId: j['owner_id'] as String,
        version: j['version'] as int,
        nonce: j['nonce'] as String,
        ciphertext: j['ciphertext'] as String,
        wraps: (j['wraps'] as List)
            .map((e) => WrappedKey.fromJson(e as Map<String, dynamic>))
            .toList(),
        signature: j['signature'] as String?,
      );

  /// How many readers. This — not a name — is the "engine".
  int get readerCount => wraps.length;

  bool canBeReadBy(String userId) =>
      ownerId == userId || wraps.any((w) => w.to == userId);
}
