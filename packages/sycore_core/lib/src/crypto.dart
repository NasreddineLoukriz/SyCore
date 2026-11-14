/// SYCORE v1 — primitives, encoding and associated-data construction.
///
/// Everything here is pure client-side. No key ever leaves the device.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;

/// Argon2id parameters. Defaults match SPEC.md §2.
class Argon2Params {
  const Argon2Params({this.t = 3, this.m = 65536, this.p = 4});

  /// Iterations.
  final int t;

  /// Memory in KiB.
  final int m;

  /// Parallelism.
  final int p;

  Map<String, Object> toJson() => {'alg': 'argon2id', 'v': 19, 't': t, 'm': m, 'p': p};
}

final Random _rng = Random.secure();

/// Cryptographically secure random bytes.
Uint8List randomBytes(int n) {
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    out[i] = _rng.nextInt(256);
  }
  return out;
}

/// Argon2id (RFC 9106). Returns a 32-byte key derived from a password.
Uint8List argon2id(String password, Uint8List salt,
    {Argon2Params params = const Argon2Params()}) {
  final p = pc.Argon2Parameters(
    pc.Argon2Parameters.ARGON2_id,
    salt,
    desiredKeyLength: 32,
    iterations: params.t,
    memory: params.m,
    lanes: params.p,
    version: pc.Argon2Parameters.ARGON2_VERSION_13,
  );
  final gen = pc.Argon2BytesGenerator()..init(p);
  final out = Uint8List(32);
  gen.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, out, 0);
  return out;
}

/// HKDF-SHA256.
Future<Uint8List> hkdf({
  required Uint8List ikm,
  required Uint8List salt,
  required String info,
  int length = 32,
}) async {
  final kdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
  final key = await kdf.deriveKey(
    secretKey: SecretKey(ikm),
    nonce: salt,
    info: utf8.encode(info),
  );
  return Uint8List.fromList(await key.extractBytes());
}

final AesGcm _aes = AesGcm.with256bits();

/// AES-256-GCM seal. Output is `ciphertext || tag(16)`.
///
/// [aad] is mandatory: a ciphertext with no associated data is a protocol
/// error (SPEC.md §3).
Future<Uint8List> aeadSeal({
  required Uint8List key,
  required Uint8List plain,
  required Uint8List aad,
  required Uint8List nonce,
}) async {
  if (nonce.length != 12) {
    throw ArgumentError('nonce must be 12 bytes');
  }
  final box = await _aes.encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: nonce,
    aad: aad,
  );
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

/// AES-256-GCM open. Throws [SycoreCryptoException] on any failure.
Future<Uint8List> aeadOpen({
  required Uint8List key,
  required Uint8List sealed,
  required Uint8List aad,
  required Uint8List nonce,
}) async {
  if (sealed.length < 16) {
    throw const SycoreCryptoException('resource_open_failed');
  }
  final split = sealed.length - 16;
  final box = SecretBox(
    sealed.sublist(0, split),
    nonce: nonce,
    mac: Mac(sealed.sublist(split)),
  );
  try {
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const SycoreCryptoException('resource_open_failed');
  }
}

/// A single, generic, non-leaking failure. SPEC.md §9.
class SycoreCryptoException implements Exception {
  const SycoreCryptoException(this.code);

  final String code;

  @override
  String toString() => 'SycoreCryptoException($code)';
}

/// base64url without padding.
String b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Decode base64url, padding optional.
Uint8List unb64u(String s) => Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));

/// ASCII/UTF-8 bytes of a string.
Uint8List utf8b(String s) => Uint8List.fromList(utf8.encode(s));

/// Associated data for every AEAD operation (SPEC.md §3).
Uint8List aad({
  required String kind,
  required String projectId,
  required String domain,
  required String resourceId,
  required String ownerId,
  required int version,
  String recipientId = '',
}) =>
    utf8b('sycore/v1|$kind|$projectId|$domain|$resourceId|$ownerId|$version|$recipientId');

/// Associated data for a device vault envelope (SPEC.md §3).
Uint8List aadVault(String deviceId) => utf8b('sycore/v1|vault|$deviceId');

/// HKDF context string for recipient key wrapping.
const String infoHosnWrap = 'sycore/v1/hosn/wrap';
