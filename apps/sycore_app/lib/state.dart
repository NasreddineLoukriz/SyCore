import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sycore_client/sycore_client.dart';

import 'l10n.dart';

/// The three people in the demonstration. Everything else is discovered from
/// the server's /health and /v1 resources.
class Persona {
  const Persona(this.id, this.name, this.nameAr, this.roleKey, this.color);

  final String id;
  final String name;
  final String nameAr;
  final String roleKey;
  final int color;

  String nameIn(Strings s) => s.isAr ? nameAr : name;
}

const personas = <Persona>[
  Persona('usr_ali', 'Ali', 'علي', 'role_ali', 0xFF35564A),
  Persona('usr_sara', 'Sara', 'سارة', 'role_sara', 0xFF4C5C7A),
  Persona('usr_mona', 'Mona', 'منى', 'role_mona', 0xFF8A6524),
];

/// One place where the app holds state. The SDK does the work; this class only
/// decides what to show and when to refresh.
class AppState extends ChangeNotifier {
  AppState({Uri? server, VaultStore? store})
      : server = server ??
            Uri.parse(const String.fromEnvironment('SYCORE_SERVER',
                defaultValue: 'http://127.0.0.1:8787')),
        sdk = SyCore(
          server: server ??
              Uri.parse(const String.fromEnvironment('SYCORE_SERVER',
                  defaultValue: 'http://127.0.0.1:8787')),
          store: store ??
              FileVaultStore(
                root: Directory(Platform.environment['SYCORE_HOME'] ??
                    '${Platform.environment['HOME'] ?? '/tmp'}/.sycore/app'),
              ),
        );

  final Uri server;
  final SyCore sdk;

  static const project = 'prj_home';
  static const device = 'laptop';
  static const demoPassword = 'correct horse battery staple';

  Account? account;
  bool busy = false;
  String? errorKey;
  Map<String, Object?> errorVars = const {};
  bool online = false;
  Map<String, dynamic> health = const {};

  bool get signedIn => account != null;
  String get userId => account?.userId ?? '';

  /// Run something with the busy flag and one error channel. Errors are stored
  /// as a key + values so they can be re-rendered in either language.
  Future<T?> guard<T>(Future<T> Function() body) async {
    busy = true;
    errorKey = null;
    errorVars = const {};
    notifyListeners();
    try {
      return await body();
    } catch (e) {
      final described = describe(e);
      errorKey = described.$1;
      errorVars = described.$2;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Localised text for the current error, if any.
  String? error(Strings t) =>
      errorKey == null ? null : t.t(errorKey!, errorVars);

  Future<void> ping() async {
    try {
      health = await sdk.operator.health();
      online = true;
    } catch (_) {
      online = false;
    }
    notifyListeners();
  }

  /// Log in if this device already has an envelope.
  ///
  /// If another device on this machine has one (the CLI demo ran first), attach
  /// this device to the *same* identity: one seed, one vault key, no new keys
  /// published. Only a machine with no envelope at all creates an identity.
  Future<bool> signIn(String userId, String password,
      {bool create = false}) async {
    final ok = await guard(() async {
      if (create) {
        return sdk.register(
            userId: userId, password: password, deviceId: device);
      }
      try {
        return await sdk.login(
            userId: userId, password: password, deviceId: device);
      } on SycoreException catch (e) {
        if (e.code != 'no_device_envelope') rethrow;
        final others = await sdk.devices(userId: userId);
        if (others.isEmpty) {
          return sdk.register(
              userId: userId, password: password, deviceId: device);
        }
        await sdk.login(
            userId: userId, password: password, deviceId: others.first);
        await sdk.addDevice(deviceId: device, password: password);
        return sdk.login(
            userId: userId, password: password, deviceId: device);
      }
    });
    account = ok;
    await ping();
    return ok != null;
  }

  Future<void> signOut() async {
    sdk.logout();
    account = null;
    errorKey = null;
    notifyListeners();
  }

  Future<void> refreshHealth() => ping();

  /// A refusal, as a translation key plus its values.
  (String, Map<String, Object?>) describe(Object e) {
    if (e is SycoreApiException) {
      return switch (e.code) {
        'forbidden' => ('err_forbidden', const {}),
        'not_found' => ('err_not_found', const {}),
        'version_conflict' => ('err_version_conflict', const {}),
        'data_poisoning_rejected' => ('err_data_poisoning', const {}),
        'not_owner' => ('err_not_owner', const {}),
        'key_conflict' => ('err_key_conflict', const {}),
        'unauthenticated' => ('err_unauthenticated', const {}),
        'invalid_envelope' => ('err_invalid_envelope', const {}),
        _ => ('err_api', {'status': e.status, 'code': e.code}),
      };
    }
    if (e is SycoreException) {
      return switch (e.code) {
        'wrong_password' => ('err_wrong_password', const {}),
        'no_device_envelope' => ('err_no_device', const {}),
        'identity_mismatch' => ('err_identity_mismatch', const {}),
        'locked' => ('err_locked', const {}),
        'unknown_group' => ('err_unknown_group', const {}),
        _ => (e.message ?? e.code, const {}),
      };
    }
    if (e is SycoreCryptoException) return ('err_crypto', {'code': e.code});
    if (e is SocketException) return ('err_offline', {'url': server});
    return (e.toString(), const {});
  }

  static String prettyJson(Map<String, dynamic> j) =>
      const JsonEncoder.withIndent('  ').convert(j);
}
