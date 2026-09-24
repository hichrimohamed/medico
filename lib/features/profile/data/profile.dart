import '../../doctors/data/doctor.dart';

/// The signed-in patient, as the profile screen needs them.
///
/// The three counts come from the server rather than from the lengths of lists
/// this screen would otherwise have to fetch: a profile that showed "3 saved
/// doctors" by downloading three doctors would be three requests to render one
/// number.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.memberSince,
    this.savedDoctors = 0,
    this.upcomingAppointments = 0,
    this.unreadThreads = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      memberSince:
          DateTime.tryParse((json['createdAt'] ?? '') as String)?.toLocal(),
      savedDoctors: (json['savedDoctors'] as num?)?.toInt() ?? 0,
      upcomingAppointments:
          (json['upcomingAppointments'] as num?)?.toInt() ?? 0,
      unreadThreads: (json['unreadThreads'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String email;

  /// When the account was opened. Null when the server did not say.
  final DateTime? memberSince;

  final int savedDoctors;
  final int upcomingAppointments;
  final int unreadThreads;

  /// "Ada" — the greeting elsewhere uses the same rule.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// "September 2026", or null when the date is unknown.
  String? get memberSinceLabel {
    final at = memberSince;
    if (at == null) return null;
    return '${kMonthNames[at.month - 1]} ${at.year}';
  }
}
