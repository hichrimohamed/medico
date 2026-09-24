/// The server's error codes, as a type.
///
/// Every failure from the API arrives as `{ "error": { code, message } }`, and
/// the `code` is a contract — `server/src/utils/errors.ts` says renaming one is
/// a breaking change. Parsing it into an enum here means a screen switches on
/// a value the compiler knows about instead of comparing strings, and an
/// unrecognised code degrades to [ApiErrorCode.unknown] rather than throwing
/// inside the error path.
enum ApiErrorCode {
  invalidCredentials('invalid_credentials'),
  accountLocked('account_locked'),
  emailTaken('email_taken'),
  validationFailed('validation_failed'),
  unauthorized('unauthorized'),
  forbidden('forbidden'),
  notFound('not_found'),
  slotTaken('slot_taken'),
  slotInPast('slot_in_past'),
  rateLimited('rate_limited'),

  /// The server said something we do not have a case for.
  unknown('unknown'),

  /// We never reached the server at all. Not a server code — the client's own,
  /// because "no network" and "server said no" need different answers.
  network('network');

  const ApiErrorCode(this.wire);

  /// The string on the wire.
  final String wire;

  static ApiErrorCode parse(String? value) {
    for (final code in ApiErrorCode.values) {
      if (code.wire == value) return code;
    }
    return ApiErrorCode.unknown;
  }
}

/// A failed API call.
///
/// [message] comes from the server, which writes its messages to be shown to a
/// patient as they are — they say what happened and what to do next. Only when
/// the server never answered do we substitute our own.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status, this.details});

  final ApiErrorCode code;
  final String message;
  final int? status;
  final Object? details;

  static const ApiException offline = ApiException(
    ApiErrorCode.network,
    "We couldn't reach Medico. Check your connection and try again.",
  );

  static const ApiException malformed = ApiException(
    ApiErrorCode.unknown,
    'Something went wrong at our end. Try again in a moment.',
  );

  @override
  String toString() => 'ApiException(${code.wire}, $status): $message';
}
