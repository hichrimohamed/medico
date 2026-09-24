import type { NextFunction, Request, Response } from 'express';
import { AppError } from '../utils/errors.js';
import { verifyAccessToken } from '../utils/tokens.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      userId?: string;
      userEmail?: string;
    }
  }
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.header('authorization') ?? '';
  const [scheme, token] = header.split(' ');

  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    return next(AppError.unauthorized('Sign in to continue.'));
  }

  try {
    const claims = verifyAccessToken(token);
    req.userId = claims.sub;
    req.userEmail = claims.email;
    next();
  } catch {
    // Expired and malformed are deliberately the same answer: the client's
    // move is identical either way — refresh, then retry.
    next(AppError.unauthorized('Your session has expired. Sign in again.'));
  }
}
