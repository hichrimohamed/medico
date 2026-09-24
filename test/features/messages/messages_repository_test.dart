import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/messages/data/message.dart';
import 'package:medico/features/messages/data/messages_repository.dart';

/// One thread exactly as `GET /threads` sends it, doctor populated.
const Map<String, dynamic> _thread = {
  'id': 't1',
  'subject': 'Blood pressure review',
  'aboutDoctorId': {
    'id': 'd2',
    'name': 'Dr. Thomas Moore',
    'specialty': 'Cardiologist',
    'specialtyField': 'Cardiology',
  },
  'lastMessageAt': '2026-09-22T10:00:00.000Z',
  'lastMessagePreview': 'Please keep going with the same dose — it is working.',
  'lastMessageFrom': 'clinic',
  'unreadForPatient': 2,
  'closedAt': null,
};

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

({ApiClient api, List<Uri> urls, List<String> methods}) _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  final urls = <Uri>[];
  final methods = <String>[];
  return (
    api: ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) {
        urls.add(request.url);
        methods.add('${request.method} ${request.url.path}');
        return handler(request);
      }),
    ),
    urls: urls,
    methods: methods,
  );
}

void main() {
  test('the list carries the threads and the count of those waiting', () async {
    final client = _client((request) async => _ok({
          'threads': [_thread],
          'unreadThreads': 1,
        }));

    final result = await HttpMessagesRepository(client.api).threads();

    expect(client.urls.single.path, '/v1/threads');
    expect(result.unreadThreads, 1);

    final thread = result.threads.single;
    expect(thread.subject, 'Blood pressure review');
    expect(thread.unreadCount, 2);
    expect(thread.hasUnread, isTrue);
    expect(thread.lastMessageFrom, MessageAuthor.clinic);
    expect(thread.isClosed, isFalse);
    // Populated, so a row can say what it is about without a second request.
    expect(thread.aboutDoctor!.name, 'Dr. Thomas Moore');
    expect(thread.lastMessagePreview, contains('—'),
        reason: 'an em dash must survive the wire');
  });

  test('the unread filter goes to the server', () async {
    final client = _client((request) async => _ok({'threads': []}));

    await HttpMessagesRepository(client.api).threads(unreadOnly: true);

    expect(client.urls.single.queryParameters['unread'], 'true');
  });

  test('a thread about nobody in particular has no doctor', () async {
    final client = _client((request) async => _ok({
          'threads': [
            {..._thread, 'aboutDoctorId': null, 'unreadForPatient': 0},
          ],
        }));

    final thread = (await HttpMessagesRepository(client.api).threads())
        .threads
        .single;

    expect(thread.aboutDoctor, isNull);
    expect(thread.hasUnread, isFalse);
  });

  test('a conversation comes back with its thread and its messages', () async {
    final client = _client((request) async => _ok({
          'thread': _thread,
          'messages': [
            {
              'id': 'm1',
              'from': 'patient',
              'body': 'Readings are around 140 over 90.',
              'sentAt': '2026-09-21T08:00:00.000Z',
              'readAt': null,
            },
            {
              'id': 'm2',
              'from': 'clinic',
              'body': 'Keep going with the same dose.',
              'sentAt': '2026-09-22T10:00:00.000Z',
              'readAt': '2026-09-22T11:00:00.000Z',
            },
          ],
        }));

    final conversation =
        await HttpMessagesRepository(client.api).conversation('t1');

    expect(client.urls.single.path, '/v1/threads/t1/messages');
    expect(conversation.thread.subject, 'Blood pressure review');
    expect(conversation.messages, hasLength(2));
    expect(conversation.messages.first.fromPatient, isTrue);
    expect(conversation.messages.first.sentAt, DateTime.utc(2026, 9, 21, 8));
    expect(conversation.messages.last.fromPatient, isFalse);
    expect(conversation.messages.last.readAt, isNotNull);
  });

  test('starting a conversation sends a subject and a first message',
      () async {
    late Map<String, dynamic> sent;
    final client = _client((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _ok(_thread, 201);
    });

    await HttpMessagesRepository(client.api).start(
      subject: '  Test results  ',
      body: '  Are they back?  ',
    );

    expect(client.methods.single, 'POST /v1/threads');
    expect(sent['subject'], 'Test results');
    expect(sent['body'], 'Are they back?');
    expect(sent.containsKey('aboutDoctorId'), isFalse);
  });

  test('a conversation can be started about a doctor', () async {
    late Map<String, dynamic> sent;
    final client = _client((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _ok(_thread, 201);
    });

    await HttpMessagesRepository(client.api).start(
      subject: 'About my appointment',
      body: 'Can I move it?',
      aboutDoctorId: 'd2',
    );

    expect(sent['aboutDoctorId'], 'd2');
  });

  test('sending posts into the thread and reads the message back', () async {
    late Map<String, dynamic> sent;
    final client = _client((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _ok({
        'id': 'm3',
        'from': 'patient',
        'body': 'Thank you.',
        'sentAt': '2026-09-22T12:00:00.000Z',
      }, 201);
    });

    final message =
        await HttpMessagesRepository(client.api).send('t1', '  Thank you.  ');

    expect(client.methods.single, 'POST /v1/threads/t1/messages');
    expect(sent['body'], 'Thank you.');
    expect(message.id, 'm3');
    expect(message.fromPatient, isTrue);
  });

  test('marking read posts to the thread and nothing else', () async {
    final client = _client((request) async => _ok(_thread));

    await HttpMessagesRepository(client.api).markRead('t1');

    expect(client.methods, ['POST /v1/threads/t1/read']);
  });

  test('an author the client does not know is not a patient message',
      () async {
    final client = _client((request) async => _ok({
          'thread': _thread,
          'messages': [
            {
              'id': 'm9',
              'from': 'automated-system',
              'body': 'Your prescription is ready.',
              'sentAt': '2026-09-22T12:00:00.000Z',
            },
          ],
        }));

    final conversation =
        await HttpMessagesRepository(client.api).conversation('t1');

    // Unknown falls to the clinic's side of the thread, which is the safe
    // default: it is not something the patient said.
    expect(conversation.messages.single.from, MessageAuthor.unknown);
    expect(conversation.messages.single.fromPatient, isFalse);
  });
}
