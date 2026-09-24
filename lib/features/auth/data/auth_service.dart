import 'dart:async';

/// Why a sign-in attempt failed. The kind drives the recovery the UI offers,
/// which is why it is an enum and not just a string.
///
/// These mirror the `code` values in `server/src/utils/errors.ts`. The mapping
/// lives in [HttpAuthService]; renaming a code on either side is a breaking
/// change to the pair.
enum AuthFailure {
  invalidCredentials,
  accountLocked,
  emailTaken,
  rateLimited,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.kind, this.message);

  final AuthFailure kind;

  /// Patient-facing. Says what happened and what to do next.
  final String message;

  @override
  String toString() => 'AuthException($kind): $message';
}

enum SsoProvider {
  google('Google'),
  apple('Apple');

  const SsoProvider(this.label);
  final String label;
}

abstract interface class AuthService {
  /// [remember] is the "Keep me signed in" checkbox. Off means the session is
  /// held in memory only and closing the app ends it.
  Future<void> signIn({
    required String email,
    required String password,
    bool remember,
  });

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signInWithProvider(SsoProvider provider);

  Future<void> sendPasswordReset(String email);

  /// Ends the session on the server as well as here. Never throws: a patient
  /// who taps Sign out is signed out locally whatever the network says.
  Future<void> signOut();
}
