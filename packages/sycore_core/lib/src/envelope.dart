/// The one envelope shape every engine produces (SPEC.md §5-§6).
///
/// The server only ever sees a sealed blob, a nonce, and a list of wrapped
/// keys. It never derives a key.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'identity.dart';
import 'model.dart';

export 'model.dart';

/// Build a [Recipient] from an [Identity].
Future<Recipient> recipientOf(Identity identity) async =>
    Recipient(identity.id, await identity.dhPublic());

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
    // The owner already has an `owner` wrap. A member list that includes the
    // owner must not add a second, X25519 copy of the same key: the engine is
    // "1 + N readers", not "1 + N + 1".
    if (r.id == ownerId) continue;
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
