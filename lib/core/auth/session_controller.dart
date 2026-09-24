import 'package:flutter/foundation.dart';

import 'session.dart';
import 'session_store.dart';

/// Who is signed in, for the whole app.
///
/// One object owns the answer so that a token rotated by a background request
/// and the name in the greeting cannot disagree. Everything that changes the
/// answer — signing in, rotating a token, signing out, a refresh the server
/// refused — goes through here and notifies.
class SessionController extends ChangeNotifier {
  SessionController({SessionStore? store})
      : _store = store ?? PrefsSessionStore();

  final SessionStore _store;

  Session? _session;
  bool _restored = false;
  bool _persisted = false;

  Session? get session => _session;
  MedicoUser? get user => _session?.user;
  bool get isSignedIn => _session != null;

  /// False until [restore] has finished. The app shows nothing but a splash
  /// until then rather than flashing the sign-in screen at a patient who is
  /// already signed in.
  bool get isRestored => _restored;

  /// Reads a remembered session from disk. Safe to call twice.
  Future<void> restore() async {
    if (_restored) return;
    _session = await _store.read();
    _persisted = _session != null;
    _restored = true;
    notifyListeners();
  }

  /// A fresh sign-in or sign-up.
  ///
  /// [remember] is the "Keep me signed in" checkbox: when it is off the
  /// session lives in memory only, so closing the app ends it.
  Future<void> begin(Session session, {required bool remember}) async {
    _session = session;
    _persisted = remember;
    _restored = true;
    if (remember) {
      await _store.write(session);
    } else {
      await _store.clear();
    }
    notifyListeners();
  }

  /// A rotated token pair. Only rewrites storage if this session came from it,
  /// so "do not keep me signed in" survives a refresh.
  Future<void> update(Session session) async {
    _session = session;
    if (_persisted) await _store.write(session);
    notifyListeners();
  }

  /// Signed out, or a refresh the server refused. Always clears storage: a
  /// revoked token left on disk would send the patient to the home screen on
  /// next launch and bounce them straight back out.
  Future<void> end() async {
    _session = null;
    _persisted = false;
    _restored = true;
    await _store.clear();
    notifyListeners();
  }
}
