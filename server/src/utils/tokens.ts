import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export interface AccessTokenClaims {
  sub: string;
  email: string;
}

export function signAccessToken(claims: AccessTokenClaims): string {
  return jwt.sign(claims, env.JWT_ACCESS_SECRET, {
    expiresIn: env.ACCESS_TOKEN_TTL,
    issuer: 'medico',
    audience: 'medico-app',
  } as jwt.SignOptions);
}

export function verifyAccessToken(token: string): AccessTokenClaims {
  return jwt.verify(token, env.JWT_ACCESS_SECRET, {
    issuer: 'medico',
    audience: 'medico-app',
  }) as AccessTokenClaims;
}

/**
 * Refresh tokens are opaque random strings, not JWTs.
 *
 * A JWT refresh token is self-validating, which is exactly the wrong property:
 * it cannot be revoked before it expires. An opaque token means every refresh
 * consults the database, and "sign out everywhere" actually works.
 */
export function createRefreshToken(): { token: string; hash: string } {
  const token = randomBytes(48).toString('base64url');
  return { token, hash: hashToken(token) };
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function refreshExpiry(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}
