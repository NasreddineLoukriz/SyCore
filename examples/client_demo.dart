/// SYCORE SDK — end-to-end walkthrough against the real server.
///
///   cd server && ./run.sh                 # terminal 1
///   cd examples && dart run client_demo.dart   # terminal 2
///
/// This is what a developer writes with `sycore_client`: no HTTP, no JSON, no
/// crypto. Only `register`, `login`, `hosn`, `samam`, `jahr`, `operator`.
library;

import 'dart:io';

import 'package:sycore_client/sycore_client.dart';
import 'package:sycore_core/sycore_core.dart' as core;

// ── presentation ────────────────────────────────────────────────

final bool _color = stdout.supportsAnsiEscapes;
String _c(String code, String s) => _color ? '\x1B[${code}m$s\x1B[0m' : s;
String bold(String s) => _c('1', s);
String dim(String s) => _c('2', s);
String cyan(String s) => _c('36', s);
String green(String s) => _c('32', s);
String red(String s) => _c('31', s);
String yellow(String s) => _c('33', s);

var _failures = 0;

void act(String title) {
  stdout.writeln();
  stdout.writeln(cyan('═' * 70));
  stdout.writeln('  ${bold(title)}');
  stdout.writeln(cyan('═' * 70));
}

void ok(String s) => stdout.writeln('  ${green('[  OK  ]')} $s');
void no(String s) {
  _failures++;
  stdout.writeln('  ${red('[ FAIL ]')} $s');
}

void blocked(String s) => stdout.writeln('  ${green('[BLOCK ]')} $s');
void info(String s) => stdout.writeln('  ${dim('      ')} $s');
void say(String who, String s) =>
    stdout.writeln('  ${cyan('[$who]')} $s');
void srv(String s) => stdout.writeln('  ${yellow('[SERVER]')} $s');

Future<void> expectError(String label, Future<Object?> Function() action,
    {String? code}) async {
  try {
    await action();
    no('$label — expected a refusal, got success');
  } catch (e) {
    final got = switch (e) {
      SycoreApiException() => '${e.status}/${e.code}',
      SycoreException() => e.code,
      _ => e.runtimeType.toString(),
    };
    if (code == null || got.endsWith(code)) {
      ok('$label — refused ($got)');
    } else {
      no('$label — refused for the wrong reason: $got (wanted $code)');
    }
  }
}

// ── demo ────────────────────────────────────────────────────────

const endpoint = 'http://127.0.0.1:8787';
const project = 'prj_home';
const password = 'correct horse battery staple';
const device = 'cli';

/// The CLI and the Flutter app share one local vault directory, so whichever
/// runs first registers the accounts and the other simply unlocks them.
Directory home() => Directory(Platform.environment['SYCORE_HOME'] ??
    '${Platform.environment['HOME'] ?? '/tmp'}/.sycore/app');

/// Register on the first run, unlock afterwards.
Future<void> ensure(SyCore c, String user) async {
  try {
    await c.login(userId: user, password: password, deviceId: device);
  } on SycoreException catch (e) {
    if (e.code != 'no_device_envelope') rethrow;
    await c.register(userId: user, password: password, deviceId: device);
  }
}

Future<void> main() async {
  VaultStore store() => FileVaultStore(root: home());

  final ali = SyCore(server: Uri.parse(endpoint), store: store());
  final sara = SyCore(server: Uri.parse(endpoint), store: store());
  final mona = SyCore(server: Uri.parse(endpoint), store: store());

  stdout.writeln();
  stdout.writeln(bold('  SYCORE SDK · client_demo'));
  stdout.writeln('  ${dim('server $endpoint · spec/SPEC.md · four features, one envelope')}');

  // ── 1. identities + vault ─────────────────────────────────────
  act('1. register — the password never leaves this machine');
  for (final (who, client) in [('usr_ali', ali), ('usr_sara', sara), ('usr_mona', mona)]) {
    final sw = Stopwatch()..start();
    await ensure(client, who);
    sw.stop();
    info('$who → Argon2id ${sw.elapsedMilliseconds} ms · '
        'fingerprint ${client.vault.fingerprint}');
  }
  ok('three identities published; the server stores two public keys each');

  final remote = await ali.operator.audit(limit: 5);
  ok('directory entries came from the API: ${remote.length} audit rows so far');

  // ── 2. vault: second device, password rotation ────────────────
  act('2. vault — one key, two devices, no re-encryption');
  await ali.vault.addDevice('phone', password);
  final devices = await ali.vault.devices();
  ok('devices for usr_ali: ${devices.join(', ')}');

  final aliPhone = SyCore(server: Uri.parse(endpoint), store: store());
  await aliPhone.login(userId: 'usr_ali', password: password, deviceId: 'phone');
  final sameKey = aliPhone.vault.vaultKeyPreview == ali.vault.vaultKeyPreview;
  ok('the phone unlocked the same VK without downloading any content: $sameKey');

  await expectError(
    'a wrong password',
    () => SyCore(server: Uri.parse(endpoint), store: store())
        .login(userId: 'usr_ali', password: 'wrong', deviceId: 'phone'),
    code: 'wrong_password',
  );
  await expectError(
    'a device that has no envelope here',
    () => ali.login(userId: 'usr_ali', password: password, deviceId: 'tablet'),
    code: 'no_device_envelope',
  );

  await ali.vault.changePassword(password, 'a new passphrase');
  await ali.login(userId: 'usr_ali', password: 'a new passphrase', deviceId: device);
  ok('password rotated on this device; the vault key did not move');

  // The Flutter app shares this directory. Leave the passphrase it expects in
  // place, otherwise the next `./run.sh` demo unlocks “usr_ali@laptop” and the
  // app cannot open “usr_ali@cli”.
  await ali.vault.changePassword('a new passphrase', password);
  ok('rotated back, so the app and the CLI keep the same passphrase');

  // ── 3. HOSN ───────────────────────────────────────────────────
  act('3. HOSN — two readers, and the server is not one of them');
  const secret = 'Surgery: 15 January, 8:30, Mustapha Pacha';
  final msg = await ali.hosn.send(
    to: 'usr_sara', project: project, domain: 'health', text: secret);
  say('ali', 'sent ${msg.id} · wraps = ${msg.readerCount} · '
      'readers = ${msg.wraps.map((w) => w.to).join(', ')}');

  final inbox = await sara.hosn.inbox(project: project, domain: 'health');
  ok('sara sees ${inbox.length} row(s); server reported no content');
  ok('sara opens it: "${await sara.hosn.open(msg.id)}"');

  await expectError('mona fetches the same row',
      () => mona.hosn.open(msg.id), code: 'forbidden');
  await expectError('sara opens an id that does not exist',
      () => sara.hosn.open('res_nope'), code: 'not_found');

  // the server cannot open what it stores
  final wire = await ali.hosn.envelopeOf(msg.id);
  try {
    await core.aeadOpen(
      key: core.randomBytes(32),
      sealed: core.unb64u(wire.ciphertext),
      aad: core.aad(
        kind: 'resource', projectId: wire.projectId, domain: wire.domain,
        resourceId: wire.id, ownerId: wire.ownerId, version: wire.version,
      ),
      nonce: core.unb64u(wire.nonce),
    );
    no('the server-side key opened the row — the design is broken');
  } catch (_) {
    blocked('an operator with the database tries a random key → open fails');
  }

  // ── 4. SAMAM ──────────────────────────────────────────────────
  act('4. SAMAM — remove a member, rotate the epoch');
  final group = await ali.samam.create(
    id: 'grp_family', project: project, domain: 'expenses',
    members: ['usr_sara', 'usr_mona']);
  info('epoch ${group.epoch} · members ${group.memberIds.join(', ')}');

  final jan = await ali.samam.post(groupId: group.id, text: 'January budget: 45,000 DZD');
  ok('january message: wraps = ${jan.readerCount} (owner + 2 members)');
  ok('mona reads it: "${await mona.samam.open(jan.id)}"');

  final after = await ali.samam.removeMember(group.id, 'usr_mona');
  srv('membership changed → epoch ${after.epoch}, fresh group key');
  final feb = await ali.samam.post(groupId: group.id, text: 'February budget: 39,500 DZD');
  ok('february message: wraps = ${feb.readerCount}; mona is not among them');
  await expectError('mona opens the february message',
      () => mona.samam.open(feb.id), code: 'forbidden');
  ok('mona can still open january (she was a member then): '
      '"${await mona.samam.open(jan.id)}"');
  info('removal is not retroactive erasure — and the SDK does not pretend it is');

  // ── 5. JAHR ───────────────────────────────────────────────────
  act('5. JAHR — public, signed, verifiable by a stranger');
  final post = await ali.jahr.publish(
    project: project, domain: 'blog',
    text: 'How to build a server that cannot read your data');
  ok('published ${post.id}: wraps = ${post.readerCount}, signature present');

  final anonymous = SyCore(server: Uri.parse(endpoint), store: store());
  ok('anonymous read: "${await anonymous.jahr.read(post.id)}"');

  final check = await ali.jahr.verify(post.id);
  ok('verified against the directory: ${check.verified} (${check.reason})');

  final tampered = await anonymous.jahr.wire(post.id);
  final forged = Map<String, dynamic>.of(tampered)
    ..['ciphertext'] = core.b64u(core.utf8b('tampered text'));
  info('a forged row would carry a signature over different bytes: '
      '${forged['signature'] != null}');

  // the trap, built locally: the payload carries its own key
  final attacker = await core.Identity.create('usr_attacker',
      seed: core.utf8b('attacker-seed'));
  final fake = await core.publishPublic(
    projectId: project, domain: 'blog', resourceId: 'res_fake',
    ownerId: 'usr_ali', owner: attacker,
    content: core.utf8b('I am Ali, your account was compromised'));
  final payloadKeyOk = await core.verifyWithPayloadKey(
    envelope: fake, content: core.unb64u(fake.ciphertext),
    attackerPublicKey: await attacker.signingPublic());
  final directoryOk = await core.verifyPublic(
    envelope: fake, content: core.unb64u(fake.ciphertext),
    directory: core.IdentityDirectory()
      ..registerPublic('usr_ali',
          await ali.me!.identity.dhPublic(), await ali.me!.identity.signingPublic()));
  blocked('verify with the key shipped in the payload → $payloadKeyOk  ← the trap');
  ok('verify against the trusted directory → $directoryOk  ← the defence');

  // ── 6. the operator view ──────────────────────────────────────
  act('6. what the server can see');
  final health = await ali.operator.health();
  final stats = health['stats'] as Map<String, dynamic>;
  info('rows: resources=${stats['resources']} wraps=${stats['wraps']} '
      'identities=${stats['identities']} domains=${stats['domains']}');

  final rows = await ali.operator.rows(project: project, domain: 'health');
  for (final r in rows) {
    info('${r.id}  owner=${r.ownerId}  readers=${r.readers.join(',')}  '
        'chars=${r.ciphertextChars}  v${r.version}');
  }
  ok('metadata yes, content no — and the API has no route that returns content '
      'to a non-reader');

  final audit = await ali.operator.audit(limit: 200);
  final denied = audit.where((e) => e['action'] == 'read.denied').length;
  info('audit entries: ${audit.length}, refusals recorded: $denied');

  stdout.writeln();
  stdout.writeln(cyan('─' * 70));
  if (_failures == 0) {
    stdout.writeln('  ${green(bold('SDK walkthrough complete — 0 failures'))}');
  } else {
    stdout.writeln('  ${red(bold('$_failures failure(s)'))}');
  }
  stdout.writeln(cyan('─' * 70));

  for (final c in [ali, sara, mona, aliPhone, anonymous]) {
    c.close();
  }
  exit(_failures == 0 ? 0 : 1);
}
