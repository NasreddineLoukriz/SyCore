/// The one envelope shape every engine produces (SPEC.md §5-§6).
///
/// The server only ever sees a sealed blob, a nonce, and a list of wrapped
/// keys. It never derives a key.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'identity.dart';

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

  /// Sender's X25519 public key (base64url). Present on every wrap so the
  /// wire format does not change when ephemeral keys arrive (SPEC.md §10).
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

  static Future<Recipient> of(Identity identity) async =>
      Recipient(identity.id, await identity.dhPublic());
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

/// Build an envelope.
///
/// `recipients` is empty for the vault, has one entry for HOSN, N entries for
/// SAMAM. There is no separate code path: the engine **is** the wrap count.
Future<Envelope> seal({
  required String projectId,
  required String domain,
  required String resourceId,
  required String ownerId,
  required Uint8List vaultKey,
  required Identity owner,
  required Uint8List plaintext,
  int version = 1,
  List<Recipient> recipients = const [],
  Uint8List? contentKey,
  Uint8List? nonceContent,
  Uint8List? nonceOwner,
  Map<String, Uint8List> recipientNonces = const {},
}) async {
  final ck = contentKey ?? randomBytes(32);
  final nCt = nonceContent ?? randomBytes(12);
  final ownerPub = await owner.dhPublic();

  final ciphertext = await aeadSeal(
    key: ck,
    plain: plaintext,
    aad: aad(
      kind: 'resource',
      projectId: projectId,
      domain: domain,
      resourceId: resourceId,
      ownerId: ownerId,
      version: version,
    ),
    nonce: nCt,
  );

  final wraps = <WrappedKey>[];

  // Owner wrap — this is the vault. It is why a new device can read everything
  // the user ever wrote.
  final nOwner = nonceOwner ?? randomBytes(12);
  final ctOwner = await aeadSeal(
    key: vaultKey,
    plain: ck,
    aad: aad(
      kind: 'owner-wrap',
      projectId: projectId,
      domain: domain,
      resourceId: resourceId,
      ownerId: ownerId,
      version: version,
    ),
    nonce: nOwner,
  );
  wraps.add(WrappedKey(
    to: ownerId,
    kind: 'owner',
    epk: b64u(ownerPub),
    nonce: b64u(nOwner),
    ct: b64u(ctOwner),
  ));

  for (final r in recipients) {
    final shared = await X25519().sharedSecretKey(
      keyPair: owner.dh,
      remotePublicKey: SimplePublicKey(r.dhPublic, type: KeyPairType.x25519),
    );
    final ikm = Uint8List.fromList(await shared.extractBytes());
    final kWrap = await hkdf(
      ikm: ikm,
      salt: Uint8List.fromList([...ownerPub, ...r.dhPublic]),
      info: infoHosnWrap,
    );
    final n = recipientNonces[r.id] ?? randomBytes(12);
    final ct = await aeadSeal(
      key: kWrap,
      plain: ck,
      aad: aad(
        kind: 'recipient-wrap',
        projectId: projectId,
        domain: domain,
        resourceId: resourceId,
        ownerId: ownerId,
        version: version,
        recipientId: r.id,
      ),
      nonce: n,
    );
    wraps.add(WrappedKey(
      to: r.id,
      kind: 'recipient',
      epk: b64u(ownerPub),
      nonce: b64u(n),
      ct: b64u(ct),
    ));
  }

  return Envelope(
    id: resourceId,
    projectId: projectId,
    domain: domain,
    ownerId: ownerId,
    version: version,
    nonce: b64u(nCt),
    ciphertext: b64u(ciphertext),
    wraps: wraps,
  );
}

/// Recover the content key as the owner, using the vault key.
Future<Uint8List> contentKeyAsOwner(Envelope env, Uint8List vaultKey) async {
  final w = env.wraps.firstWhere((w) => w.kind == 'owner');
  return aeadOpen(
    key: vaultKey,
    sealed: unb64u(w.ct),
    aad: aad(
      kind: 'owner-wrap',
      projectId: env.projectId,
      domain: env.domain,
      resourceId: env.id,
      ownerId: env.ownerId,
      version: env.version,
    ),
    nonce: unb64u(w.nonce),
  );
}

/// Recover the content key as a recipient.
Future<Uint8List> contentKeyAsRecipient(Envelope env, Identity me) async {
  final w = env.wraps.firstWhere((w) => w.to == me.id);
  final epk = unb64u(w.epk);
  final shared = await X25519().sharedSecretKey(
    keyPair: me.dh,
    remotePublicKey: SimplePublicKey(epk, type: KeyPairType.x25519),
  );
  final ikm = Uint8List.fromList(await shared.extractBytes());
  final myPub = await me.dhPublic();
  final kWrap = await hkdf(
    ikm: ikm,
    salt: Uint8List.fromList([...epk, ...myPub]),
    info: infoHosnWrap,
  );
  return aeadOpen(
    key: kWrap,
    sealed: unb64u(w.ct),
    aad: aad(
      kind: 'recipient-wrap',
      projectId: env.projectId,
      domain: env.domain,
      resourceId: env.id,
      ownerId: env.ownerId,
      version: env.version,
      recipientId: me.id,
    ),
    nonce: unb64u(w.nonce),
  );
}

/// Open the payload with a content key. AAD binds it to this exact row.
Future<Uint8List> openContent(Envelope env, Uint8List contentKey) => aeadOpen(
      key: contentKey,
      sealed: unb64u(env.ciphertext),
      aad: aad(
        kind: 'resource',
        projectId: env.projectId,
        domain: env.domain,
        resourceId: env.id,
        ownerId: env.ownerId,
        version: env.version,
      ),
      nonce: unb64u(env.nonce),
    );

/// Owner path in one call.
Future<Uint8List> openAsOwner(Envelope env, Uint8List vaultKey) async =>
    openContent(env, await contentKeyAsOwner(env, vaultKey));

/// Recipient path in one call.
Future<Uint8List> openAsRecipient(Envelope env, Identity me) async =>
    openContent(env, await contentKeyAsRecipient(env, me));
