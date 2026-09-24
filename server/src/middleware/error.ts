import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import mongoose from 'mongoose';
import { AppError, type ErrorCode } from '../utils/errors.js';
import { env } from '../config/env.js';

export interface ErrorBody {
  error: { code: ErrorCode; message: string; details?: unknown };
}

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({
    error: { code: 'not_found', message: `No route for ${req.method} ${req.path}.` },
  } satisfies ErrorBody);
}

/**
 * One place that decides what the client sees.
 *
 * Two rules: the patient-facing message never contains a stack trace or a
 * driver error string, and nothing here logs a request body — sign-in bodies
 * contain passwords and this is a health app.
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
) {
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details },
    } satisfies ErrorBody);
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: 'validation_failed',
        message: 'Some of those details need another look.',
        details: err.issues.map((issue) => ({
          field: issue.path.join('.'),
          message: issue.message,
        })),
      },
    } satisfies ErrorBody);
    return;
  }

  if (err instanceof mongoose.Error.ValidationError) {
    res.status(400).json({
      error: { code: 'validation_failed', message: 'Some of those details need another look.' },
    } satisfies ErrorBody);
    return;
  }

  if (!env.isProduction) {
    console.error('[unhandled]', err);
  } else {
    console.error('[unhandled]', err instanceof Error ? err.message : 'non-error thrown');
  }

  res.status(500).json({
    error: { code: 'unknown', message: 'Something went wrong at our end. Try again in a moment.' },
  } satisfies ErrorBody);
}
