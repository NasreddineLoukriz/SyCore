/// SYCORE client — the SDK.
///
/// One object, one server, four features. Everything that touches a key happens
/// in this process; the server only ever sees the sealed result.
///
/// ```dart
/// final sycore = SyCore(server: Uri.parse('http://127.0.0.1:8787'));
///
/// await sycore.register(userId: 'usr_ali', password: 'correct horse');
/// await sycore.hosn.send(to: 'usr_sara', project: 'prj', domain: 'health',
///                        text: 'Surgery at 8:30');
///
/// for (final row in await sycore.hosn.inbox(project: 'prj', domain: 'health')) {
///   print(await sycore.hosn.open(row.id));
/// }
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sycore_core/sycore_core.dart' as core;

import 'api.dart';
import 'local_store.dart';

export 'api.dart' show Api, SycoreApiException;
export 'local_store.dart' show FileVaultStore, MemoryVaultStore, VaultStore;

/// A client-side refusal: no account, locked vault, unknown group, bad input.
class SycoreException implements Exception {
  const SycoreException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'SycoreException($code${message == null ? '' : ': $message'})';
}

/// Metadata the server is allowed to know about a row.
class ResourceMeta {
  const ResourceMeta({
    required this.id,
    required this.projectId,
    required this.domain,
    required this.ownerId,
    required this.version,
    required this.readers,
    required this.ciphertextChars,
    required this.signed,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String domain;
  final String ownerId;
  final int version;

  /// User ids named in `wraps`. Not the content — the readership.
  final List<String> readers;
  final int ciphertextChars;
  final bool signed;
  final String updatedAt;

  factory ResourceMeta.fromJson(Map<String, dynamic> j) => ResourceMeta(
        id: j['id'] as String,
        projectId: j['project_id'] as String,
        domain: j['domain'] as String,
        ownerId: j['owner_id'] as String,
        version: j['version'] as int,
        readers: (j['readers'] as List).cast<String>(),
        ciphertextChars: j['ciphertext_chars'] as int,
        signed: j['signed'] as bool,
        updatedAt: j['updated_at'] as String,
      );

  bool readableBy(String user) => ownerId == user || readers.contains(user);
}

/// The outcome of checking a JAHR post against the trusted directory.
class JahrCheck {
  const JahrCheck({
    required this.verified,
    required this.signer,
    required this.reason,
  });

  final bool verified;
  final String signer;

  /// `ok`, `unknown_signer`, `bad_signature`, `not_public`.
  final String reason;
}

/// A SAMAM group as this device remembers it.
class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.projectId,
    required this.domain,
    required this.epoch,
    required this.members,
  });

  final String id;
  final String projectId;
  final String domain;
  final int epoch;

  /// member id → X25519 public key (base64url).
  final Map<String, String> members;

  List<String> get memberIds => members.keys.toList()..sort();

  GroupInfo copyWith({int? epoch, Map<String, String>? members}) => GroupInfo(
        id: id,
        projectId: projectId,
        domain: domain,
        epoch: epoch ?? this.epoch,
        members: members ?? this.members,
      );
}

/// An unlocked session on one device.
class Account {
  Account({
    required this.userId,
    required this.deviceId,
    required this.identity,
    required this.vault,
    required this.vaultKey,
    required this.seed,
    required this.fingerprint,
  });

  final String userId;
  final String deviceId;
  final core.Identity identity;
  final core.Vault vault;
  final Uint8List vaultKey;
  final Uint8List seed;
  final String fingerprint;

  int get identitySeedLength => seed.length;
}

// ───────────────────────────────────────────────────────────────────

/// The SDK entry point.
class SyCore {
  SyCore({
    required Uri server,
    VaultStore? store,
    String namespace = 'default',
  })  : _api = Api(server),
        _store = store ?? FileVaultStore(namespace: namespace);

  final Api _api;
  final VaultStore _store;

  Account? _account;

  /// The unlocked account, or `null`.
  Account? get me => _account;

  Account _require() {
    final a = _account;
    if (a == null) {
      throw const SycoreException('locked', 'register() or login() first');
    }
    return a;
  }

  // ── account lifecycle ─────────────────────────────────────────

  /// Create an identity, a vault key, and this device's envelope — then publish
  /// the two public keys. The password never leaves this machine.
  Future<Account> register({
    required String userId,
    required String password,
    String deviceId = 'laptop',
  }) async {
    if (await _store.read(_accountKey(userId, deviceId)) != null) {
      throw SycoreException('device_exists', '$userId@$deviceId already has a vault');
    }

    final seed = core.randomBytes(32);
    final identity = await core.Identity.create(userId, seed: seed);
    final vaultKey = core.randomBytes(32);
    final vault = await core.Vault.create(
      password: password,
      deviceId: deviceId,
      vk: vaultKey,
    );

    await _publishIdentity(identity);

    _account = Account(
      userId: userId,
      deviceId: deviceId,
      identity: identity,
      vault: vault,
      vaultKey: vaultKey,
      seed: seed,
      fingerprint: await identity.fingerprint(),
    );
    await _saveDevice(_account!);
    return _account!;
  }

  /// Unlock this device's envelope and recover the identity.
  Future<Account> login({
    required String userId,
    required String password,
    String deviceId = 'laptop',
  }) async {
    final record = await _store.read(_accountKey(userId, deviceId));
    if (record == null) {
      throw SycoreException(
        'no_device_envelope',
        'no vault for $userId@$deviceId on this machine',
      );
    }

    final vault = _vaultFrom(record);
    final Uint8List vaultKey;
    try {
      vaultKey = await vault.unlock(password);
    } on core.SycoreCryptoException {
      throw const SycoreException('wrong_password');
    }

    final seed = await _openLocal(
      record['identity_seed'] as Map<String, dynamic>,
      vaultKey,
      _localAad(userId, 'identity'),
    );
    final identity = await core.Identity.create(userId, seed: seed);

    // The directory is the source of truth for public keys. If the server has
    // never seen this identity (fresh database), publish; if it disagrees,
    // refuse — a server must not be able to swap keys silently.
    final remote = await _tryDirectory(userId);
    if (remote == null) {
      await _publishIdentity(identity);
    } else if (remote.$1 != core.b64u(await identity.dhPublic()) ||
        remote.$2 != core.b64u(await identity.signingPublic())) {
      throw const SycoreException(
        'identity_mismatch',
        'the server holds different public keys for this user',
      );
    }

    _account = Account(
      userId: userId,
      deviceId: deviceId,
      identity: identity,
      vault: vault,
      vaultKey: vaultKey,
      seed: seed,
      fingerprint: await identity.fingerprint(),
    );
    return _account!;
  }

  void logout() => _account = null;

  /// Every device that has an envelope for this account on this machine.
  Future<List<String>> devices({String? userId}) async {
    final user = userId ?? _require().userId;
    final keys = await _store.keys('accounts/$user@');
    return [
      for (final k in keys) k.substring(k.indexOf('@') + 1),
    ];
  }

  /// Add a second device: a new envelope around the *same* vault key.
  ///
  /// No content is re-encrypted, and this device's key is not copied — the new
  /// device gets its own Argon2id salt and its own wrapped VK.
  Future<void> addDevice({
    required String deviceId,
    required String password,
  }) async {
    final a = _require();
    final vault = await core.Vault.create(
      password: password,
      deviceId: deviceId,
      vk: a.vaultKey,
    );
    final record = await DeviceRecord.build(
      userId: a.userId,
      deviceId: deviceId,
      vault: vault,
      seed: a.seed,
      vaultKey: a.vaultKey,
    );
    await _store.write(_accountKey(a.userId, deviceId), record);
  }

  /// Re-wrap the vault key under a new password. Content keys are untouched.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final a = _require();
    final rotated = await a.vault.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    final record = await _store.read(_accountKey(a.userId, a.deviceId));
    if (record == null) throw const SycoreException('no_device_envelope');
    record['vault'] = rotated.toJson();
    await _store.write(_accountKey(a.userId, a.deviceId), record);
    _account = Account(
      userId: a.userId,
      deviceId: a.deviceId,
      identity: a.identity,
      vault: rotated,
      vaultKey: a.vaultKey,
      seed: a.seed,
      fingerprint: a.fingerprint,
    );
  }

  // ── features ──────────────────────────────────────────────────

  late final VaultFeature vault = VaultFeature._(this);
  late final HosnFeature hosn = HosnFeature._(this);
  late final SamamFeature samam = SamamFeature._(this);
  late final JahrFeature jahr = JahrFeature._(this);
  late final OperatorFeature operator = OperatorFeature._(this);

  void close() => _api.close();

  // ── internals ─────────────────────────────────────────────────

  String _accountKey(String user, String device) => 'accounts/$user@$device';

  core.Vault _vaultFrom(Map<String, dynamic> record) {
    final v = record['vault'] as Map<String, dynamic>;
    final kdf = v['kdf'] as Map<String, dynamic>;
    return core.Vault(
      deviceId: v['device_id'] as String,
      salt: core.unb64u(kdf['salt'] as String),
      nonce: core.unb64u(v['nonce'] as String),
      wrappedVk: core.unb64u(v['wrapped_vk'] as String),
    );
  }

  Future<void> _saveDevice(Account a) async {
    final record = await DeviceRecord.build(
      userId: a.userId,
      deviceId: a.deviceId,
      vault: a.vault,
      seed: a.seed,
      vaultKey: a.vaultKey,
    );
    await _store.write(_accountKey(a.userId, a.deviceId), record);
  }

  Future<void> _publishIdentity(core.Identity identity) async {
    try {
      await _api.postJson('/v1/identities', body: {
        'user_id': identity.id,
        'dh_pub': core.b64u(await identity.dhPublic()),
        'sign_pub': core.b64u(await identity.signingPublic()),
      });
    } on SycoreApiException catch (e) {
      if (e.code == 'key_conflict') {
        throw SycoreException(
          'identity_mismatch',
          '${identity.id} is already registered with different keys',
        );
      }
      rethrow;
    }
  }

  Future<(String, String)?> _tryDirectory(String userId) async {
    try {
      final j = await _api.getJson('/v1/identities/$userId');
      return (j['dh_pub'] as String, j['sign_pub'] as String);
    } on SycoreApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The trusted public key of a user, as published in the directory.
  Future<core.Recipient> _recipient(String userId) async {
    final j = await _api.getJson('/v1/identities/$userId');
    return core.Recipient(userId, core.unb64u(j['dh_pub'] as String));
  }

  Future<Uint8List> _openLocal(
    Map<String, dynamic> sealed,
    Uint8List key,
    Uint8List aad,
  ) =>
      core.aeadOpen(
        key: key,
        sealed: core.unb64u(sealed['ct'] as String),
        aad: aad,
        nonce: core.unb64u(sealed['nonce'] as String),
      );

  Future<Map<String, dynamic>> _sealLocal(
    List<int> plain,
    Uint8List key,
    Uint8List aad,
  ) async {
    final nonce = core.randomBytes(12);
    final ct = await core.aeadSeal(
      key: key,
      plain: Uint8List.fromList(plain),
      aad: aad,
      nonce: nonce,
    );
    return {'nonce': core.b64u(nonce), 'ct': core.b64u(ct)};
  }

  Uint8List _localAad(String user, String kind) =>
      core.utf8b('sycore/v1|local|$user|$kind');

  String _newId(String prefix) =>
      '${prefix}_${core.b64u(core.randomBytes(9)).replaceAll('-', 'x').replaceAll('_', 'y')}';
}

/// Small helper so the file layout stays in one place.
abstract final class DeviceRecord {
  static Future<Map<String, dynamic>> build({
    required String userId,
    required String deviceId,
    required core.Vault vault,
    required Uint8List seed,
    required Uint8List vaultKey,
  }) async {
    final nonce = core.randomBytes(12);
    final ct = await core.aeadSeal(
      key: vaultKey,
      plain: seed,
      aad: core.utf8b('sycore/v1|local|$userId|identity'),
      nonce: nonce,
    );
    return {
      'v': 1,
      'user_id': userId,
      'device_id': deviceId,
      'vault': vault.toJson(),
      'identity_seed': {'nonce': core.b64u(nonce), 'ct': core.b64u(ct)},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

// ───────────────────────────────────────────── feature: vault

/// What this device can say about itself.
class VaultFeature {
  VaultFeature._(this._s);

  final SyCore _s;

  /// What the server stores for this device: one envelope, no key.
  Map<String, Object> get envelope => _s._require().vault.toJson();

  /// Short fingerprint of the signing key — the thing a human compares.
  String get fingerprint => _s._require().fingerprint;

  /// The vault key, for display only. It never leaves the process.
  String get vaultKeyPreview => _short(_s._require().vaultKey);

  Future<List<String>> devices() => _s.devices();

  /// Add a second device: a new envelope, the same vault key, no re-encryption.
  Future<void> addDevice(String deviceId, String password) =>
      _s.addDevice(deviceId: deviceId, password: password);

  Future<void> changePassword(String oldPassword, String newPassword) =>
      _s.changePassword(oldPassword: oldPassword, newPassword: newPassword);
}

// ───────────────────────────────────────────── feature: HOSN

/// Two readers: the owner and one recipient.
class HosnFeature {
  HosnFeature._(this._s);

  final SyCore _s;

  /// Encrypt for exactly one other person.
  Future<core.Envelope> send({
    required String to,
    required String project,
    required String domain,
    required String text,
    String? resourceId,
  }) async {
    final a = _s._require();
    final recipient = await _s._recipient(to);
    final env = await core.seal(
      projectId: project,
      domain: domain,
      resourceId: resourceId ?? _s._newId('res'),
      ownerId: a.userId,
      vaultKey: a.vaultKey,
      owner: a.identity,
      plaintext: core.utf8b(text),
      recipients: [recipient],
    );
    await _s._api.postJson(
      '/v1/resources',
      as: a.userId,
      body: {'clearance': 'E2EE', 'envelope': env.toJson()},
    );
    return env;
  }

  /// Rows in a domain that this user may read — metadata only.
  Future<List<ResourceMeta>> inbox({
    required String project,
    required String domain,
  }) async {
    final a = _s._require();
    final j = await _s._api.getJson(
      '/v1/resources',
      as: a.userId,
      query: {'project_id': project, 'domain': domain},
    );
    return (j['resources'] as List)
        .map((e) => ResourceMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch and decrypt one row, as owner or as recipient.
  Future<String> open(String resourceId) async {
    final a = _s._require();
    final env = await _fetch(resourceId);
    final Uint8List clear;
    if (env.ownerId == a.userId) {
      clear = await core.openAsOwner(env, a.vaultKey);
    } else {
      clear = await core.openAsRecipient(env, a.identity);
    }
    return utf8.decode(clear);
  }

  /// Fetch the sealed envelope without opening it.
  Future<core.Envelope> envelopeOf(String resourceId) => _fetch(resourceId);

  Future<core.Envelope> _fetch(String resourceId) async {
    final a = _s._require();
    final j = await _s._api.getJson('/v1/resources/$resourceId', as: a.userId);
    return core.Envelope.fromJson(j);
  }
}

// ───────────────────────────────────────────── feature: SAMAM

/// A group, an epoch, and a rotation whenever the membership changes.
class SamamFeature {
  SamamFeature._(this._s);

  final SyCore _s;

  Future<GroupInfo> create({
    required String id,
    required String project,
    required String domain,
    required List<String> members,
  }) async {
    final a = _s._require();
    final keys = <String, String>{};
    for (final m in {a.userId, ...members}) {
      keys[m] = core.b64u((await _s._recipient(m)).dhPublic);
    }
    final info = GroupInfo(
      id: id,
      projectId: project,
      domain: domain,
      epoch: 1,
      members: keys,
    );
    await _save(info, core.randomBytes(32));
    return info;
  }

  Future<GroupInfo> get(String id) async {
    final a = _s._require();
    final record = await _s._store.read('groups/${a.userId}/$id');
    if (record == null) {
      throw SycoreException('unknown_group', 'no local state for group $id');
    }
    return GroupInfo(
      id: record['id'] as String,
      projectId: record['project_id'] as String,
      domain: record['domain'] as String,
      epoch: record['epoch'] as int,
      members: (record['members'] as Map).cast<String, String>(),
    );
  }

  Future<GroupInfo> addMember(String groupId, String userId) async {
    final info = await get(groupId);
    final key = core.b64u((await _s._recipient(userId)).dhPublic);
    final next = info.copyWith(
      epoch: info.epoch + 1,
      members: {...info.members, userId: key},
    );
    await _save(next, core.randomBytes(32));
    return next;
  }

  /// Remove a member and rotate: they keep the past, not the future.
  Future<GroupInfo> removeMember(String groupId, String userId) async {
    final info = await get(groupId);
    if (!info.members.containsKey(userId)) {
      throw SycoreException('not_a_member', userId);
    }
    final next = info.copyWith(
      epoch: info.epoch + 1,
      members: {...info.members}..remove(userId),
    );
    await _save(next, core.randomBytes(32));
    return next;
  }

  /// Seal one message with the current epoch key, wrapped once per reader.
  Future<core.Envelope> post({
    required String groupId,
    required String text,
    String? resourceId,
  }) async {
    final a = _s._require();
    final info = await get(groupId);
    final key = await _keyOf(info);
    final env = await core.seal(
      projectId: info.projectId,
      domain: info.domain,
      resourceId: resourceId ?? _s._newId('msg'),
      ownerId: a.userId,
      vaultKey: a.vaultKey,
      owner: a.identity,
      plaintext: core.utf8b(text),
      contentKey: key,
      recipients: [
        for (final e in info.members.entries)
          core.Recipient(e.key, core.unb64u(e.value)),
      ],
    );
    await _s._api.postJson(
      '/v1/resources',
      as: a.userId,
      body: {'clearance': 'E2EE', 'envelope': env.toJson()},
    );
    return env;
  }

  Future<List<ResourceMeta>> timeline(String groupId) async {
    final info = await get(groupId);
    final a = _s._require();
    final j = await _s._api.getJson(
      '/v1/resources',
      as: a.userId,
      query: {'project_id': info.projectId, 'domain': info.domain},
    );
    final all = (j['resources'] as List)
        .map((e) => ResourceMeta.fromJson(e as Map<String, dynamic>))
        .toList();
    // The server cannot tag rows with a group (that would be a second index it
    // must understand); the client filters by readership.
    return all.where((r) => r.readableBy(a.userId) && !r.signed).toList();
  }

  /// Open a group message; works as owner (vault wrap) or member (X25519 wrap).
  Future<String> open(String resourceId) => _s.hosn.open(resourceId);

  // ── storage ──
  Future<void> _save(GroupInfo info, Uint8List groupKey) async {
    final a = _s._require();
    final payload = core.utf8b(jsonEncode({
      'id': info.id,
      'project_id': info.projectId,
      'domain': info.domain,
      'epoch': info.epoch,
      'members': info.members,
      'group_key': core.b64u(groupKey),
    }));
    final sealed = await _s._sealLocal(
      payload,
      a.vaultKey,
      _s._localAad(a.userId, 'group/${info.id}'),
    );
    await _s._store.write('groups/${a.userId}/${info.id}', {
      ...{
        'id': info.id,
        'project_id': info.projectId,
        'domain': info.domain,
        'epoch': info.epoch,
        'members': info.members,
      },
      'key': sealed,
    });
  }

  Future<Uint8List> _keyOf(GroupInfo info) async {
    final a = _s._require();
    final record = await _s._store.read('groups/${a.userId}/${info.id}');
    if (record == null) throw SycoreException('unknown_group', info.id);
    final clear = await _s._openLocal(
      record['key'] as Map<String, dynamic>,
      a.vaultKey,
      _s._localAad(a.userId, 'group/${info.id}'),
    );
    final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    return core.unb64u(payload['group_key'] as String);
  }
}

// ───────────────────────────────────────────── feature: JAHR

/// Public, signed content. Zero wraps; everyone may read; nobody may forge.
class JahrFeature {
  JahrFeature._(this._s);

  final SyCore _s;

  Future<core.Envelope> publish({
    required String project,
    required String domain,
    required String text,
    String? resourceId,
  }) async {
    final a = _s._require();
    final env = await core.publishPublic(
      projectId: project,
      domain: domain,
      resourceId: resourceId ?? _s._newId('post'),
      ownerId: a.userId,
      owner: a.identity,
      content: core.utf8b(text),
    );
    await _s._api.postJson(
      '/v1/resources',
      as: a.userId,
      body: {'clearance': 'JAHR', 'envelope': env.toJson()},
    );
    return env;
  }

  /// Read a public post without an account: no header, no identity.
  Future<String> read(String resourceId) async {
    final j = await _s._api.getJson('/v1/resources/$resourceId');
    return utf8.decode(core.unb64u(j['ciphertext'] as String));
  }

  Future<List<ResourceMeta>> feed({
    required String project,
    required String domain,
  }) async {
    final j = await _s._api.getJson(
      '/v1/resources',
      query: {'project_id': project, 'domain': domain},
    );
    return (j['resources'] as List)
        .map((e) => ResourceMeta.fromJson(e as Map<String, dynamic>))
        .where((m) => m.signed)
        .toList();
  }

  /// Verify a post against the **directory**, never against a key carried in
  /// the payload. This is the whole defence (spec/SPEC.md §7).
  Future<JahrCheck> verify(String resourceId) async {
    final j = await _s._api.getJson('/v1/resources/$resourceId');
    final env = core.Envelope.fromJson(j);
    final content = core.unb64u(env.ciphertext);

    if (env.signature == null) {
      return JahrCheck(verified: false, signer: env.ownerId, reason: 'not_public');
    }

    final directory = core.IdentityDirectory();
    try {
      final key = await _s._api.getJson('/v1/identities/${env.ownerId}');
      directory.registerPublic(
        env.ownerId,
        core.unb64u(key['dh_pub'] as String),
        core.unb64u(key['sign_pub'] as String),
      );
    } on SycoreApiException catch (e) {
      if (e.isNotFound) {
        return JahrCheck(
            verified: false, signer: env.ownerId, reason: 'unknown_signer');
      }
      rethrow;
    }

    final ok = await core.verifyPublic(
      envelope: env,
      content: content,
      directory: directory,
    );
    return JahrCheck(
      verified: ok,
      signer: env.ownerId,
      reason: ok ? 'ok' : 'bad_signature',
    );
  }

  /// Fetch the raw row as an anonymous visitor, for showing the wire.
  Future<Map<String, dynamic>> wire(String resourceId) =>
      _s._api.getJson('/v1/resources/$resourceId');
}

// ───────────────────────────────────────────── feature: operator view

/// Exactly what someone with the database can see.
class OperatorFeature {
  OperatorFeature._(this._s);

  final SyCore _s;

  Future<Map<String, dynamic>> health() => _s._api.getJson('/health');

  Future<List<Map<String, dynamic>>> audit({int limit = 50}) async {
    final j = await _s._api.getJson('/v1/audit', query: {'limit': '$limit'});
    return (j['entries'] as List).cast<Map<String, dynamic>>();
  }

  /// Rows the API will disclose to `as` (the signed-in user, by default).
  ///
  /// The server has no admin route: the operator sees the same rows any client
  /// sees, only without the keys to open them.
  Future<List<ResourceMeta>> rows({
    required String project,
    String? domain,
    String? as,
  }) async {
    final j = await _s._api.getJson('/v1/resources', as: as ?? _s.me?.userId, query: {
      'project_id': project,
      if (domain != null) 'domain': domain,
    });
    return (j['resources'] as List)
        .map((e) => ResourceMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// What the policies table says about a domain.
  Future<String?> policy(String project, String domain) async {
    final j = await _s._api.getJson(
      '/v1/resources',
      query: {'project_id': project, 'domain': domain},
    );
    return j['policy'] as String?;
  }
}

// ───────────────────────────────────────────── small helpers

/// `abcd…wxyz` — never print a whole key on a screen.
String _short(List<int> bytes, [int n = 6]) {
  final s = core.b64u(bytes);
  return s.length <= n * 2 ? s : '${s.substring(0, n)}…${s.substring(s.length - n)}';
}
