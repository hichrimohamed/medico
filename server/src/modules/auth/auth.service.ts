import { randomBytes } from 'node:crypto';
import { AppError } from '../../utils/errors.js';
import { hashPassword, verifyPassword } from '../../utils/password.js';
import {
  createRefreshToken,
  hashToken,
  refreshExpiry,
  signAccessToken,
} from '../../utils/tokens.js';
import { UserModel, type UserDoc } from '../../models/user.model.js';
import {
  PasswordResetModel,
  RefreshTokenModel,
} from '../../models/token.model.js';
import type { SignInInput, SignUpInput } from './auth.schemas.js';

/** Failed attempts before the account locks, and for how long. */
const MAX_FAILED_ATTEMPTS = 5;
const LOCK_DURATION_MS = 15 * 60 * 1000;
const RESET_TTL_MS = 30 * 60 * 1000;

export interface Session {
  accessToken: string;
  refreshToken: string;
  user: { id: string; name: string; email: string };
}

async function issueSession(user: UserDoc): Promise<Session> {
  const { token, hash } = createRefreshToken();
  await RefreshTokenModel.create({
    userId: user._id,
    tokenHash: hash,
    expiresAt: refreshExpiry(),
  });

  return {
    accessToken: signAccessToken({ sub: String(user._id), email: user.email }),
    refreshToken: token,
    user: { id: String(user._id), name: user.name, email: user.email },
  };
}

export async function signUp(input: SignUpInput): Promise<Session> {
  const existing = await UserModel.findOne({ email: input.email }).lean();
  if (existing) {
    throw AppError.conflict(
      'email_taken',
      'There is already a Medico account with this email. Sign in instead, or reset the password.',
    );
  }

  const user = await UserModel.create({
    name: input.name,
    email: input.email,
    passwordHash: await hashPassword(input.password),
  });

  return issueSession(user);
}

export async function signIn(input: SignInInput): Promise<Session> {
  const user = await UserModel.findOne({ email: input.email }).select(
    '+passwordHash +failedSignInCount +lockedUntil',
  );

  // Same message and same work whether or not the account exists. Returning
  // early here would let anyone probe which emails are registered patients,
  // and the timing difference alone is a disclosure.
  if (!user) {
    await hashPassword(input.password);
    throw new AppError(
      401,
      'invalid_credentials',
      "That email and password don't match. Check the password, or reset it if you are not sure.",
    );
  }

  if (user.lockedUntil && user.lockedUntil.getTime() > Date.now()) {
    throw new AppError(
      423,
      'account_locked',
      'This account is locked after too many attempts. Reset your password to unlock it, or call the clinic on 0800 555 100.',
    );
  }

  const ok = await verifyPassword(input.password, user.passwordHash);

  if (!ok) {
    const failed = (user.failedSignInCount ?? 0) + 1;
    const locking = failed >= MAX_FAILED_ATTEMPTS;
    await UserModel.updateOne(
      { _id: user._id },
      {
        failedSignInCount: locking ? 0 : failed,
        lockedUntil: locking ? new Date(Date.now() + LOCK_DURATION_MS) : null,
      },
    );

    if (locking) {
      throw new AppError(
        423,
        'account_locked',
        'This account is locked after too many attempts. Reset your password to unlock it, or call the clinic on 0800 555 100.',
      );
    }
    throw new AppError(
      401,
      'invalid_credentials',
      "That email and password don't match. Check the password, or reset it if you are not sure.",
    );
  }

  if (user.failedSignInCount) {
    await UserModel.updateOne(
      { _id: user._id },
      { failedSignInCount: 0, lockedUntil: null },
    );
  }

  return issueSession(user);
}

/**
 * Rotates the refresh token on every use.
 *
 * If a token that has already been rotated comes back, either the client is
 * replaying or someone else has the token. Both cases are handled the same
 * way: revoke every live session for that user and make them sign in again.
 */
export async function refresh(presented: string): Promise<Session> {
  const hash = hashToken(presented);
  const record = await RefreshTokenModel.findOne({ tokenHash: hash });

  if (!record) throw AppError.unauthorized('Sign in again to continue.');

  if (record.revokedAt || record.replacedByHash) {
    await RefreshTokenModel.updateMany(
      { userId: record.userId, revokedAt: null },
      { revokedAt: new Date() },
    );
    throw AppError.unauthorized(
      'For your security we ended that session. Sign in again.',
    );
  }

  if (record.expiresAt.getTime() <= Date.now()) {
    throw AppError.unauthorized('Your session has expired. Sign in again.');
  }

  const user = await UserModel.findById(record.userId);
  if (!user) throw AppError.unauthorized('Sign in again to continue.');

  const session = await issueSession(user);
  await RefreshTokenModel.updateOne(
    { _id: record._id },
    { revokedAt: new Date(), replacedByHash: hashToken(session.refreshToken) },
  );

  return session;
}

export async function signOut(presented: string): Promise<void> {
  await RefreshTokenModel.updateOne(
    { tokenHash: hashToken(presented), revokedAt: null },
    { revokedAt: new Date() },
  );
}

export async function signOutEverywhere(userId: string): Promise<void> {
  await RefreshTokenModel.updateMany(
    { userId, revokedAt: null },
    { revokedAt: new Date() },
  );
}

/**
 * Always resolves, whether or not the address belongs to an account.
 *
 * The screen's copy — "If there is a Medico account for that address" — is a
 * deliberate non-answer, and it is only true if the server behaves this way
 * too. Returns the token in development so the flow is testable without mail.
 */
export async function requestPasswordReset(
  email: string,
): Promise<{ token: string | null }> {
  const user = await UserModel.findOne({ email });
  if (!user) return { token: null };

  const token = randomBytes(32).toString('base64url');
  await PasswordResetModel.create({
    userId: user._id,
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + RESET_TTL_MS),
  });

  // TODO(mail): hand to the transactional mail provider. Until then the route
  // only surfaces this outside production.
  return { token };
}

export async function confirmPasswordReset(
  token: string,
  password: string,
): Promise<void> {
  const record = await PasswordResetModel.findOne({ tokenHash: hashToken(token) });

  if (!record || record.usedAt || record.expiresAt.getTime() <= Date.now()) {
    throw AppError.badRequest(
      'invalid_credentials',
      'That reset link has expired. Ask for a new one.',
    );
  }

  await UserModel.updateOne(
    { _id: record.userId },
    {
      passwordHash: await hashPassword(password),
      failedSignInCount: 0,
      lockedUntil: null,
    },
  );
  await PasswordResetModel.updateOne({ _id: record._id }, { usedAt: new Date() });

  // A password change ends every other session. Whoever forced the reset
  // should not still be signed in on another device.
  await signOutEverywhere(String(record.userId));
}
