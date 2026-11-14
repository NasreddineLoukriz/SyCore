/// A deliberately dumb server: it stores sealed boxes and enforces metadata
/// policy. It has no crypto and no keys — on purpose.
library;

import 'model.dart';

/// Domain clearances. The server only stores the string; it never verifies it.
abstract final class Clearance {
  static const e2ee = 'E2EE';
  static const plain = 'PLAIN';
  static const jahr = 'JAHR';
}

class ServerException implements Exception {
  const ServerException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// In-memory stand-in for the real Postgres-backed server.
///
/// The point of the demo is that this class contains **zero cryptography**.
/// If an engine name ("HOSN", "SAMAM") ever appears in a server, the design has
/// already failed.
class BlindServer {
  final Map<String, Envelope> _resources = {};
  final Map<String, String> _policy = {};

  int storedChars = 0;
  int authorizations = 0;
  int denials = 0;

  /// Trust-on-first-use domain gate (SPEC.md §6, data-poisoning defence).
  String put(Envelope env, {required String clearance}) {
    final policyKey = '${env.projectId}|${env.domain}';
    final locked = _policy[policyKey];

    if (locked == null) {
      _policy[policyKey] = clearance;
    } else if (locked != clearance) {
      throw const ServerException('data_poisoning_rejected');
    }

    final previous = _resources[env.id];
    if (previous == null) {
      if (env.version != 1) throw const ServerException('version_conflict');
    } else if (env.version != previous.version + 1) {
      throw const ServerException('version_conflict');
    }

    _resources[env.id] = env;
    storedChars = _resources.values
        .fold(0, (sum, e) => sum + e.ciphertext.length);
    return env.id;
  }

  /// Authorization is pure metadata: owner, or named in `wraps`.
  Envelope fetch(String id, {required String requester}) {
    final env = _resources[id];
    if (env == null) {
      denials++;
      throw const ServerException('not_found');
    }

    final publicDomain =
        _policy['${env.projectId}|${env.domain}'] == Clearance.jahr;
    if (!publicDomain && !env.canBeReadBy(requester)) {
      denials++;
      throw const ServerException('forbidden');
    }

    authorizations++;
    return env;
  }

  String? policyOf(String projectId, String domain) =>
      _policy['$projectId|$domain'];

  List<Envelope> resourcesIn(String projectId, String domain) => _resources
      .values
      .where((e) => e.projectId == projectId && e.domain == domain)
      .toList();

  /// Exactly what an operator (or an attacker with the database) can see.
  Map<String, Object?> wireView(String id) {
    final e = _resources[id]!;
    return {
      'id': e.id,
      'project_id': e.projectId,
      'domain': e.domain,
      'owner_id': e.ownerId,
      'version': e.version,
      'readers': e.wraps.map((w) => w.to).toList(),
      'ciphertext_chars': e.ciphertext.length,
      'signature': e.signature == null ? 'none' : 'present',
    };
  }
}
