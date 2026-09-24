import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/auth/data/auth_service.dart';
import 'package:medico/features/auth/data/http_auth_service.dart';

/// A signed-in session exactly as `/auth/sign-in` returns one.
final String _sessionBody = jsonEncode({
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'user': {'id': 'u1', 'name': 'Ada Lovelace', 'email': 'ada@example.com'},
});

({HttpAuthService auth, SessionController session, List<String> calls}) _subject(
  Future<http.Response> Function(http.Request request) handler, {
  SessionStore? store,
}) {
  final calls = <String>[];
  final session = SessionController(store: store ?? InMemorySessionStore());
  final api = ApiClient(
    baseUrl: 'https://api.test/v1',
    session: session,
    httpClient: MockClient((request) {
      calls.add('${request.method} ${request.url.path}');
      return handler(request);
    }),
  );
  return (
    auth: HttpAuthService(api: api, session: session),
    session: session,
    calls: calls,
  );
}

void main() {
  test('a successful sign-in starts a session', () async {
    final subject = _subject((request) async {
      expect(jsonDecode(request.body), {
        'email': 'ada@example.com',
        'password': 'medico1234',
      });
      return http.Response(_sessionBody, 200);
    });

    await subject.auth.signIn(
      email: 'ada@example.com',
      password: 'medico1234',
    );

    expect(subject.session.isSignedIn, isTrue);
    expect(subject.session.user!.name, 'Ada Lovelace');
    expect(subject.session.user!.firstName, 'Ada');
  });

  test('"keep me signed in", off, keeps nothing on disk', () async {
    final store = InMemorySessionStore();
    final subject = _subject(
      (request) async => http.Response(_sessionBody, 200),
      store: store,
    );

    await subject.auth.signIn(
      email: 'ada@example.com',
      password: 'medico1234',
      remember: false,
    );

    expect(subject.session.isSignedIn, isTrue,
        reason: 'the patient is signed in for as long as the app is open');
    expect(await store.read(), isNull,
        reason: 'but nothing was written for the next launch');
  });

  test('"keep me signed in", on, survives a restart', () async {
    final store = InMemorySessionStore();
    final subject = _subject(
      (request) async => http.Response(_sessionBody, 200),
      store: store,
    );

    await subject.auth.signIn(
      email: 'ada@example.com',
      password: 'medico1234',
      remember: true,
    );

    // A fresh controller over the same storage is what the next launch does.
    final next = SessionController(store: store);
    await next.restore();
    expect(next.isSignedIn, isTrue);
    expect(next.user!.email, 'ada@example.com');
  });

  test('a locked account arrives as the kind the screen offers a reset for',
      () async {
    final subject = _subject(
      (request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'account_locked',
            'message': 'This account is locked after too many attempts.',
          },
        }),
        423,
      ),
    );

    await expectLater(
      subject.auth.signIn(email: 'ada@example.com', password: 'nope'),
      throwsA(isA<AuthException>()
          .having((e) => e.kind, 'kind', AuthFailure.accountLocked)
          // The server writes for the patient; we do not paraphrase it.
          .having((e) => e.message, 'message',
              'This account is locked after too many attempts.')),
    );
    expect(subject.session.isSignedIn, isFalse);
  });

  test('a taken email on sign-up is its own kind', () async {
    final subject = _subject(
      (request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'email_taken',
            'message': 'There is already a Medico account with this email.',
          },
        }),
        409,
      ),
    );

    await expectLater(
      subject.auth.signUp(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'medico1234',
      ),
      throwsA(isA<AuthException>()
          .having((e) => e.kind, 'kind', AuthFailure.emailTaken)),
    );
  });

  test('being throttled is not a wrong password', () async {
    final subject = _subject(
      (request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'rate_limited',
            'message': 'Too many attempts. Wait a few minutes and try again.',
          },
        }),
        429,
      ),
    );

    await expectLater(
      subject.auth.signIn(email: 'ada@example.com', password: 'medico1234'),
      throwsA(isA<AuthException>()
          .having((e) => e.kind, 'kind', AuthFailure.rateLimited)),
    );
  });

  test('signing out revokes the refresh token at the server', () async {
    String? revoked;
    final subject = _subject((request) async {
      if (request.url.path.endsWith('/auth/sign-out')) {
        revoked = jsonDecode(request.body)['refreshToken'] as String;
        return http.Response('', 204);
      }
      return http.Response(_sessionBody, 200);
    });

    await subject.auth.signIn(email: 'ada@example.com', password: 'medico1234');
    await subject.auth.signOut();

    expect(revoked, 'refresh-1');
    expect(subject.session.isSignedIn, isFalse);
  });

  test('signing out with no network still signs the patient out here',
      () async {
    final subject = _subject((request) async {
      if (request.url.path.endsWith('/auth/sign-out')) {
        throw http.ClientException('connection closed', request.url);
      }
      return http.Response(_sessionBody, 200);
    });

    await subject.auth.signIn(email: 'ada@example.com', password: 'medico1234');
    await subject.auth.signOut();

    expect(subject.session.isSignedIn, isFalse,
        reason: 'a borrowed phone must not keep the session because the '
            'network was down');
  });

  test('a password reset asks, and says nothing about whether the address '
      'exists', () async {
    final subject = _subject(
      (request) async => http.Response(
        jsonEncode({
          'message': 'If there is a Medico account for that address, the '
              'reset link is on its way.',
        }),
        200,
      ),
    );

    await subject.auth.sendPasswordReset('nobody@example.com');
    expect(subject.calls, ['POST /v1/auth/password-reset/request']);
  });

  test('SSO says it is not connected rather than failing vaguely', () async {
    final subject = _subject((request) async => http.Response('{}', 200));

    await expectLater(
      subject.auth.signInWithProvider(SsoProvider.google),
      throwsA(isA<AuthException>().having(
        (e) => e.message,
        'message',
        contains('Google sign-in is not connected yet'),
      )),
    );
    expect(subject.calls, isEmpty, reason: 'there is no route to call');
  });
}
