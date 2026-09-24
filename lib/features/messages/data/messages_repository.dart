import '../../../core/api/api_client.dart';
import 'message.dart';

/// The list screen's whole answer: the conversations, and how many are
/// waiting. The count comes from the server rather than being derived from the
/// page, so a filtered list still knows the true number.
typedef ThreadList = ({List<MessageThread> threads, int unreadThreads});

/// One conversation, opened.
typedef Conversation = ({MessageThread thread, List<Message> messages});

abstract interface class MessagesRepository {
  Future<ThreadList> threads({bool unreadOnly = false});

  Future<Conversation> conversation(String threadId);

  /// Starts a new conversation and returns it.
  Future<MessageThread> start({
    required String subject,
    required String body,
    String? aboutDoctorId,
  });

  Future<Message> send(String threadId, String body);

  /// Marks the clinic's messages in a thread as read.
  Future<void> markRead(String threadId);
}

class HttpMessagesRepository implements MessagesRepository {
  const HttpMessagesRepository(this._api);

  final ApiClient _api;

  @override
  Future<ThreadList> threads({bool unreadOnly = false}) async {
    final body = await _api.get(
      '/threads',
      query: {if (unreadOnly) 'unread': 'true'},
    );

    final map = (body as Map<String, dynamic>?) ?? const {};
    final entries = map['threads'];

    return (
      threads: entries is List
          ? entries
              .whereType<Map<String, dynamic>>()
              .map(MessageThread.fromJson)
              .toList(growable: false)
          : const <MessageThread>[],
      unreadThreads: (map['unreadThreads'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<Conversation> conversation(String threadId) async {
    final body = await _api.get('/threads/$threadId/messages');
    final map = (body as Map<String, dynamic>?) ?? const {};
    final messages = map['messages'];

    return (
      thread: MessageThread.fromJson(
        (map['thread'] as Map<String, dynamic>?) ?? const {},
      ),
      messages: messages is List
          ? messages
              .whereType<Map<String, dynamic>>()
              .map(Message.fromJson)
              .toList(growable: false)
          : const <Message>[],
    );
  }

  @override
  Future<MessageThread> start({
    required String subject,
    required String body,
    String? aboutDoctorId,
  }) async {
    final created = await _api.post('/threads', body: {
      'subject': subject.trim(),
      'body': body.trim(),
      if (aboutDoctorId != null && aboutDoctorId.isNotEmpty)
        'aboutDoctorId': aboutDoctorId,
    });

    return MessageThread.fromJson(
      (created as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  Future<Message> send(String threadId, String body) async {
    final sent = await _api.post(
      '/threads/$threadId/messages',
      body: {'body': body.trim()},
    );

    return Message.fromJson((sent as Map<String, dynamic>?) ?? const {});
  }

  @override
  Future<void> markRead(String threadId) async {
    await _api.post('/threads/$threadId/read');
  }
}
