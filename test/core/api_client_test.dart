import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/core/auth/session.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';

const _user = MedicoUser(id: 'u1', name: 'Ada Lovelace', email: 'ada@example.com');

Session _session({String access = 'access-1', String refresh = 'refresh-1'}) =>
    Session(accessToken: access, refreshToken: refresh, user: _user);

Future<SessionController> _signedIn({bool remember = true}) async {
  final controller = SessionController(store: InMemorySessionStore());
  await controller.begin(_session(), remember: remember);
  return controller;
}

void main() {
  test('sends the access token, and nothing when there is no session', () async {
    final headers = <String, String?>{};
    final session = SessionController(store: InMemorySessionStore());

    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: session,
      httpClient: MockClient((request) async {
        headers[request.url.path] = request.headers['authorization'];
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );

    await api.get('/doctors');
    await session.begin(_session(), remember: false);
    await api.get('/me/favourites');

    expect(headers['/v1/doctors'], isNull);
    expect(headers['/v1/me/favourites'], 'Bearer access-1');
  });

  test('a 401 refreshes the session once and replays the request', () async {
    final session = await _signedIn();
    final calls = <String>[];

    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: session,
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');

        if (request.url.path.endsWith('/auth/refresh')) {
          expect(jsonDecode(request.body)['refreshToken'], 'refresh-1');
          return http.Response(
            jsonEncode({'accessToken': 'access-2', 'refreshToken': 'refresh-2'}),
            200,
          );
        }

        if (request.headers['authorization'] == 'Bearer access-2') {
          return http.Response(jsonEncode({'doctors': []}), 200);
        }
        return http.Response(
          jsonEncode({'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'}}),
          401,
        );
      }),
    );

    final body = await api.get('/me/favourites');

    expect(body, {'doctors': []});
    expect(calls, [
      'GET /v1/me/favourites',
      'POST /v1/auth/refresh',
      'GET /v1/me/favourites',
    ]);
    expect(session.session!.accessToken, 'access-2');
    expect(session.session!.refreshToken, 'refresh-2');
    // `/auth/refresh` answers with tokens only — the patient must survive it.
    expect(session.user!.name, 'Ada Lovelace');
  });

  test('four requests meeting one expired token refresh once, not four',
      () async {
    final session = await _signedIn();
    var refreshes = 0;

    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: session,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          // A rotated token the server would revoke the chain over if it were
          // asked to rotate the same one twice.
          return http.Response(
            jsonEncode({
              'accessToken': 'access-2',
              'refreshToken': 'refresh-rotated',
            }),
            200,
          );
        }
        if (request.headers['authorization'] == 'Bearer access-2') {
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'}}),
          401,
        );
      }),
    );

    await Future.wait([
      api.get('/a'),
      api.get('/b'),
      api.get('/c'),
      api.get('/d'),
    ]);

    expect(refreshes, 1);
    expect(session.session!.refreshToken, 'refresh-rotated');
  });

  test('a refresh the server refuses ends the session', () async {
    final session = await _signedIn();

    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: session,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'For your security we ended that session. Sign in again.',
              },
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode({'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'}}),
          401,
        );
      }),
    );

    await expectLater(
      api.get('/me/favourites'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.unauthorized)),
    );
    expect(session.isSignedIn, isFalse,
        reason: 'a dead refresh chain must not be left on the device');
  });

  test('being offline during a refresh keeps the session', () async {
    final session = await _signedIn();

    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: session,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          throw const SocketException('no route to host');
        }
        return http.Response(
          jsonEncode({'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'}}),
          401,
        );
      }),
    );

    await expectLater(api.get('/me/favourites'), throwsA(isA<ApiException>()));
    expect(session.isSignedIn, isTrue,
        reason: 'a tunnel is not a revoked token');
  });

  test('the error envelope becomes a typed failure', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'slot_taken',
                'message': 'Someone just booked that time. Pick another.',
              },
            }),
            409,
          )),
    );

    await expectLater(
      api.post('/appointments', body: const {}),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.slotTaken)
          .having((e) => e.message, 'message',
              'Someone just booked that time. Pick another.')
          .having((e) => e.status, 'status', 409)),
    );
  });

  test('an unknown code degrades instead of throwing inside the error path',
      () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'error': {'code': 'teapot', 'message': 'No coffee here.'},
            }),
            418,
          )),
    );

    await expectLater(
      api.get('/anything'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.unknown)
          .having((e) => e.message, 'message', 'No coffee here.')),
    );
  });

  test('a dead network is its own failure, not a server error', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) async {
        throw http.ClientException('connection closed', request.url);
      }),
    );

    await expectLater(
      api.get('/doctors'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.network)),
    );
  });

  test('a 204 is a success with nothing in it', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: await _signedIn(),
      httpClient: MockClient((request) async => http.Response('', 204)),
    );

    expect(await api.delete('/me/favourites/d2'), isNull);
  });

  test('query parameters are carried, not dropped', () async {
    late Uri seen;
    final api = ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) async {
        seen = request.url;
        return http.Response('{}', 200);
      }),
    );

    await api.get('/doctors', query: {'specialty': 'Eye care', 'perPage': '50'});

    expect(seen.queryParameters['specialty'], 'Eye care');
    expect(seen.queryParameters['perPage'], '50');
  });
}
