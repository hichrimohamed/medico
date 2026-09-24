import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/session.dart';
import '../auth/session_controller.dart';
import 'api_exception.dart';

/// The one place the app talks to the network.
///
/// It does three things that every caller would otherwise have to remember:
/// attaches the access token, turns the server's error envelope into an
/// [ApiException], and — when a request comes back 401 — refreshes the session
/// once and replays the request.
///
/// That replay is the whole reason this is a class and not a function. Access
/// tokens live fifteen minutes, so a patient who leaves the app open over
/// lunch will hit an expired one on their next tap. Without this they would be
/// thrown back to sign-in while holding a perfectly good refresh token.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.session,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final SessionController session;
  final http.Client _http;

  /// In flight refresh, shared by every request that hit a 401 at once.
  ///
  /// Without this, four parallel requests meeting an expired token would fire
  /// four refreshes with the same token. Three of them would arrive after the
  /// token had rotated, and the server treats a retired refresh token coming
  /// back as a stolen one — it would revoke the chain and sign the patient out.
  /// The bug would look like a random logout under bad timing.
  Future<bool>? _refreshing;

  void close() => _http.close();

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) =>
      _send('GET', path, query: query, authenticated: authenticated);

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) =>
      _send('PUT', path, body: body, authenticated: authenticated);

  Future<dynamic> patch(String path, {Object? body, bool authenticated = true}) =>
      _send('PATCH', path, body: body, authenticated: authenticated);

  /// Takes a body, which is unusual for DELETE but is what deleting an account
  /// needs: the password, re-entered, as proof for something irreversible.
  Future<dynamic> delete(
    String path, {
    Object? body,
    bool authenticated = true,
  }) =>
      _send('DELETE', path, body: body, authenticated: authenticated);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    required bool authenticated,
    bool isRetry = false,
  }) async {
    final uri = _uri(path, query);
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json';

    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final token = session.session?.accessToken;
    if (authenticated && token != null && token.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on SocketException {
      throw ApiException.offline;
    } on http.ClientException {
      throw ApiException.offline;
    } on TimeoutException {
      throw ApiException.offline;
    }

    if (response.statusCode == 401 &&
        authenticated &&
        !isRetry &&
        session.isSignedIn) {
      if (await _refresh()) {
        return _send(
          method,
          path,
          body: body,
          query: query,
          authenticated: authenticated,
          isRetry: true,
        );
      }
    }

    return _decode(response);
  }

  Uri _uri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  dynamic _decode(http.Response response) {
    final hasBody = response.bodyBytes.isNotEmpty;
    dynamic decoded;
    if (hasBody) {
      try {
        // Decoded from the bytes as UTF-8 rather than through `response.body`,
        // which falls back to latin-1 when a response arrives without a
        // charset. JSON is UTF-8 by definition, and the server's messages are
        // full of em dashes and curly quotes — a patient should not be told
        // that the clinic is closed on â€" Sunday.
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        // A proxy's HTML error page, or a crash before the JSON was written.
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw ApiException.malformed;
        }
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded is Map<String, dynamic>
        ? decoded['error'] as Map<String, dynamic>?
        : null;

    throw ApiException(
      ApiErrorCode.parse(error?['code'] as String?),
      (error?['message'] as String?) ?? ApiException.malformed.message,
      status: response.statusCode,
      details: error?['details'],
    );
  }

  /// Rotates the session. Returns false when the patient has to sign in again,
  /// having already cleared the dead session.
  Future<bool> _refresh() {
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _performRefresh() async {
    final current = session.session;
    if (current == null || current.refreshToken.isEmpty) return false;

    try {
      final body = await _send(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': current.refreshToken},
        authenticated: false,
        isRetry: true,
      );
      if (body is! Map<String, dynamic>) return false;

      final rotated = Session.fromJson(body);
      if (rotated.accessToken.isEmpty || rotated.refreshToken.isEmpty) {
        return false;
      }
      // `/auth/refresh` answers with tokens only, so keep the patient we know.
      await session.update(rotated.copyWith(
        user: body['user'] == null ? current.user : rotated.user,
      ));
      return true;
    } on ApiException catch (error) {
      // Offline is not a revoked session — keeping it lets the patient come
      // back when the train leaves the tunnel instead of being signed out.
      if (error.code == ApiErrorCode.network) return false;
      await session.end();
      return false;
    }
  }
}
