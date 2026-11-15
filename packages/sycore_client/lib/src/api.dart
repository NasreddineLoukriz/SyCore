/// The HTTP surface of a SYCORE server: six endpoints, no crypto.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A refusal from the server, mapped to its wire code.
///
/// The client never guesses why. `code` is what the server said:
/// `forbidden`, `not_found`, `version_conflict`, `data_poisoning_rejected`,
/// `not_owner`, `key_conflict`, `unauthenticated`, `invalid_envelope`.
class SycoreApiException implements Exception {
  const SycoreApiException(this.status, this.code);

  final int status;
  final String code;

  /// True when the server refused because this user is not a reader.
  bool get isForbidden => status == 403;

  bool get isNotFound => status == 404;

  bool get isConflict => status == 409;

  @override
  String toString() => 'SycoreApiException($status, $code)';
}

/// Thin, explicit wrapper over the six routes.
class Api {
  Api(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = baseUrl.replace(
      path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}$path',
      queryParameters: query,
    );
    return u;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? as,
    Map<String, String>? query,
  }) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers(as))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Object body,
    String? as,
  }) async {
    final res = await _client
        .post(
          _uri(path),
          headers: {..._headers(as), 'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(res);
  }

  Map<String, String> _headers(String? as) =>
      as == null ? const {} : {'x-sycore-user': as};

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final error = body['error'];
      final code = error is Map ? (error['code'] as String? ?? 'error') : 'error';
      throw SycoreApiException(res.statusCode, code);
    }
    return body;
  }

  void close() => _client.close();
}
