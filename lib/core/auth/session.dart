/// The signed-in patient, as the API describes them.
class MedicoUser {
  const MedicoUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory MedicoUser.fromJson(Map<String, dynamic> json) {
    return MedicoUser(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
    );
  }

  final String id;
  final String name;
  final String email;

  /// "Ada" — the greeting on the home screen is a hello, not a salutation.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

/// One signed-in session: who, and the two tokens that prove it.
///
/// The access token is short-lived (15 minutes) and is what every request
/// carries. The refresh token is opaque, long-lived, and rotates on every use
/// — the server keeps only a hash of it, and a retired one coming back revokes
/// the whole chain. That last rule is why this class is immutable and replaced
/// wholesale: holding a stale refresh token and retrying with it is precisely
/// the signal the server reads as theft.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: (json['accessToken'] ?? '') as String,
      refreshToken: (json['refreshToken'] ?? '') as String,
      user: MedicoUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final MedicoUser user;

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    MedicoUser? user,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': user.toJson(),
      };
}
