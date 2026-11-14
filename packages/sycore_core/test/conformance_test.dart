/// Conformance against `vectors/v1.json` — the same file a Python, Dart or
/// TypeScript implementation must agree on.
///
/// These tests are the protocol's threat model, written as assertions.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sycore_core/sycore_core.dart';
import 'package:test/test.dart';

late Map<String, dynamic> v;

Future<Uint8List> sha256(String s) async =>
    Uint8List.fromList((await Sha256().hash(utf8b(s))).bytes);

Future<Identity> identityFromSeeds(String id, String label) async {
  return Identity.fromKeyPairs(
    id,
    dh: await X25519().newKeyPairFromSeed(await sha256('$label-x25519-v1')),
    signing: await Ed25519().newKeyPairFromSeed(await sha256('$label-ed25519-v1')),
  );
}

Envelope hosnEnvelope() {
  final h = v['hosn'] as Map<String, dynamic>;
  final ow = h['owner_wrap'] as Map<String, dynamic>;
  final rw = h['recipient_wrap'] as Map<String, dynamic>;
  return Envelope(
    id: h['resource_id'] as String,
    projectId: h['project_id'] as String,
    domain: h['domain'] as String,
    ownerId: h['owner_id'] as String,
    version: h['version'] as int,
    nonce: h['nonce_content'] as String,
    ciphertext: h['ciphertext'] as String,
    wraps: [
      WrappedKey(
        to: ow['to'] as String,
        kind: 'owner',
        epk: rw['epk'] as String,
        nonce: ow['nonce'] as String,
        ct: ow['ct'] as String,
      ),
      WrappedKey(
        to: rw['to'] as String,
        kind: 'recipient',
        epk: rw['epk'] as String,
        nonce: rw['nonce'] as String,
        ct: rw['ct'] as String,
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    final file = File('../../vectors/v1.json');
    v = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('§2 KDF', () {
    test('Argon2id t=3 m=64MiB p=4 matches the vector', () {
      final vault = v['vault'] as Map<String, dynamic>;
      final env = vault['envelope'] as Map<String, dynamic>;
      final kdf = env['kdf'] as Map<String, dynamic>;
      final salt = unb64u(kdf['salt'] as String);
      final key = argon2id(vault['password'] as String, salt);
      expect(b64u(key), vault['expected_kek']);
    });
  });

  group('§4 vault', () {
    test('unlock returns the expected VK', () async {
      final vault = v['vault'] as Map<String, dynamic>;
      final env = vault['envelope'] as Map<String, dynamic>;
      final kdf = env['kdf'] as Map<String, dynamic>;
      final v1 = Vault(
        deviceId: env['device_id'] as String,
        salt: unb64u(kdf['salt'] as String),
        nonce: unb64u(env['nonce'] as String),
        wrappedVk: unb64u(env['wrapped_vk'] as String),
      );
      expect(b64u(await v1.unlock(vault['password'] as String)),
          vault['expected_vk']);
    });

    test('wrong password fails closed', () async {
      final vault = v['vault'] as Map<String, dynamic>;
      final env = vault['envelope'] as Map<String, dynamic>;
      final kdf = env['kdf'] as Map<String, dynamic>;
      final v1 = Vault(
        deviceId: env['device_id'] as String,
        salt: unb64u(kdf['salt'] as String),
        nonce: unb64u(env['nonce'] as String),
        wrappedVk: unb64u(env['wrapped_vk'] as String),
      );
      await expectLater(
        v1.unlock('wrong password'),
        throwsA(isA<SycoreCryptoException>()
            .having((e) => e.code, 'code', 'vault_unlock_failed')),
      );
    });

    test('envelope replayed onto another device fails (AAD binding)', () async {
      final vault = v['vault'] as Map<String, dynamic>;
      final env = vault['envelope'] as Map<String, dynamic>;
      final kdf = env['kdf'] as Map<String, dynamic>;
      final v1 = Vault(
        deviceId: 'dev_laptop', // different device
        salt: unb64u(kdf['salt'] as String),
        nonce: unb64u(env['nonce'] as String),
        wrappedVk: unb64u(env['wrapped_vk'] as String),
      );
      await expectLater(
        v1.unlock(vault['password'] as String),
        throwsA(isA<SycoreCryptoException>()),
      );
    });

    test('password rotation keeps VK byte-identical', () async {
      final vault = v['vault'] as Map<String, dynamic>;
      final env = vault['envelope'] as Map<String, dynamic>;
      final kdf = env['kdf'] as Map<String, dynamic>;
      final v1 = Vault(
        deviceId: env['device_id'] as String,
        salt: unb64u(kdf['salt'] as String),
        nonce: unb64u(env['nonce'] as String),
        wrappedVk: unb64u(env['wrapped_vk'] as String),
      );
      final before = await v1.unlock(vault['password'] as String);
      final rotated = await v1.changePassword(
        oldPassword: vault['password'] as String,
        newPassword: 'a completely new passphrase',
      );
      final after = await rotated.unlock('a completely new passphrase');
      expect(b64u(after), b64u(before));
      await expectLater(
        v1.unlock('a completely new passphrase'),
        throwsA(isA<SycoreCryptoException>()),
      );
    });
  });

  group('§5 content + wraps', () {
    test('owner opens the vector envelope', () async {
      final h = v['hosn'] as Map<String, dynamic>;
      final vk = unb64u((v['vault'] as Map<String, dynamic>)['expected_vk'] as String);
      expect(utf8.decode(await openAsOwner(hosnEnvelope(), vk)), h['plaintext']);
    });

    test('recipient opens the vector envelope', () async {
      final h = v['hosn'] as Map<String, dynamic>;
      final sara = await identityFromSeeds('usr_sara', 'sara');
      expect(
        await sara.dhPublic(),
        unb64u(h['recipient_public'] as String),
        reason: 'fixture keys must match the vectors',
      );
      expect(utf8.decode(await openAsRecipient(hosnEnvelope(), sara)),
          h['plaintext']);
    });

    test('a stranger cannot open it', () async {
      final mona = await identityFromSeeds('usr_mona', 'mona');
      await expectLater(
        openAsRecipient(hosnEnvelope(), mona),
        throwsA(anything),
      );
    });

    test('ciphertext transplanted to another resource fails', () async {
      final e = hosnEnvelope();
      final moved = Envelope(
        id: 'res_9999', // AAD no longer matches
        projectId: e.projectId,
        domain: e.domain,
        ownerId: e.ownerId,
        version: e.version,
        nonce: e.nonce,
        ciphertext: e.ciphertext,
        wraps: e.wraps,
      );
      final vk = unb64u((v['vault'] as Map<String, dynamic>)['expected_vk'] as String);
      await expectLater(
        openAsOwner(moved, vk),
        throwsA(isA<SycoreCryptoException>()),
      );
    });

    test('relabelled recipient fails (identity misbinding)', () async {
      final e = hosnEnvelope();
      final saraKeys = await identityFromSeeds('usr_mona', 'sara');
      final relabelled = Envelope(
        id: e.id,
        projectId: e.projectId,
        domain: e.domain,
        ownerId: e.ownerId,
        version: e.version,
        nonce: e.nonce,
        ciphertext: e.ciphertext,
        wraps: [
          for (final w in e.wraps)
            if (w.kind == 'recipient')
              WrappedKey(
                to: 'usr_mona', // server relabels the reader
                kind: w.kind,
                epk: w.epk,
                nonce: w.nonce,
                ct: w.ct,
              )
            else
              w,
        ],
      );
      await expectLater(
        openAsRecipient(relabelled, saraKeys),
        throwsA(anything),
      );
    });
  });

  group('§7 JAHR', () {
    test('verifies against the directory', () async {
      final j = v['jahr'] as Map<String, dynamic>;
      final ali = await identityFromSeeds('usr_ali', 'ali');
      final dir = IdentityDirectory();
      await dir.register(ali);
      final env = Envelope(
        id: j['resource_id'] as String,
        projectId: j['project_id'] as String,
        domain: j['domain'] as String,
        ownerId: j['owner_id'] as String,
        version: 1,
        nonce: '',
        ciphertext: b64u(utf8b(j['content'] as String)),
        wraps: const [],
        signature: j['signature'] as String,
      );
      expect(dir.signingKeyOf('usr_ali'), isNotEmpty);
      expect(
        await verifyPublic(
          envelope: env,
          content: utf8b(j['content'] as String),
          directory: dir,
        ),
        isTrue,
      );
    });

    test('tampered content fails', () async {
      final j = v['jahr'] as Map<String, dynamic>;
      final ali = await identityFromSeeds('usr_ali', 'ali');
      final dir = IdentityDirectory();
      await dir.register(ali);
      final env = Envelope(
        id: j['resource_id'] as String,
        projectId: j['project_id'] as String,
        domain: j['domain'] as String,
        ownerId: j['owner_id'] as String,
        version: 1,
        nonce: '',
        ciphertext: '',
        wraps: const [],
        signature: j['signature'] as String,
      );
      expect(
        await verifyPublic(
          envelope: env,
          content: utf8b('${j['content']}!'),
          directory: dir,
        ),
        isFalse,
      );
    });

    test('a signature replayed in another domain fails', () async {
      final j = v['jahr'] as Map<String, dynamic>;
      final ali = await identityFromSeeds('usr_ali', 'ali');
      final dir = IdentityDirectory();
      await dir.register(ali);
      final env = Envelope(
        id: j['resource_id'] as String,
        projectId: j['project_id'] as String,
        domain: 'notes', // different domain
        ownerId: j['owner_id'] as String,
        version: 1,
        nonce: '',
        ciphertext: '',
        wraps: const [],
        signature: j['signature'] as String,
      );
      expect(
        await verifyPublic(
          envelope: env,
          content: utf8b(j['content'] as String),
          directory: dir,
        ),
        isFalse,
      );
    });

    test('an unknown signer is not trusted', () async {
      final j = v['jahr'] as Map<String, dynamic>;
      final dir = IdentityDirectory(); // empty: nobody registered
      final env = Envelope(
        id: j['resource_id'] as String,
        projectId: j['project_id'] as String,
        domain: j['domain'] as String,
        ownerId: j['owner_id'] as String,
        version: 1,
        nonce: '',
        ciphertext: '',
        wraps: const [],
        signature: j['signature'] as String,
      );
      expect(
        await verifyPublic(
          envelope: env,
          content: utf8b(j['content'] as String),
          directory: dir,
        ),
        isFalse,
      );
    });
  });
}
