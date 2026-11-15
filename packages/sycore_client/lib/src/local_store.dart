/// Where a device keeps its own vault envelope.
///
/// Nothing in here is sent anywhere. The server never learns the password, the
/// vault key, or the identity seed.
library;

import 'dart:convert';
import 'dart:io';

/// A tiny key/value contract, so the SDK can be tested in memory.
abstract interface class VaultStore {
  Future<Map<String, dynamic>?> read(String key);

  Future<void> write(String key, Map<String, dynamic> value);

  Future<void> delete(String key);

  Future<List<String>> keys(String prefix);
}

/// JSON files under `~/.sycore/<namespace>/<key>.json`.
///
/// Prototype-grade: the raw file holds the *wrapped* key material only. An
/// attacker with the file still needs the password, and Argon2id makes guessing
/// expensive. A shipping app would put this in the OS keychain.
class FileVaultStore implements VaultStore {
  FileVaultStore({Directory? root, this.namespace = 'default'})
      : _root = root ??
            Directory(
              '${Platform.environment['HOME'] ?? Directory.systemTemp.path}'
              '/.sycore/$namespace',
            );

  final Directory _root;
  final String namespace;

  File _file(String key) => File('${_root.path}/${Uri.encodeComponent(key)}.json');

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    await _root.create(recursive: true);
    final f = _file(key);
    // Write-then-rename, so a crash never leaves half a vault behind.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<String>> keys(String prefix) async {
    if (!await _root.exists()) return const [];
    final out = <String>[];
    await for (final e in _root.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      final name = e.uri.pathSegments.last;
      final key = Uri.decodeComponent(name.substring(0, name.length - 5));
      if (key.startsWith(prefix)) out.add(key);
    }
    out.sort();
    return out;
  }
}

/// For tests and for a "nothing touches the disk" demo mode.
class MemoryVaultStore implements VaultStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      _data[key] == null ? null : Map<String, dynamic>.of(_data[key]!);

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = Map<String, dynamic>.of(value);
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<List<String>> keys(String prefix) async =>
      _data.keys.where((k) => k.startsWith(prefix)).toList()..sort();
}
