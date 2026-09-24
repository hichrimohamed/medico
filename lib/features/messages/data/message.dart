import '../../doctors/data/doctor.dart';

/// Which side wrote a message.
///
/// A side, not a person: the clinic is a rota, and a reply comes from whoever
/// is on it. Naming an individual in the bubble would imply that individual is
/// the one reading the thread.
enum MessageAuthor {
  patient('patient'),
  clinic('clinic'),
  unknown('');

  const MessageAuthor(this.wire);
  final String wire;

  static MessageAuthor parse(Object? value) {
    for (final author in MessageAuthor.values) {
      if (author.wire == value) return author;
    }
    return MessageAuthor.unknown;
  }
}

class Message {
  const Message({
    required this.id,
    required this.from,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? '') as String,
      from: MessageAuthor.parse(json['from']),
      body: (json['body'] ?? '') as String,
      sentAt: _instant(json['sentAt']),
      readAt: json['readAt'] == null ? null : _instant(json['readAt']),
    );
  }

  final String id;
  final MessageAuthor from;
  final String body;

  /// The instant it was sent, in UTC.
  ///
  /// Rendered in the *device's* timezone, unlike an appointment time. An
  /// appointment is a wall-clock arrangement with a clinic; a message is a
  /// thing that happened, and "11:04" should mean 11:04 where the patient was
  /// standing when it arrived.
  final DateTime sentAt;

  final DateTime? readAt;

  bool get fromPatient => from == MessageAuthor.patient;

  /// "11:04", local.
  String get timeLabel {
    final at = sentAt.toLocal();
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  /// The day it landed on, local, for grouping.
  DateTime get day {
    final at = sentAt.toLocal();
    return DateTime(at.year, at.month, at.day);
  }
}

/// A conversation with the practice.
class MessageThread {
  const MessageThread({
    required this.id,
    required this.subject,
    required this.lastMessageAt,
    this.aboutDoctor,
    this.lastMessagePreview = '',
    this.lastMessageFrom = MessageAuthor.clinic,
    this.unreadCount = 0,
    this.isClosed = false,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final doctor = json['aboutDoctorId'];

    return MessageThread(
      id: (json['id'] ?? '') as String,
      subject: (json['subject'] ?? '') as String,
      // Populated when the thread is about an appointment; a plain id — or
      // nothing — when it is about the practice generally.
      aboutDoctor:
          doctor is Map<String, dynamic> ? Doctor.fromJson(doctor) : null,
      lastMessageAt: _instant(json['lastMessageAt']),
      lastMessagePreview: (json['lastMessagePreview'] ?? '') as String,
      lastMessageFrom: MessageAuthor.parse(json['lastMessageFrom']),
      unreadCount: (json['unreadForPatient'] as num?)?.toInt() ?? 0,
      isClosed: json['closedAt'] != null,
    );
  }

  final String id;

  /// What the patient will recognise in a list — "Blood pressure review".
  final String subject;

  /// The doctor this is *about*, where there is one. Not the author of the
  /// replies.
  final Doctor? aboutDoctor;

  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final MessageAuthor lastMessageFrom;

  /// Messages from the clinic not yet opened.
  final int unreadCount;

  /// Closed conversations stay readable; they take no new messages.
  final bool isClosed;

  bool get hasUnread => unreadCount > 0;

  /// "Now", "11:04", "Yesterday", "14 Sep" — a list row has one line for this,
  /// so it gets shorter as the thing gets older.
  String get whenLabel {
    final at = lastMessageAt.toLocal();
    final now = DateTime.now();
    final elapsed = now.difference(at);

    if (elapsed.inMinutes < 1) return 'Now';

    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(at.year, at.month, at.day);

    if (that == today) {
      return '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
    }
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (at.year == now.year) {
      return '${at.day} ${kMonthNames[at.month - 1].substring(0, 3)}';
    }
    return '${at.day} ${kMonthNames[at.month - 1].substring(0, 3)} ${at.year}';
  }
}

DateTime _instant(Object? value) =>
    DateTime.tryParse(value is String ? value : '')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
