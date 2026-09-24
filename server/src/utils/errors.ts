/**
 * Error codes are a contract, not prose.
 *
 * The Flutter client switches on these to decide what to offer the patient —
 * `account_locked` is what puts a "Reset password" button under the error
 * banner. Renaming one of these is a breaking API change.
 *
 * Mirrors `AuthFailure` in lib/features/auth/data/auth_service.dart.
 */
export type ErrorCode =
  | 'invalid_credentials'
  | 'account_locked'
  | 'email_taken'
  | 'validation_failed'
  | 'unauthorized'
  | 'forbidden'
  | 'not_found'
  | 'slot_taken'
  | 'slot_in_past'
  | 'rate_limited'
  | 'unknown';

export class AppError extends Error {
  readonly status: number;
  readonly code: ErrorCode;
  readonly details?: unknown;

  constructor(
    status: number,
    code: ErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(code: ErrorCode, message: string, details?: unknown) {
    return new AppError(400, code, message, details);
  }

  static unauthorized(message = 'Sign in to continue.') {
    return new AppError(401, 'unauthorized', message);
  }

  static notFound(message = 'Not found.') {
    return new AppError(404, 'not_found', message);
  }

  static conflict(code: ErrorCode, message: string) {
    return new AppError(409, code, message);
  }
}
