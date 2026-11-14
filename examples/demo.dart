/// SYCORE v1 — live demonstration.
///
///   cd examples && dart pub get && dart run demo.dart
///
/// Every scene uses the real library: real Argon2id, real X25519, real
/// AES-256-GCM, real Ed25519. Nothing is mocked except the server, which is an
/// in-memory class containing no cryptography at all.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sycore_core/sycore_core.dart';

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
  stdout.writeln('  ${bold('المشهد $n')}  $ar');
  stdout.writeln('  ${dim(en)}');
  stdout.writeln(cyan('═' * 68));
}

void client(String s) => stdout.writeln('  ${cyan('[CLIENT]')} $s');
void server(String s) => stdout.writeln('  ${yellow('[SERVER]')} $s');
void ok(String s) => stdout.writeln('  ${green('[  OK  ]')} $s');
void blocked(String s) => stdout.writeln('  ${green('[BLOCK ]')} $s');
void no(String s) => stdout.writeln('  ${red('[ FAIL ]')} $s');
void info(String s) => stdout.writeln('  ${dim('    ')} $s');

String short(String s, [int n = 26]) =>
    s.length <= n ? s : '${s.substring(0, n)}…';

Future<void> expectFail(String label, Future<Object?> Function() action) async {
  try {
    await action();
    no('$label — نجح، وكان يجب أن يفشل!');
  } catch (_) {
    ok('$label — فشل كما هو متوقّع');
  }
}

// ───────────────────────────────────────────── demo

Future<void> main() async {
  stdout.writeln();
  stdout.writeln(bold('  S Y C O R E  ·  wire format v1'));
  stdout.writeln('  ${dim('خادم أعمى · عميل ذكي · المحرّكات = عدد اللفّات')}');
  stdout.writeln();
  stdout.writeln('  ${dim('SPEC.md §2-§8  ·  vectors/v1.json  ·  sycore_core 0.1.0')}');

  // ── identities ────────────────────────────────────────────────
  act(1, 'الهويات', 'every user = one X25519 key + one Ed25519 key');
  final ali = await Identity.create('usr_ali', seed: utf8b('ali-demo-seed'));
  final sara = await Identity.create('usr_sara', seed: utf8b('sara-demo-seed'));
  final mona = await Identity.create('usr_mona', seed: utf8b('mona-demo-seed'));
  final directory = IdentityDirectory();
  for (final who in [ali, sara, mona]) {
    await directory.register(who);
    info('${who.id.padRight(9)}  fingerprint ${await who.fingerprint()}');
  }
  ok('ثلاث هويات، والمفاتيح العامة فقط نُشرت في الدليل');

  // ─────────────────────────────────────────────────────────────
  // ── vault ─────────────────────────────────────────────────────
  act(2, 'الخزنة: مفتاح واحد، أجهزة متعددة', 'password → Argon2id → KEK → wrapped VK');
  const password = 'correct horse battery staple';
  final sw = Stopwatch()..start();
  final vk = randomBytes(32);
  final phone = await Vault.create(password: password, deviceId: 'dev_phone', vk: vk);
  sw.stop();
  client('جهاز الهاتف: Argon2id (3 iterations, 64 MiB) في ${sw.elapsedMilliseconds} ms');
  info('VK = ${short(b64u(vk))}  (لا يغادر الجهاز أبداً)');
  info('ظرف الهاتف: ${short(phone.toJson()['wrapped_vk'] as String)}');

  final laptop = await Vault.create(password: password, deviceId: 'dev_laptop', vk: vk);
  info('ظرف اللابتوب: ${short(laptop.toJson()['wrapped_vk'] as String)}  (نفس VK، ظرف مختلف)');

  final vkPhone = await phone.unlock(password);
  final vkLaptop = await laptop.unlock(password);
  ok('الهاتف فتح الخزنة:  VK = ${short(b64u(vkPhone))}');
  ok('اللابتوب فتح الخزنة: VK = ${short(b64u(vkLaptop))}');
  ok('نفس المفتاح بالبايت: ${b64u(vkPhone) == b64u(vkLaptop)}');

  server('يخزّن ظرفين فقط — ولا يعرف كلمة السر ولا VK');
  await expectFail('كلمة سر خاطئة', () => phone.unlock('wrong password'));
  await expectFail('نقل ظرف الهاتف إلى جهاز آخر',
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
  ok('تغيير كلمة السر: VK لم يتغيّر بايتاً واحداً (${b64u(vkAfter) == b64u(vk) ? 'مطابق' : 'مختلف'})');
  info('لم تُعَد تشفير أي بيانات — أُعيد لفّ VK فقط');
  await expectFail('كلمة السر القديمة بعد التغيير', () => rotated.unlock(password));

  // ─────────────────────────────────────────────────────────────
  // ── server + HOSN ─────────────────────────────────────────────
  final serverInstance = BlindServer();

  act(3, 'HOSN: رسالة بين شخصين', 'two wraps: owner + one recipient');
  const secret = 'موعد العملية: 15 جانفي، مستشفى مصطفى باشا، الساعة 8:30';
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
  client('علي شفّر الرسالة ولفّ المفتاح مرّتين');
  info('CK = ${short(msg.wraps.isEmpty ? '' : b64u(await contentKeyAsOwner(msg, vk)))}');
  info('wraps = ${msg.readerCount}  → ${msg.wraps.map((w) => '${w.to}:${w.kind}').join(', ')}');

  serverInstance.put(msg, clearance: Clearance.e2ee);
  server('خزّن ${unb64u(msg.ciphertext).length} بايت مشفّرة في المجال health');
  info('ciphertext = ${short(msg.ciphertext, 44)}');
  info('قائمة القرّاء = ${msg.wraps.map((w) => w.to).join(', ')}  (بيانات وصفية فقط)');

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
    no('الخادم فكّ التشفير — التصميم فاشل!');
  } catch (_) {
    blocked('الخادم حاول فكّ التشفير بمفتاح عشوائي → ${red('فشل')} (لا يملك CK)');
  }

  final fetched = serverInstance.fetch('res_001', requester: sara.id);
  final read = utf8.decode(await openAsRecipient(fetched, sara));
  ok('سارة جلبت الظرف وفكّته: "$read"');
  await expectFail('منى (ليست في wraps) تحاول الجلب',
      () async => serverInstance.fetch('res_001', requester: mona.id));

  // ─────────────────────────────────────────────────────────────
  // ── AAD ───────────────────────────────────────────────────────
  act(4, 'AAD: لماذا لا يستطيع الخادم نقل الرسائل', 'ciphertext is bound to its row');
  final moved = Envelope(
    id: 'res_999', // تسمية أخرى
    projectId: msg.projectId,
    domain: msg.domain,
    ownerId: msg.ownerId,
    version: msg.version,
    nonce: msg.nonce,
    ciphertext: msg.ciphertext,
    wraps: msg.wraps,
  );
  server('مشغّل خبيث نقل الشيفرة من res_001 إلى res_999…');
  await expectFail('سارة تفتح الشيفرة المنقولة', () => openAsRecipient(moved, sara));
  info('الرسالة لم تُلمس، لكن AAD يحمل رقم المورد → يفشل الفتح');

  // ─────────────────────────────────────────────────────────────
  // ── SAMAM ─────────────────────────────────────────────────────
  act(5, 'SAMAM: مجموعة، وسحب عضو', '1 + N wraps, and an epoch per rotation');
  final group = await Group.create(
    id: 'grp_family',
    projectId: 'prj_home',
    domain: 'expenses',
    members: [await recipientOf(ali), await recipientOf(sara), await recipientOf(mona)],
  );
  info('Epoch ${group.epoch} · الأعضاء: ${group.members.keys.join(', ')}');

  final g1 = await group.sealMessage(
    resourceId: 'res_g01',
    ownerId: ali.id,
    owner: ali,
    vaultKey: vk,
    plaintext: 'ميزانية جانفي: 45,000 دج',
  );
  serverInstance.put(g1, clearance: Clearance.e2ee);
  ok('رسالة epoch 1: wraps = ${g1.readerCount}  (المالك + 3 أعضاء)');
  ok('منى قرأت: "${utf8.decode(await openAsRecipient(g1, mona))}"');

  server('سحب منى من المجموعة → epoch ${group.epoch + 1} بمفتاح جديد');
  final group2 = group.rotate(remaining: [ali.id, sara.id]);
  final g2 = await group2.sealMessage(
    resourceId: 'res_g02',
    ownerId: ali.id,
    owner: ali,
    vaultKey: vk,
    plaintext: 'ميزانية فيفري: 39,500 دج',
  );
  serverInstance.put(g2, clearance: Clearance.e2ee);
  ok('رسالة epoch 2: wraps = ${g2.readerCount}  — منى ليست فيها');
  await expectFail('منى تحاول قراءة رسالة epoch 2', () => openAsRecipient(g2, mona));
  ok('منى ما زالت تقرأ رسالة epoch 1 (كانت عضواً حينها): '
      '"${utf8.decode(await openAsRecipient(g1, mona))}"');
  info('هذا هو الفرق بين «سحب» و«إخفاء الماضي»');

  // ─────────────────────────────────────────────────────────────
  // ── JAHR ──────────────────────────────────────────────────────
  act(6, 'JAHR: نشر عام موقّع', 'zero wraps, one signature, read by anyone');
  final post = await publishPublic(
    projectId: 'prj_home',
    domain: 'blog',
    resourceId: 'res_post_01',
    ownerId: ali.id,
    owner: ali,
    content: utf8b('كيف تبني خادماً لا يستطيع قراءة بياناتك'),
  );
  serverInstance.put(post, clearance: Clearance.jahr);
  ok('نُشر: wraps = ${post.readerCount} · signature = ${short(post.signature!)}');

  final anonymous = serverInstance.fetch('res_post_01', requester: 'anonymous');
  final content = unb64u(anonymous.ciphertext);
  ok('زائر بلا حساب قرأ المنشور (JAHR عام بطبيعته)');
  ok('التحقق من الدليل: ${await verifyPublic(envelope: post, content: content, directory: directory)}');

  final tampered = Uint8List.fromList([...content, 0x21]);
  blocked('محتوى معدَّل → التحقق: ${await verifyPublic(envelope: post, content: tampered, directory: directory)}');

  // the trap: verifying with a key shipped in the payload
  final attacker = await Identity.create('usr_attacker', seed: utf8b('attacker-seed'));
  final forged = await publishPublic(
    projectId: 'prj_home',
    domain: 'blog',
    resourceId: 'res_post_02',
    ownerId: ali.id, // يدّعي أنه علي
    owner: attacker, // لكنه يوقّع بمفتاحه
    content: utf8b('أنا علي، وحسابك تم اختراقه'),
  );
  final forgedContent = unb64u(forged.ciphertext);
  final selfCheck = await verifyWithPayloadKey(
    envelope: forged,
    content: forgedContent,
    attackerPublicKey: await attacker.signingPublic(),
  );
  server('انتحال: المحتوى منسوب إلى علي، والتوقيع بمفتاح المهاجم');
  blocked('تحقّق بالمفتاح المرفق مع الحمولة → ${red('$selfCheck')}  ← الفخ');
  ok('تحقّق بالدليل الموثوق → ${await verifyPublic(envelope: forged, content: forgedContent, directory: directory)}  ← الدفاع');
  info('لهذا لا يُقبل مفتاح من الحمولة أبداً — SPEC.md §7');

  // ─────────────────────────────────────────────────────────────
  // ── TOFU ──────────────────────────────────────────────────────
  act(7, 'TOFU: قفل المجال', 'a domain keeps its clearance forever');
  info('health مقفول على: ${serverInstance.policyOf('prj_home', 'health')}');
  final plainAttempt = await seal(
    projectId: 'prj_home',
    domain: 'health',
    resourceId: 'res_003',
    ownerId: ali.id,
    vaultKey: vk,
    owner: ali,
    plaintext: utf8b('نص مكشوف'),
  );
  await expectFail(
    'كتابة PLAIN داخل مجال E2EE',
    () async => serverInstance.put(plainAttempt, clearance: Clearance.plain),
  );
  info('هجوم تلويث البيانات: صف مكشوف وسط صفوف مشفّرة → مرفوض');

  // ─────────────────────────────────────────────────────────────
  // ── summary ───────────────────────────────────────────────────
  act(8, 'ماذا رأى الخادم؟', 'the whole point, in one table');
  for (final id in ['res_001', 'res_g01', 'res_g02', 'res_post_01']) {
    final view = serverInstance.wireView(id);
    info('${(view['id'] as String).padRight(13)} '
        'readers=${(view['readers'] as List).length}  '
        'len=${view['ciphertext_chars']}  '
        'sig=${view['signature']}');
  }
  stdout.writeln();
  ok('الخادم عرف: من، لمن، متى، حجم، مجال');
  ok('الخادم لم يعرف: حرفاً واحداً من المحتوى');
  info('تفويضات ناجحة: ${serverInstance.authorizations} · مرفوضة: ${serverInstance.denials}');
  stdout.writeln();
  stdout.writeln(cyan('─' * 68));
  stdout.writeln('  ${bold('نفس الظرف في كل المشاهد:')} '
      'ciphertext + nonce + wraps[] + signature?');
  stdout.writeln('  ${dim('خزنة=1 · HOSN=2 · SAMAM=1+N · JAHR=0+توقيع')}');
  stdout.writeln(cyan('─' * 68));
}
