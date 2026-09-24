import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import 'auth_service.dart';

/// The real thing: `/auth/*` on the Medico API.
///
/// The screens are unchanged by this class existing — they depend on
/// [AuthService] and on the [AuthFailure] kinds, not on the transport. What
/// this adds is the translation at the boundary: the server's error `code`
/// becomes a kind, and the server's `message` is passed through untouched,
/// because it is already written to be read by a patient.
class HttpAuthService implements AuthService {
  const HttpAuthService({required this.api, required this.session});

  final ApiClient api;
  final SessionController session;

  @override
  Future<void> signIn({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final body = await _call(
      () => api.post(
        '/auth/sign-in',
        body: {'email': email, 'password': password},
        authenticated: false,
      ),
    );
    await session.begin(_sessionFrom(body), remember: remember);
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final body = await _call(
      () => api.post(
        '/auth/sign-up',
        body: {'name': name, 'email': email, 'password': password},
        authenticated: false,
      ),
    );
    // Someone who has just typed their details twice should not have to type
    // them a third time on the next launch.
    await session.begin(_sessionFrom(body), remember: true);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _call(
      () => api.post(
        '/auth/password-reset/request',
        body: {'email': email},
        authenticated: false,
      ),
    );
    // The response is deliberately identical whether or not the address is
    // registered, so there is nothing here to branch on — which is what makes
    // the screen's "If there is a Medico account for that address" honest.
  }

  @override
  Future<void> signInWithProvider(SsoProvider provider) async {
    // The buttons are on the screens; the routes are not on the server. Saying
    // so is better than a spinner that ends in a generic failure.
    throw AuthException(
      AuthFailure.unknown,
      '${provider.label} sign-in is not connected yet. '
      'Use your email and password for now.',
    );
  }

  @override
  Future<void> signOut() async {
    final token = session.session?.refreshToken;

    // Local first, and unconditionally. A patient on a borrowed phone taps
    // Sign out and is signed out — a flat network is not a reason to leave the
    // session sitting on the device.
    await session.end();

    if (token == null || token.isEmpty) return;
    try {
      await api.post(
        '/auth/sign-out',
        body: {'refreshToken': token},
        authenticated: false,
      );
    } on ApiException {
      // The token is revoked here and expires on its own at the far end.
    }
  }

  Session _sessionFrom(dynamic body) {
    if (body is! Map<String, dynamic>) {
      throw const AuthException(
        AuthFailure.unknown,
        'Something went wrong at our end. Try again in a moment.',
      );
    }
    final parsed = Session.fromJson(body);
    if (parsed.accessToken.isEmpty || parsed.refreshToken.isEmpty) {
      throw const AuthException(
        AuthFailure.unknown,
        'Something went wrong at our end. Try again in a moment.',
      );
    }
    return parsed;
  }

  /// Runs [request] and rewrites an [ApiException] as the [AuthException] the
  /// screens already know how to answer.
  Future<dynamic> _call(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw AuthException(_kindOf(error.code), error.message);
    }
  }

  static AuthFailure _kindOf(ApiErrorCode code) {
    return switch (code) {
      ApiErrorCode.invalidCredentials ||
      // A 401 on a credential endpoint is a rejected credential, whatever the
      // generic name of the code.
      ApiErrorCode.unauthorized =>
        AuthFailure.invalidCredentials,
      ApiErrorCode.accountLocked => AuthFailure.accountLocked,
      ApiErrorCode.emailTaken => AuthFailure.emailTaken,
      ApiErrorCode.rateLimited => AuthFailure.rateLimited,
      ApiErrorCode.network => AuthFailure.network,
      _ => AuthFailure.unknown,
    };
  }
}
