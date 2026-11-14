/// SYCORE v1 — live demonstration.
///
///   cd examples && dart pub get && dart run demo.dart        # English
///   dart run demo.dart --ar                                  # العربية
///
/// Every scene uses the real library: real Argon2id, real X25519, real
/// AES-256-GCM, real Ed25519. Nothing is mocked except the server, which is an
/// in-memory class containing no cryptography at all.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sycore_core/sycore_core.dart';

// ───────────────────────────────────────────── language

/// Most terminals do not apply the Unicode bidi algorithm, so Arabic lines
/// come out with their words in reverse visual order. The demo therefore
/// prints English by default and Arabic on request.
bool _ar = false;

String L(String ar, String en) => _ar ? ar : en;

// ───────────────────────────────────────────── presentation helpers

final bool _color = stdout.supportsAnsiEscapes;

String _c(String code, String s) => _color ? '\x1B[${code}m$s\x1B[0m' : s;
String bold(String s) => _c('1', s);
String dim(String s) => _c('2', s);
String cyan(String s) => _c('36', s);
String green(String s) => _c('32', s);
String red(String s) => _c('31', s);
String yellow(String s) => _c('33', s);

void act(int n, String ar, String en) {
  stdout.writeln();
  stdout.writeln(cyan('═' * 68));
  stdout.writeln('  ${bold(_ar ? 'المشهد $n' : 'Scene $n')}   ${_ar ? ar : en}');
  if (_ar) stdout.writeln('  ${dim(en)}');
  stdout.writeln(cyan('═' * 68));
}

void client(String s) => stdout.writeln('  ${cyan('[CLIENT]')} $s');
void server(String s) => stdout.writeln('  ${yellow('[SERVER]')} $s');
void ok(String s) => stdout.writeln('  ${green('[  OK  ]')} $s');
void blocked(String s) => stdout.writeln('  ${green('[BLOCK ]')} $s');
void no(String s) => stdout.writeln('  ${red('[ FAIL ]')} $s');
void info(String s) => stdout.writeln('  ${dim('      ')} $s');

String short(String s, [int n = 26]) =>
    s.length <= n ? s : '${s.substring(0, n)}…';

Future<void> expectFail(String label, Future<Object?> Function() action) async {
  try {
    await action();
    no(L('$label — نجح، وكان يجب أن يفشل!',
        '$label — succeeded, but it had to fail!'));
  } catch (_) {
    ok(L('$label — فشل كما هو متوقّع', '$label — failed, as expected'));
  }
}

// ───────────────────────────────────────────── demo

Future<void> main(List<String> args) async {
  _ar = args.contains('--ar');

  stdout.writeln();
  stdout.writeln(bold('  S Y C O R E  ·  wire format v1'));
  stdout.writeln('  ${dim(L('خادم أعمى · عميل ذكي · المحرّكات = عدد اللفّات', 'blind server · smart client · engines are wrap-counts'))}');
  stdout.writeln();
  stdout.writeln('  ${dim('spec/SPEC.md §2-§8  ·  vectors/v1.json  ·  sycore_core 0.1.0')}');

  // ── identities ────────────────────────────────────────────────
  act(1, 'الهويات', 'Identities — one X25519 key + one Ed25519 key per user');
  final ali = await Identity.create('usr_ali', seed: utf8b('ali-demo-seed'));
  final sara = await Identity.create('usr_sara', seed: utf8b('sara-demo-seed'));
  final mona = await Identity.create('usr_mona', seed: utf8b('mona-demo-seed'));
  final directory = IdentityDirectory();
  for (final who in [ali, sara, mona]) {
    await directory.register(who);
    info('${who.id.padRight(9)}  fingerprint ${await who.fingerprint()}');
  }
  ok(L('ثلاث هويات، والمفاتيح العامة فقط نُشرت في الدليل',
      'three identities; only public keys went into the directory'));

  // ─────────────────────────────────────────────────────────────
  // ── vault ─────────────────────────────────────────────────────
  act(2, 'الخزنة: مفتاح واحد، أجهزة متعددة',
      'Vault — password → Argon2id → KEK → wrapped VK');
  const password = 'correct horse battery staple';
  final sw = Stopwatch()..start();
  final vk = randomBytes(32);
  final phone =
      await Vault.create(password: password, deviceId: 'dev_phone', vk: vk);
  sw.stop();
  client(L(
      'جهاز الهاتف: Argon2id (3 iterations, 64 MiB) في ${sw.elapsedMilliseconds} ms',
      'phone: Argon2id (3 iterations, 64 MiB) took ${sw.elapsedMilliseconds} ms'));
  info(L('VK = ${short(b64u(vk))}  (لا يغادر الجهاز أبداً)',
      'VK = ${short(b64u(vk))}  (never leaves the device)'));
  info(L('ظرف الهاتف: ${short(phone.toJson()['wrapped_vk'] as String)}',
      'phone envelope: ${short(phone.toJson()['wrapped_vk'] as String)}'));

  final laptop =
      await Vault.create(password: password, deviceId: 'dev_laptop', vk: vk);
  info(L(
      'ظرف اللابتوب: ${short(laptop.toJson()['wrapped_vk'] as String)}  (نفس VK، ظرف مختلف)',
      'laptop envelope: ${short(laptop.toJson()['wrapped_vk'] as String)}  (same VK, different envelope)'));

  final vkPhone = await phone.unlock(password);
  final vkLaptop = await laptop.unlock(password);
  ok(L('الهاتف فتح الخزنة:  VK = ${short(b64u(vkPhone))}',
      'phone unlocked the vault:  VK = ${short(b64u(vkPhone))}'));
  ok(L('اللابتوب فتح الخزنة: VK = ${short(b64u(vkLaptop))}',
      'laptop unlocked the vault: VK = ${short(b64u(vkLaptop))}'));
  ok(L('نفس المفتاح بالبايت: ${b64u(vkPhone) == b64u(vkLaptop)}',
      'byte-identical key: ${b64u(vkPhone) == b64u(vkLaptop)}'));

  server(L('يخزّن ظرفين فقط — ولا يعرف كلمة السر ولا VK',
      'stores two envelopes only — knows neither the password nor the VK'));
  await expectFail(L('كلمة سر خاطئة', 'wrong password'),
      () => phone.unlock('wrong password'));
  await expectFail(
      L('نقل ظرف الهاتف إلى جهاز آخر', 'replaying the phone envelope on another device'),
      () => Vault(
            deviceId: 'dev_laptop',
            salt: phone.salt,
            nonce: phone.nonce,
            wrappedVk: phone.wrappedVk,
          ).unlock(password));

  final rotated = await phone.changePassword(
    oldPassword: password,
    newPassword: 'new passphrase for 2026',
  );
  final vkAfter = await rotated.unlock('new passphrase for 2026');
  ok(L(
      'تغيير كلمة السر: VK لم يتغيّر بايتاً واحداً (${b64u(vkAfter) == b64u(vk) ? 'مطابق' : 'مختلف'})',
      'password changed: the VK is unchanged, byte for byte (${b64u(vkAfter) == b64u(vk) ? 'identical' : 'DIFFERENT'})'));
  info(L('لم تُعَد تشفير أي بيانات — أُعيد لفّ VK فقط',
      'nothing was re-encrypted — only the VK was re-wrapped'));
  await expectFail(L('كلمة السر القديمة بعد التغيير', 'the old password, after the change'),
      () => rotated.unlock(password));

  // ─────────────────────────────────────────────────────────────
  // ── server + HOSN ─────────────────────────────────────────────
  final serverInstance = BlindServer();

  act(3, 'HOSN: رسالة بين شخصين', 'HOSN — a message between two people: 2 wraps');
  const secretAr = 'موعد العملية: 15 جانفي، مستشفى مصطفى باشا، الساعة 8:30';
  const secretEn = 'Surgery: 15 January, Mustapha Pacha hospital, 8:30';
  final secret = L(secretAr, secretEn);
  final msg = await seal(
    projectId: 'prj_home',
    domain: 'health',
    resourceId: 'res_001',
    ownerId: ali.id,
    vaultKey: vk,
    owner: ali,
    plaintext: utf8b(secret),
    recipients: [await recipientOf(sara)],
  );
  client(L('علي شفّر الرسالة ولفّ المفتاح مرّتين',
      'Ali encrypted the message and wrapped the key twice'));
  info('CK = ${short(b64u(await contentKeyAsOwner(msg, vk)))}');
  info('wraps = ${msg.readerCount}  → ${msg.wraps.map((w) => '${w.to}:${w.kind}').join(', ')}');

  serverInstance.put(msg, clearance: Clearance.e2ee);
  server(L('خزّن ${unb64u(msg.ciphertext).length} بايت مشفّرة في المجال health',
      'stored ${unb64u(msg.ciphertext).length} ciphertext bytes in domain health'));
  info('ciphertext = ${short(msg.ciphertext, 44)}');
  info(L('قائمة القرّاء = ${msg.wraps.map((w) => w.to).join(', ')}  (بيانات وصفية فقط)',
      'readers = ${msg.wraps.map((w) => w.to).join(', ')}  (metadata only)'));

  try {
    await aeadOpen(
      key: randomBytes(32), // the server has no key; this is it trying
      sealed: unb64u(msg.ciphertext),
      aad: aad(
        kind: 'resource',
        projectId: msg.projectId,
        domain: msg.domain,
        resourceId: msg.id,
        ownerId: msg.ownerId,
        version: msg.version,
      ),
      nonce: unb64u(msg.nonce),
    );
    no(L('الخادم فكّ التشفير — التصميم فاشل!',
        'the server decrypted it — the design is broken!'));
  } catch (_) {
    blocked(L('الخادم حاول فكّ التشفير بمفتاح عشوائي → ${red('فشل')} (لا يملك CK)',
        'the server tried to decrypt with a random key → ${red('failed')} (it has no CK)'));
  }

  final fetched = serverInstance.fetch('res_001', requester: sara.id);
  final read = utf8.decode(await openAsRecipient(fetched, sara));
  ok(L('سارة جلبت الظرف وفكّته: "$read"', 'Sara fetched and opened it: "$read"'));
  await expectFail(
      L('منى (ليست في wraps) تحاول الجلب', 'Mona, not in the wraps, tries to fetch'),
      () async => serverInstance.fetch('res_001', requester: mona.id));

  // ─────────────────────────────────────────────────────────────
  // ── AAD ───────────────────────────────────────────────────────
  act(4, 'AAD: لماذا لا يستطيع الخادم نقل الرسائل',
      'AAD — why the server cannot move a ciphertext to another row');
  final moved = Envelope(
    id: 'res_999', // another resource id
    projectId: msg.projectId,
    domain: msg.domain,
    ownerId: msg.ownerId,
    version: msg.version,
    nonce: msg.nonce,
    ciphertext: msg.ciphertext,
    wraps: msg.wraps,
  );
  server(L('مشغّل خبيث نقل الشيفرة من res_001 إلى res_999…',
      'a malicious operator copied the ciphertext from res_001 to res_999…'));
  await expectFail(
      L('سارة تفتح الشيفرة المنقولة', 'Sara opens the relocated ciphertext'),
      () => openAsRecipient(moved, sara));
  info(L('الرسالة لم تُلمس، لكن AAD يحمل رقم المورد → يفشل الفتح',
      'the bytes are untouched, but the AAD carries the resource id → open fails'));

  // ─────────────────────────────────────────────────────────────
  // ── SAMAM ─────────────────────────────────────────────────────
  act(5, 'SAMAM: مجموعة، وسحب عضو',
      'SAMAM — a group, then a member is removed: 1 + N wraps');
  final group = await Group.create(
    id: 'grp_family',
    projectId: 'prj_home',
    domain: 'expenses',
    members: [
      await recipientOf(ali),
      await recipientOf(sara),
      await recipientOf(mona),
    ],
  );
  info(L('Epoch ${group.epoch} · الأعضاء: ${group.members.keys.join(', ')}',
      'epoch ${group.epoch} · members: ${group.members.keys.join(', ')}'));

  final g1 = await group.sealMessage(
    resourceId: 'res_g01',
    ownerId: ali.id,
    owner: ali,
    vaultKey: vk,
    plaintext: L('ميزانية جانفي: 45,000 دج', 'January budget: 45,000 DZD'),
  );
  serverInstance.put(g1, clearance: Clearance.e2ee);
  ok(L('رسالة epoch 1: wraps = ${g1.readerCount}  (المالك + 3 أعضاء)',
      'epoch 1 message: wraps = ${g1.readerCount}  (owner + 3 members)'));
  ok(L('منى قرأت: "${utf8.decode(await openAsRecipient(g1, mona))}"',
      'Mona read it: "${utf8.decode(await openAsRecipient(g1, mona))}"'));

  server(L('سحب منى من المجموعة → epoch ${group.epoch + 1} بمفتاح جديد',
      'Mona is removed → epoch ${group.epoch + 1} with a fresh key'));
  final group2 = group.rotate(remaining: [ali.id, sara.id]);
  final g2 = await group2.sealMessage(
    resourceId: 'res_g02',
    ownerId: ali.id,
    owner: ali,
    vaultKey: vk,
    plaintext: L('ميزانية فيفري: 39,500 دج', 'February budget: 39,500 DZD'),
  );
  serverInstance.put(g2, clearance: Clearance.e2ee);
  ok(L('رسالة epoch 2: wraps = ${g2.readerCount}  — منى ليست فيها',
      'epoch 2 message: wraps = ${g2.readerCount}  — Mona is not in it'));
  await expectFail(L('منى تحاول قراءة رسالة epoch 2', 'Mona tries to read the epoch 2 message'),
      () => openAsRecipient(g2, mona));
  ok(L('منى ما زالت تقرأ رسالة epoch 1 (كانت عضواً حينها): '
          '"${utf8.decode(await openAsRecipient(g1, mona))}"',
      'Mona can still read the epoch 1 message (she was a member then): '
          '"${utf8.decode(await openAsRecipient(g1, mona))}"'));
  info(L('هذا هو الفرق بين «سحب» و«إخفاء الماضي»',
      'that is the difference between removing a member and rewriting their past'));

  // ─────────────────────────────────────────────────────────────
  // ── JAHR ──────────────────────────────────────────────────────
  act(6, 'JAHR: نشر عام موقّع',
      'JAHR — public content, signed: 0 wraps, 1 signature');
  final post = await publishPublic(
    projectId: 'prj_home',
    domain: 'blog',
    resourceId: 'res_post_01',
    ownerId: ali.id,
    owner: ali,
    content: utf8b(L('كيف تبني خادماً لا يستطيع قراءة بياناتك',
        'How to build a server that cannot read your data')),
  );
  serverInstance.put(post, clearance: Clearance.jahr);
  ok(L('نُشر: wraps = ${post.readerCount} · signature = ${short(post.signature!)}',
      'published: wraps = ${post.readerCount} · signature = ${short(post.signature!)}'));

  final anonymous = serverInstance.fetch('res_post_01', requester: 'anonymous');
  final content = unb64u(anonymous.ciphertext);
  ok(L('زائر بلا حساب قرأ المنشور (JAHR عام بطبيعته)',
      'an anonymous visitor read it (JAHR is public by design)'));
  ok(L('التحقق من الدليل: ${await verifyPublic(envelope: post, content: content, directory: directory)}',
      'verified against the directory: ${await verifyPublic(envelope: post, content: content, directory: directory)}'));

  final tampered = Uint8List.fromList([...content, 0x21]);
  blocked(L('محتوى معدَّل → التحقق: ${await verifyPublic(envelope: post, content: tampered, directory: directory)}',
      'tampered content → verify: ${await verifyPublic(envelope: post, content: tampered, directory: directory)}'));

  // the trap: verifying with a key shipped in the payload
  final attacker =
      await Identity.create('usr_attacker', seed: utf8b('attacker-seed'));
  final forged = await publishPublic(
    projectId: 'prj_home',
    domain: 'blog',
    resourceId: 'res_post_02',
    ownerId: ali.id, // claims to be Ali
    owner: attacker, // but signs with an attacker key
    content: utf8b(L('أنا علي، وحسابك تم اختراقه', 'I am Ali, your account was compromised')),
  );
  final forgedContent = unb64u(forged.ciphertext);
  final selfCheck = await verifyWithPayloadKey(
    envelope: forged,
    content: forgedContent,
    attackerPublicKey: await attacker.signingPublic(),
  );
  server(L('انتحال: المحتوى منسوب إلى علي، والتوقيع بمفتاح المهاجم',
      'forgery: the content claims to be Ali, signed with the attacker key'));
  blocked(L('تحقّق بالمفتاح المرفق مع الحمولة → ${red('$selfCheck')}  ← الفخ',
      'verify with the key shipped in the payload → ${red('$selfCheck')}  ← the trap'));
  ok(L('تحقّق بالدليل الموثوق → ${await verifyPublic(envelope: forged, content: forgedContent, directory: directory)}  ← الدفاع',
      'verify against the trusted directory → ${await verifyPublic(envelope: forged, content: forgedContent, directory: directory)}  ← the defence'));
  info(L('لهذا لا يُقبل مفتاح من الحمولة أبداً — spec/SPEC.md §7',
      'that is why a key from the payload is never accepted — spec/SPEC.md §7'));

  // ─────────────────────────────────────────────────────────────
  // ── TOFU ──────────────────────────────────────────────────────
  act(7, 'TOFU: قفل المجال', 'TOFU — a domain keeps its clearance forever');
  info(L('health مقفول على: ${serverInstance.policyOf('prj_home', 'health')}',
      'health is locked to: ${serverInstance.policyOf('prj_home', 'health')}'));
  final plainAttempt = await seal(
    projectId: 'prj_home',
    domain: 'health',
    resourceId: 'res_003',
    ownerId: ali.id,
    vaultKey: vk,
    owner: ali,
    plaintext: utf8b(L('نص مكشوف', 'a plaintext row')),
  );
  await expectFail(
    L('كتابة PLAIN داخل مجال E2EE', 'writing PLAIN into an E2EE domain'),
    () async => serverInstance.put(plainAttempt, clearance: Clearance.plain),
  );
  info(L('هجوم تلويث البيانات: صف مكشوف وسط صفوف مشفّرة → مرفوض',
      'data poisoning: one plaintext row among encrypted rows → rejected'));

  // ─────────────────────────────────────────────────────────────
  // ── summary ───────────────────────────────────────────────────
  act(8, 'ماذا رأى الخادم؟', 'What the server saw — the whole point');
  for (final id in ['res_001', 'res_g01', 'res_g02', 'res_post_01']) {
    final view = serverInstance.wireView(id);
    info('${(view['id'] as String).padRight(13)} '
        'readers=${(view['readers'] as List).length}  '
        'len=${view['ciphertext_chars']}  '
        'sig=${view['signature']}');
  }
  stdout.writeln();
  ok(L('الخادم عرف: من، لمن، متى، حجم، مجال',
      'the server knew: who, for whom, when, how big, which domain'));
  ok(L('الخادم لم يعرف: حرفاً واحداً من المحتوى',
      'the server did not know: a single character of the content'));
  info(L('تفويضات ناجحة: ${serverInstance.authorizations} · مرفوضة: ${serverInstance.denials}',
      'authorizations granted: ${serverInstance.authorizations} · denied: ${serverInstance.denials}'));
  stdout.writeln();
  stdout.writeln(cyan('─' * 68));
  stdout.writeln('  ${bold(L('نفس الظرف في كل المشاهد:', 'One envelope in every scene:'))} '
      'ciphertext + nonce + wraps[] + signature?');
  stdout.writeln('  ${dim(L('خزنة=1 · HOSN=2 · SAMAM=1+N · JAHR=0+توقيع', 'vault=1 · HOSN=2 · SAMAM=1+N · JAHR=0+sig'))}');
  stdout.writeln(cyan('─' * 68));
}
