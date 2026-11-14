/// The device vault envelope: password → Argon2id → KEK → wrapped VK.
library;

import 'dart:typed_data';

import 'crypto.dart';

/// One device's copy of the vault key.
///
/// The vault key (`VK`) is generated **once per user** and wrapped separately
/// for every device. Adding a device adds an envelope; it never duplicates
/// content. Changing the password re-wraps `VK` — no content is re-encrypted.
class Vault {
  Vault({
    required this.deviceId,
    required this.salt,
    required this.nonce,
    required this.wrappedVk,
    this.params = const Argon2Params(),
  });

  final String deviceId;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List wrappedVk;
  final Argon2Params params;

  /// Build a device envelope that wraps [vk].
  static Future<Vault> create({
    required String password,
    required String deviceId,
    required Uint8List vk,
    Uint8List? salt,
    Uint8List? nonce,
    Argon2Params params = const Argon2Params(),
  }) async {
    final s = salt ?? randomBytes(16);
    final n = nonce ?? randomBytes(12);
    final kek = argon2id(password, s, params: params);
    final wrapped = await aeadSeal(
      key: kek,
      plain: vk,
      aad: aadVault(deviceId),
      nonce: n,
    );
    return Vault(
      deviceId: deviceId,
      salt: s,
      nonce: n,
      wrappedVk: wrapped,
      params: params,
    );
  }

  /// Recover `VK`. Any failure is reported as `vault_unlock_failed` — the
  /// caller never learns which check failed.
  Future<Uint8List> unlock(String password) async {
    try {
      final kek = argon2id(password, salt, params: params);
      return await aeadOpen(
        key: kek,
        sealed: wrappedVk,
        aad: aadVault(deviceId),
        nonce: nonce,
      );
    } catch (_) {
      throw const SycoreCryptoException('vault_unlock_failed');
    }
  }

  /// Re-wrap the same `VK` under a new password.
  Future<Vault> changePassword({
    required String oldPassword,
    required String newPassword,
    Uint8List? salt,
    Uint8List? nonce,
  }) async {
    final vk = await unlock(oldPassword);
    return Vault.create(
      password: newPassword,
      deviceId: deviceId,
      vk: vk,
      salt: salt,
      nonce: nonce,
      params: params,
    );
  }

  Map<String, Object> toJson() => {
        'v': 1,
        'device_id': deviceId,
        'kdf': {...params.toJson(), 'salt': b64u(salt)},
        'nonce': b64u(nonce),
        'wrapped_vk': b64u(wrappedVk),
      };
}
