import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sycore_client/sycore_client.dart';

/// The three people in the demonstration. Everything else is discovered from
/// the server's /health and /v1 resources.
class Persona {
  const Persona(this.id, this.name, this.role, this.color);

  final String id;
  final String name;
  final String role;
  final int color;
}

const personas = <Persona>[
  Persona('usr_ali', 'Ali', 'owns the vault, sends and publishes', 0xFF4DD4C6),
  Persona('usr_sara', 'Sara', 'the invited reader', 0xFF8E8CF0),
  Persona('usr_mona', 'Mona', 'the member who is removed', 0xFFE8B45C),
];

/// One place where the app holds state. The SDK does the work; this class only
/// decides what to show and when to refresh.
class AppState extends ChangeNotifier {
  AppState({Uri? server, VaultStore? store})
      : server = server ?? Uri.parse(
            const String.fromEnvironment('SYCORE_SERVER',
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
  String? error;
  bool online = false;
  Map<String, dynamic> health = const {};

  bool get signedIn => account != null;
  String get userId => account?.userId ?? '';

  /// Run something with the busy flag and a single error channel.
  Future<T?> guard<T>(Future<T> Function() body) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final out = await body();
      return out;
    } catch (e) {
      error = describe(e);
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

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
  Future<bool> signIn(String userId, String password, {bool create = false}) async {
    final ok = await guard(() async {
      if (create) {
        return sdk.register(userId: userId, password: password, deviceId: device);
      }
      try {
        return await sdk.login(userId: userId, password: password, deviceId: device);
      } on SycoreException catch (e) {
        if (e.code != 'no_device_envelope') rethrow;
        final others = await sdk.devices(userId: userId);
        if (others.isEmpty) {
          return sdk.register(userId: userId, password: password, deviceId: device);
        }
        await sdk.login(userId: userId, password: password, deviceId: others.first);
        await sdk.addDevice(deviceId: device, password: password);
        return sdk.login(userId: userId, password: password, deviceId: device);
      }
    });
    account = ok;
    await ping();
    return ok != null;
  }

  Future<void> signOut() async {
    sdk.logout();
    account = null;
    error = null;
    notifyListeners();
  }

  Future<List<String>> directoryIds() async => personas.map((p) => p.id).toList();

  Future<void> refreshHealth() => ping();

  String describe(Object e) {
    if (e is SycoreApiException) {
      return switch (e.code) {
        'forbidden' =>
          '403 · forbidden — the server found the row, but this user is not in its wraps',
        'not_found' => '404 · not_found — no such row',
        'version_conflict' => '409 · version_conflict — someone wrote a newer version',
        'data_poisoning_rejected' =>
          '422 · data_poisoning_rejected — the domain is locked to another clearance',
        'not_owner' => '403 · not_owner — only the owner may write this row',
        'key_conflict' =>
          '409 · key_conflict — this name is registered with different keys. '
              'The demo server was reset? Run  ./reset.sh  in server/ and delete ~/.sycore/app',
        'unauthenticated' => '401 · unauthenticated — the SDK sent no X-Sycore-User',
        'invalid_envelope' => '422 · invalid_envelope — the server refused the shape',
        _ => '${e.status} · ${e.code}',
      };
    }
    if (e is SycoreException) {
      return switch (e.code) {
        'wrong_password' => 'vault_unlock_failed — wrong password for this device',
        'no_device_envelope' => 'This device holds no envelope for that account',
        'identity_mismatch' =>
          'identity_mismatch — the server holds different public keys for this name',
        'locked' => 'Locked — sign in first',
        'unknown_group' => 'No local state for that group on this device',
        _ => e.message ?? e.code,
      };
    }
    if (e is SycoreCryptoException) {
      return 'refused on this device: ${e.code}';
    }
    if (e is SocketException) {
      return 'Cannot reach the server at $server — is server/run.sh running?';
    }
    return e.toString();
  }

  static String prettyJson(Map<String, dynamic> j) =>
      const JsonEncoder.withIndent('  ').convert(j);
}
