import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/profile/data/profile_repository.dart';

/// The patient exactly as `GET /me` sends them.
const Map<String, dynamic> _me = {
  'id': 'u1',
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'createdAt': '2026-03-14T09:00:00.000Z',
  'updatedAt': '2026-09-01T09:00:00.000Z',
  'favouriteDoctorIds': ['d2', 'd5'],
  'savedDoctors': 2,
  'upcomingAppointments': 3,
  'unreadThreads': 1,
};

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

({ApiClient api, List<String> calls, List<String> bodies}) _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  final calls = <String>[];
  final bodies = <String>[];
  return (
    api: ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) {
        calls.add('${request.method} ${request.url.path}');
        bodies.add(request.body);
        return handler(request);
      }),
    ),
    calls: calls,
    bodies: bodies,
  );
}

void main() {
  test('the profile carries the counts the screen shows', () async {
    final client = _client((request) async => _ok(_me));

    final profile = await HttpProfileRepository(client.api).load();

    expect(client.calls.single, 'GET /v1/me');
    expect(profile.name, 'Ada Lovelace');
    expect(profile.firstName, 'Ada');
    expect(profile.email, 'ada@example.com');
    expect(profile.savedDoctors, 2);
    expect(profile.upcomingAppointments, 3);
    expect(profile.unreadThreads, 1);
    expect(profile.memberSinceLabel, 'March 2026');
  });

  test('a profile with no dates does not throw', () async {
    final client = _client((request) async => _ok({'id': 'u1', 'name': 'A B'}));

    final profile = await HttpProfileRepository(client.api).load();

    expect(profile.memberSince, isNull);
    expect(profile.memberSinceLabel, isNull);
    expect(profile.upcomingAppointments, 0);
  });

  test('renaming PATCHes the trimmed name', () async {
    final client = _client(
      (request) async => _ok({..._me, 'name': 'Ada King'}),
    );

    final updated = await HttpProfileRepository(client.api).rename('  Ada King  ');

    expect(client.calls.single, 'PATCH /v1/me');
    expect(jsonDecode(client.bodies.single)['name'], 'Ada King');
    expect(updated.name, 'Ada King');
  });

  test('changing the password sends both, and nothing else', () async {
    final client = _client((request) async => http.Response('', 204));

    await HttpProfileRepository(client.api).changePassword(
      currentPassword: 'old-one',
      newPassword: 'a-longer-new-one',
    );

    expect(client.calls.single, 'POST /v1/me/password');
    final sent = jsonDecode(client.bodies.single) as Map<String, dynamic>;
    expect(sent, {
      'currentPassword': 'old-one',
      'newPassword': 'a-longer-new-one',
    });
  });

  test('deleting the account sends the password with the DELETE', () async {
    final client = _client((request) async => http.Response('', 204));

    await HttpProfileRepository(client.api).deleteAccount('medico1234');

    expect(client.calls.single, 'DELETE /v1/me');
    // Unusual for a DELETE, and deliberate: the session alone is not proof
    // enough for the one thing that cannot be undone.
    expect(jsonDecode(client.bodies.single)['password'], 'medico1234');
  });
}
