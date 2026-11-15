/// The two languages the app speaks, and the words it uses in each.
///
/// Deliberately a plain map rather than generated localisation: the whole app
/// has one text table, and a missing key is loud (`!key`) instead of silent.
library;

import 'package:flutter/widgets.dart';

enum AppLang { en, ar }

/// The single source of truth for the chosen language.
///
/// Set by the switch in the header; the root rebuilds the whole tree, so every
/// screen and every dialog picks up the new direction and the new words.
final ValueNotifier<AppLang> appLang = ValueNotifier(AppLang.en);

/// The raw tables, so a test can prove both languages define the same keys with
/// the same placeholders. Nothing in the app reads these directly.
Map<String, String> get enTable => _en;
Map<String, String> get arTable => _ar;

String _pretty(String template, Map<String, Object?> vars) {
  var out = template;
  for (final e in vars.entries) {
    out = out.replaceAll('{${e.key}}', '${e.value}');
  }
  return out;
}

class Strings {
  const Strings(this.lang);

  final AppLang lang;

  bool get isAr => lang == AppLang.ar;

  /// The language toggle label.
  String get otherLanguageName => isAr ? 'English' : 'العربية';

  /// `t('nav_vault')`, `t('wraps_n', {'n': 3})`.
  String t(String key, [Map<String, Object?>? vars]) {
    final table = isAr ? _ar : _en;
    final raw = table[key] ?? _en[key] ?? '!$key';
    return vars == null ? raw : _pretty(raw, vars);
  }
}

extension StringsContext on BuildContext {
  Strings get s => Strings(appLang.value);

  bool get isAr => appLang.value == AppLang.ar;
}

const _en = <String, String>{
  // ── shell ────────────────────────────────────────────────────
  'app_name': 'SyCore',
  'app_tagline': 'encrypted storage you can see',
  'nav_vault': 'Vault',
  'nav_messages': 'Messages',
  'nav_group': 'Group',
  'nav_public': 'Public',
  'nav_operator': 'Operator',
  'nav_blurb_vault': 'one key, many devices, no re-encryption',
  'nav_blurb_messages': 'HOSN · two readers: you and one person',
  'nav_blurb_group': 'SAMAM · a new key whenever the members change',
  'nav_blurb_public': 'JAHR · public text, signed authorship',
  'nav_blurb_operator': 'what the server can actually see',
  'server_up': 'server up',
  'server_down': 'server down',
  'server_reachable': 'server {url} · reachable',
  'server_unreachable': 'server {url} · not reachable — run server/run.sh',
  'lock_vault': 'Lock vault',
  'project': 'project {id}',
  'fingerprint_short': 'key {f}',
  'build': 'version 0.1.0 · wire v1',
  'refresh': 'Refresh',
  'language': 'Language',

  // ── login ────────────────────────────────────────────────────
  'login_claim': 'Encrypted storage\nyou can see.',
  'login_intro': 'The server keeps sealed boxes and the list of who may open '
      'them. It holds no key. This app is the client: every encryption happens '
      'here, before anything is sent.',
  'login_flow_plain': 'plaintext',
  'login_flow_plain_note': 'this device only',
  'login_flow_sealed': 'sealed',
  'login_flow_sealed_note': 'bound to project · domain · row · owner · version',
  'login_flow_wire': 'box + wraps',
  'login_flow_wire_note': 'what leaves the device',
  'login_flow_server': 'server',
  'login_flow_server_note': 'stores, authorises, never opens',
  'sign_in': 'Sign in',
  'login_help': 'Each person keeps their own vault on this machine. Pick one — '
      'the passphrase is the only thing that opens it.',
  'passphrase': 'Passphrase',
  'unlock': 'Unlock {name}’s vault',
  'unlocking': 'Opening…',
  'create_identity': 'Create identity',
  'create_off': 'First time on this device? Create the identity',
  'create_on': 'This device already has an envelope — just unlock',
  'kdf_note': 'Argon2id · 64 MiB · 3 passes — about 0.75 s, on purpose',
  'role_ali': 'owns the vault, sends and publishes',
  'role_sara': 'the invited reader',
  'role_mona': 'the member who is removed',

  // ── shared ───────────────────────────────────────────────────
  'cancel': 'Cancel',
  'add': 'Add',
  'create': 'Create',
  'close': 'Close',
  'show': 'Show',
  'hide': 'Hide',
  'show_json': 'Show JSON',
  'owner': 'owner',
  'readers': 'readers',
  'metadata': 'row',
  'wraps': 'wraps',
  'version': 'version',
  'updated': 'updated',
  'ciphertext': 'ciphertext',
  'chars': '{n} chars',
  'v': 'v{n}',
  'copy': 'copy',
  'nothing_here': 'nothing here',

  // ── vault ────────────────────────────────────────────────────
  'identity': 'Identity',
  'user': 'user',
  'device': 'device',
  'fingerprint': 'fingerprint',
  'identity_note': 'This device holds two key pairs: X25519 for key agreement '
      'and Ed25519 for signatures. Only the public halves ever reached the '
      'server.',
  'vault_key': 'Vault key',
  'vk': 'key',
  'derivation': 'derivation',
  'derivation_value': 'Argon2id (t=3, m=64 MiB, p=4) → KEK',
  'wrapped_by': 'wrapped by',
  'wrapped_by_value': 'AES-256-GCM, AAD = device id',
  'vault_key_note': 'This key never leaves the process. The server keeps the '
      'envelope beside it, never the key.',
  'change': 'Change',
  'devices': 'Devices',
  'this_one': 'this one',
  'add_device': 'Add a device',
  'add_device_short': 'Add',
  'add_device_note': 'A new envelope around the same vault key. Nothing is '
      're-encrypted, and this device keeps its own Argon2id salt.',
  'device_name': 'Device name',
  'device_added': 'Device “{name}” now holds its own envelope for the same key.',
  'change_passphrase': 'Change passphrase',
  'change_passphrase_note': 'The vault key is wrapped again under the new '
      'passphrase. Not one content key, not one ciphertext, is touched.',
  'current': 'Current',
  'new': 'New',
  'rewrap': 'Wrap again',
  'passphrase_changed': 'Passphrase changed. The vault key is byte-identical.',
  'server_holds': 'What the server holds for this device',
  'server_holds_note': 'A salt, a nonce, and a wrapped vault key. Three fields '
      'that are useless without the passphrase — and the passphrase is never '
      'sent.',
  'no_envelope': 'no envelope on this device',
  'you': 'you',

  // ── messages ─────────────────────────────────────────────────
  'inbox': 'Inbox',
  'domain_health': 'health',
  'new_message': 'New',
  'compose_title': 'HOSN · one recipient',
  'compose_note': 'The content key is written twice: once for you, under the '
      'vault key, and once for the recipient, under X25519. The server sees two '
      'sealed boxes and a list of names.',
  'to': 'To',
  'message': 'Message',
  'encrypt_send': 'Seal and send',
  'open_a_row': 'Open a row',
  'open_hint': 'The server hands over a sealed box. The key is derived here, '
      'not there.',
  'opened_locally': 'opened here',
  'refused': 'refused',
  'plaintext': 'Plaintext, recovered on this device',
  'as_stored': 'The same row, as the server stores it',
  'empty_inbox': 'No row this user may read. Seal one, or sign in as the '
      'recipient.',
  'from_to': '{from} → {to}',

  // ── group ────────────────────────────────────────────────────
  'group': 'Group',
  'epoch': 'epoch',
  'members': 'Members',
  'no_group': 'No group state on this device.\nOnly the creator holds the '
      'epoch key.',
  'create_group': 'Create group',
  'new_group': 'New group',
  'new_group_note': 'The epoch key is wrapped once per member. Removing someone '
      'advances the epoch and replaces the key.',
  'seal_post': 'Seal and post',
  'post_to_epoch': 'Post to epoch {n}',
  'timeline': 'Timeline',
  'readers_n': '{n} readers',
  'member_note': 'Only the owner holds the epoch key on this device. Members '
      'read what was wrapped for them.',
  'removal_title': 'Removal is not erasure',
  'removal_note': 'When a member is removed the epoch advances and a fresh key '
      'is generated. Everything sealed after that point is beyond their reach. '
      'Everything sealed before it is still theirs — they held the key when it '
      'was written. An implementation that hides this is lying about what it '
      'can promise.',
  'group_created': 'Group created at epoch {n}.',
  'group_posted': 'Sealed with the epoch {n} key · {w} wraps.',
  'member_removed': '{user} removed → epoch {n}. The key was replaced: the past '
      'stays readable, the future does not.',
  'member_added': '{user} added → epoch {n}.',
  'mona_empty': 'Mona sees nothing after the rotation.\nThe rows still exist; '
      'she is not in their wraps.',
  'no_messages': 'No group messages yet.',
  'add_member': '+ {user}',

  // ── public ───────────────────────────────────────────────────
  'public': 'Public',
  'domain_blog': 'blog',
  'publish': 'Publish',
  'publish_note': 'JAHR is the one engine where the text is not secret — it is '
      'public by design. What is protected is authorship.',
  'nothing_published': 'Nothing published yet.',
  'publish_title': 'Publish publicly',
  'publish_dialog_note': 'Zero wraps. The bytes are stored as they are, and an '
      'Ed25519 signature binds them to this identity, this project, this domain '
      'and this row id.',
  'content': 'Content',
  'sign_publish': 'Sign and publish',
  'verify': 'Verify',
  'read_anonymous': 'Read as a visitor',
  'read_anonymous_title': 'Anonymous read · {id}',
  'verified_directory': 'verified · directory',
  'unknown_signer': 'unknown signer',
  'bad_signature': 'bad signature',
  'trap': 'The trap',
  'trap_note': 'An attacker publishes in your name and signs with his own key — '
      'and helpfully ships that key with the payload. Verification that reads '
      'the key from the payload says yes.',
  'run_experiment': 'Run the forgery experiment',
  'key_from_payload': 'key from the payload',
  'key_from_directory': 'key from the directory',
  'must_reject': 'must be rejected',
  'blocked': 'blocked',
  'accepted': 'accepted',
  'trap_conclusion': 'The forgery only survives against a key the attacker '
      'supplied. The directory is what makes it fail.',
  'trap_broken': 'Something is wrong: the directory accepted a forgery.',
  'trap_footnote': 'This is why spec/SPEC.md §7 forbids taking a public key '
      'from the payload being verified. A verifier that does is not verifying '
      'anything.',
  'published': 'Published {id} · 0 wraps · 1 signature.',

  // ── operator ─────────────────────────────────────────────────
  'stats_identities': 'identities',
  'stats_resources': 'rows',
  'stats_wraps': 'wraps',
  'stats_domains': 'domains',
  'stats_audit': 'audit entries',
  'rows_in_db': 'Rows in the database',
  'empty': '— empty —',
  'signed': 'signed',
  'sealed': 'sealed',
  'wire_view': 'Row, as stored',
  'wire_hint': 'Select a row.\nThis is all the operator can read.',
  'audit': 'Audit',
  'the_point': 'The point',
  'the_point_note': 'Everything above is metadata: who owns a row, who may read '
      'it, when, how large. The ciphertext column is the only thing that '
      'matters, and no endpoint returns it to a user who is not in its wraps. '
      'There is no admin route that decrypts, because there is no key to '
      'decrypt with.',

  // ── errors ───────────────────────────────────────────────────
  'err_forbidden': '403 · the server found the row, but this user is not in its '
      'wraps',
  'err_not_found': '404 · no such row',
  'err_version_conflict': '409 · someone wrote a newer version',
  'err_data_poisoning': '422 · this domain is locked to another clearance',
  'err_not_owner': '403 · only the owner may write this row',
  'err_key_conflict': '409 · this name is registered with different keys. Run '
      'server/reset.sh and delete ~/.sycore/app, then sign in again.',
  'err_unauthenticated': '401 · the request carried no user header',
  'err_invalid_envelope': '422 · the server refused the shape of the envelope',
  'err_api': '{status} · {code}',
  'err_wrong_password': 'Wrong passphrase for this device.',
  'err_no_device': 'This device holds no envelope for that account.',
  'err_identity_mismatch': 'The server holds different public keys for this '
      'name. Run server/reset.sh.',
  'err_locked': 'Locked — sign in first.',
  'err_unknown_group': 'No local state for that group on this device.',
  'err_crypto': 'Refused on this device: {code}',
  'err_offline': 'Cannot reach the server at {url} — is server/run.sh running?',
};

const _ar = <String, String>{
  // ── shell ────────────────────────────────────────────────────
  'app_name': 'سايكور',
  'app_tagline': 'تخزين مشفّر تراه بعينك',
  'nav_vault': 'الخزنة',
  'nav_messages': 'الرسائل',
  'nav_group': 'المجموعة',
  'nav_public': 'العلني',
  'nav_operator': 'المشغّل',
  'nav_blurb_vault': 'مفتاح واحد، أجهزة متعددة، بلا إعادة تشفير',
  'nav_blurb_messages': 'HOSN · قارئان: أنت وشخص واحد',
  'nav_blurb_group': 'SAMAM · مفتاح جديد كلّما تغيّر الأعضاء',
  'nav_blurb_public': 'JAHR · نصّ علني، ونسب موقّع',
  'nav_blurb_operator': 'ما يستطيع الخادم رؤيته فعلاً',
  'server_up': 'الخادم متاح',
  'server_down': 'الخادم متوقف',
  'server_reachable': 'الخادم {url} · متاح',
  'server_unreachable': 'الخادم {url} · لا يستجيب — شغّل server/run.sh',
  'lock_vault': 'إغلاق الخزنة',
  'project': 'المشروع {id}',
  'fingerprint_short': 'البصمة {f}',
  'build': 'الإصدار 0.1.0 · الصيغة v1',
  'refresh': 'تحديث',
  'language': 'اللغة',

  // ── login ────────────────────────────────────────────────────
  'login_claim': 'تخزين مشفّر\nتراه بعينك.',
  'login_intro': 'يحتفظ الخادم بصناديق مقفولة وقائمة بمن يملك فتحها، ولا يحمل '
      'أي مفتاح. هذا التطبيق هو العميل: كل تشفير يحدث هنا، قبل أن يخرج شيء.',
  'login_flow_plain': 'النص الأصلي',
  'login_flow_plain_note': 'على هذا الجهاز وحده',
  'login_flow_sealed': 'مقفول',
  'login_flow_sealed_note': 'مربوط بالمشروع · المجال · الصف · المالك · الإصدار',
  'login_flow_wire': 'صندوق ولفّات',
  'login_flow_wire_note': 'ما يخرج من الجهاز',
  'login_flow_server': 'الخادم',
  'login_flow_server_note': 'يخزّن، يصرّح، ولا يفتح',
  'sign_in': 'الدخول',
  'login_help': 'لكل شخص خزنته على هذا الجهاز. اختر واحداً — عبارة المرور وحدها '
      'هي ما يفتحها.',
  'passphrase': 'عبارة المرور',
  'unlock': 'افتح خزنة {name}',
  'unlocking': 'جارٍ الفتح…',
  'create_identity': 'إنشاء هوية',
  'create_off': 'أول مرة على هذا الجهاز؟ أنشئ الهوية',
  'create_on': 'هذا الجهاز يملك ظرفاً بالفعل — افتح فقط',
  'kdf_note': 'Argon2id · 64 ميبي · 3 دورات — نحو 0.75 ثانية، عن قصد',
  'role_ali': 'يملك الخزنة، يرسل وينشر',
  'role_sara': 'القارئة المدعوّة',
  'role_mona': 'العضوة التي تُسحب',

  // ── shared ───────────────────────────────────────────────────
  'cancel': 'إلغاء',
  'add': 'إضافة',
  'create': 'إنشاء',
  'close': 'إغلاق',
  'show': 'إظهار',
  'hide': 'إخفاء',
  'show_json': 'إظهار JSON',
  'owner': 'المالك',
  'readers': 'القرّاء',
  'metadata': 'الصف',
  'wraps': 'اللفّات',
  'version': 'الإصدار',
  'updated': 'آخر تحديث',
  'ciphertext': 'النص المشفّر',
  'chars': '{n} حرفاً',
  'v': 'v{n}',
  'copy': 'نسخ',
  'nothing_here': 'لا شيء هنا',

  // ── vault ────────────────────────────────────────────────────
  'identity': 'الهوية',
  'user': 'المستخدم',
  'device': 'الجهاز',
  'fingerprint': 'البصمة',
  'identity_note': 'يحمل هذا الجهاز زوجي مفاتيح: X25519 لتبادل المفاتيح، '
      'وEd25519 للتوقيع. النصفان العلنيان وحدهما وصلا إلى الخادم.',
  'vault_key': 'مفتاح الخزنة',
  'vk': 'المفتاح',
  'derivation': 'الاشتقاق',
  'derivation_value': 'Argon2id (t=3, m=64 MiB, p=4) → KEK',
  'wrapped_by': 'ملفوف بـ',
  'wrapped_by_value': 'AES-256-GCM، والـ AAD هو معرّف الجهاز',
  'vault_key_note': 'هذا المفتاح لا يغادر العملية. الخادم يحفظ الظرف إلى جانبه، '
      'ولا يحفظ المفتاح.',
  'change': 'تغيير',
  'devices': 'الأجهزة',
  'this_one': 'هذا',
  'add_device': 'إضافة جهاز',
  'add_device_short': 'إضافة',
  'add_device_note': 'ظرف جديد حول نفس مفتاح الخزنة. لا يُعاد تشفير أي شيء، '
      'ولكل جهاز ملح Argon2id خاص به.',
  'device_name': 'اسم الجهاز',
  'device_added': 'الجهاز «{name}» يحمل الآن ظرفه الخاص لنفس المفتاح.',
  'change_passphrase': 'تغيير عبارة المرور',
  'change_passphrase_note': 'يُعاد لفّ مفتاح الخزنة تحت عبارة المرور الجديدة. '
      'لا يُمسّ مفتاح محتوى واحد، ولا نصّ مشفّر واحد.',
  'current': 'الحالية',
  'new': 'الجديدة',
  'rewrap': 'أعد اللفّ',
  'passphrase_changed': 'تغيّرت عبارة المرور. مفتاح الخزنة لم يتغيّر بايتاً واحداً.',
  'server_holds': 'ما يحتفظ به الخادم لهذا الجهاز',
  'server_holds_note': 'ملح، ورقم يُستعمل مرة واحدة (nonce)، ومفتاح خزنة ملفوف. '
      'ثلاثة حقول لا تنفع بدون عبارة المرور — وعبارة المرور لا تُرسل أبداً.',
  'no_envelope': 'لا ظرف على هذا الجهاز',
  'you': 'أنت',

  // ── messages ─────────────────────────────────────────────────
  'inbox': 'الوارد',
  'domain_health': 'الصحة',
  'new_message': 'جديد',
  'compose_title': 'HOSN · مستلم واحد',
  'compose_note': 'يُكتب مفتاح المحتوى مرّتين: مرة لك تحت مفتاح الخزنة، ومرة '
      'للمستلم بـ X25519. الخادم يرى صندوقين مقفولين وقائمة أسماء.',
  'to': 'إلى',
  'message': 'الرسالة',
  'encrypt_send': 'اقفل وأرسل',
  'open_a_row': 'افتح صفاً',
  'open_hint': 'الخادم يسلّم صندوقاً مقفولاً. المفتاح يُشتقّ هنا، لا هناك.',
  'opened_locally': 'فُتح هنا',
  'refused': 'مرفوض',
  'plaintext': 'النص الأصلي، مُستعاد على هذا الجهاز',
  'as_stored': 'نفس الصف كما يخزّنه الخادم',
  'empty_inbox': 'لا صفّ يقرؤه هذا المستخدم. اقفل واحداً، أو ادخل باسم المستلم.',
  'from_to': '{from} ← {to}',

  // ── group ────────────────────────────────────────────────────
  'group': 'المجموعة',
  'epoch': 'الحقبة',
  'members': 'الأعضاء',
  'no_group': 'لا حالة مجموعة على هذا الجهاز.\nالمنشئ وحده يحمل مفتاح الحقبة.',
  'create_group': 'إنشاء مجموعة',
  'new_group': 'مجموعة جديدة',
  'new_group_note': 'مفتاح الحقبة يُلفّ مرة لكل عضو. سحب عضو يرفع الحقبة '
      'ويستبدل المفتاح.',
  'seal_post': 'اقفل وانشر',
  'post_to_epoch': 'انشر في الحقبة {n}',
  'timeline': 'الخط الزمني',
  'readers_n': '{n} قرّاء',
  'member_note': 'المالك وحده يحمل مفتاح الحقبة على هذا الجهاز. الأعضاء يقرؤون '
      'ما لُفّ لهم.',
  'removal_title': 'سحب العضو ليس محواً',
  'removal_note': 'حين يُسحب عضو تتقدّم الحقبة ويُولَّد مفتاح جديد. كل ما لُفّ '
      'بعد ذلك خارج متناوله. وكل ما لُفّ قبله ما زال له — كان يملك المفتاح حين '
      'كُتب. أي تنفيذ يخفي هذا يكذب بشأن ما يستطيع أن يعد به.',
  'group_created': 'أُنشئت المجموعة في الحقبة {n}.',
  'group_posted': 'لُفّت بمفتاح الحقبة {n} · {w} لفّات.',
  'member_removed': 'سُحب {user} → الحقبة {n}. استُبدل المفتاح: الماضي يبقى '
      'مقروءاً، والمستقبل لا.',
  'member_added': 'أُضيف {user} → الحقبة {n}.',
  'mona_empty': 'منى لا ترى شيئاً بعد الدوران.\nالصفوف موجودة، لكنها ليست في '
      'لفّاتها.',
  'no_messages': 'لا رسائل في المجموعة بعد.',
  'add_member': '+ {user}',

  // ── public ───────────────────────────────────────────────────
  'public': 'العلني',
  'domain_blog': 'المدوّنة',
  'publish': 'انشر',
  'publish_note': 'JAHR هو المحرّك الوحيد الذي لا يكون النصّ فيه سرّاً — هو علني '
      'بالتصميم. المحميّ هو نِسبة النصّ إلى صاحبه.',
  'nothing_published': 'لم يُنشر شيء بعد.',
  'publish_title': 'انشر علناً',
  'publish_dialog_note': 'صفر لفّات. البايتات تُخزَّن كما هي، وتوقيع Ed25519 '
      'يربطها بهذه الهوية وهذا المشروع وهذا المجال وهذا المعرّف.',
  'content': 'المحتوى',
  'sign_publish': 'وقّع وانشر',
  'verify': 'تحقّق',
  'read_anonymous': 'اقرأ كزائر',
  'read_anonymous_title': 'قراءة مجهولة · {id}',
  'verified_directory': 'موثّق · الدليل',
  'unknown_signer': 'مُوقّع مجهول',
  'bad_signature': 'توقيع فاسد',
  'trap': 'الفخّ',
  'trap_note': 'مهاجم ينشر باسمك ويوقّع بمفتاحه، ويُرفق مفتاحه مع الحمولة. '
      'التحقّق الذي يقرأ المفتاح من الحمولة يقول: نعم.',
  'run_experiment': 'شغّل تجربة التزوير',
  'key_from_payload': 'المفتاح من الحمولة',
  'key_from_directory': 'المفتاح من الدليل',
  'must_reject': 'يجب أن يُرفض',
  'blocked': 'مُحيَّد',
  'accepted': 'مقبول',
  'trap_conclusion': 'التزوير ينجح فقط أمام مفتاح قدّمه المهاجم. الدليل هو ما '
      'يجعله يفشل.',
  'trap_broken': 'هناك خطأ: الدليل قَبِل تزويراً.',
  'trap_footnote': 'لهذا تمنع المواصفة (SPEC §7) أخذ مفتاح علني من الحمولة التي '
      'تُتحقَّق. من يفعل ذلك لا يتحقّق من شيء.',
  'published': 'نُشر {id} · صفر لفّات · توقيع واحد.',

  // ── operator ─────────────────────────────────────────────────
  'stats_identities': 'الهويات',
  'stats_resources': 'الصفوف',
  'stats_wraps': 'اللفّات',
  'stats_domains': 'المجالات',
  'stats_audit': 'سجل التدقيق',
  'rows_in_db': 'الصفوف في قاعدة البيانات',
  'empty': '— فارغ —',
  'signed': 'موقّع',
  'sealed': 'مقفول',
  'wire_view': 'الصف كما يُخزَّن',
  'wire_hint': 'اختر صفاً.\nهذا كل ما يستطيع المشغّل قراءته.',
  'audit': 'سجل التدقيق',
  'the_point': 'الخلاصة',
  'the_point_note': 'كل ما فوق بيانات وصفية: من يملك الصف، ومن يقرؤه، ومتى، '
      'وحجمه. عمود النص المشفّر هو الشيء الوحيد المهم، ولا نقطة نهاية تعيده '
      'لمستخدم ليس في لفّاته. ولا مسار إداري يفكّ التشفير، لأنه لا مفتاح ليُفكّ به.',

  // ── errors ───────────────────────────────────────────────────
  'err_forbidden': '403 · الخادم وجد الصف، لكن هذا المستخدم ليس في لفّاته',
  'err_not_found': '404 · لا صفّ بهذا المعرّف',
  'err_version_conflict': '409 · كتب أحدهم إصداراً أحدث',
  'err_data_poisoning': '422 · هذا المجال مقفول على تصنيف آخر',
  'err_not_owner': '403 · المالك وحده يكتب هذا الصف',
  'err_key_conflict': '409 · هذا الاسم مسجّل بمفاتيح أخرى. شغّل server/reset.sh '
      'واحذف ~/.sycore/app ثم ادخل من جديد.',
  'err_unauthenticated': '401 · الطلب لم يحمل ترويسة مستخدم',
  'err_invalid_envelope': '422 · الخادم رفض شكل الظرف',
  'err_api': '{status} · {code}',
  'err_wrong_password': 'عبارة مرور خاطئة لهذا الجهاز.',
  'err_no_device': 'هذا الجهاز لا يحمل ظرفاً لهذا الحساب.',
  'err_identity_mismatch': 'الخادم يحمل مفاتيح علنية أخرى لهذا الاسم. شغّل '
      'server/reset.sh.',
  'err_locked': 'مقفل — ادخل أولاً.',
  'err_unknown_group': 'لا حالة محلية لهذه المجموعة على هذا الجهاز.',
  'err_crypto': 'رُفض على هذا الجهاز: {code}',
  'err_offline': 'لا يمكن الوصول إلى الخادم {url} — هل server/run.sh يعمل؟',
};
