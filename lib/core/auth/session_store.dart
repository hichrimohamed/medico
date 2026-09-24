import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

/// Where a session survives the app being closed.
///
/// An interface, because "keep me signed in" is a promise about storage and
/// the tests should be able to check it without a platform channel.
abstract interface class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

/// The real one.
///
/// **This is not secure storage.** `shared_preferences` is a plist on iOS and
/// an XML file on Android: readable on a jailbroken or rooted device, and
/// included in an unencrypted backup. What is kept here is a refresh token,
/// which is revocable and rotates on every use — a stolen one is detectable
/// and killable, unlike a password. A Keychain-backed store is the right home
/// for it and the swap is this one class; see `TODO(secure-storage)`.
class PrefsSessionStore implements SessionStore {
  PrefsSessionStore({SharedPreferences? preferences}) : _cached = preferences;

  static const String _key = 'medico.session';

  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _cached ??= await SharedPreferences.getInstance();

  @override
  Future<Session?> read() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = Session.fromJson(decoded);
      // A half-written record is worse than none: it would send the patient to
      // the home screen and fail on the first request.
      if (session.refreshToken.isEmpty) return null;
      return session;
    } on FormatException {
      // Written by an older version, or corrupted. Sign-in is the recovery.
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    await (await _prefs).setString(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await (await _prefs).remove(_key);
  }
}

/// For tests and for "do not keep me signed in", which is the same requirement
/// stated two ways: this session lives exactly as long as the process.
class InMemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
