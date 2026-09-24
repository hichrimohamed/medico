import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny, z } from 'zod';

/**
 * Parses and *replaces* the request body with the parsed value, so handlers
 * receive the coerced, stripped object rather than whatever was posted.
 */
export function validateBody<T extends ZodTypeAny>(schema: T) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) return next(result.error);
    req.body = result.data as z.infer<T>;
    next();
  };
}

export function validateQuery<T extends ZodTypeAny>(schema: T) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.query);
    if (!result.success) return next(result.error);
    // Express 5 makes req.query a getter, so the parsed value is stashed
    // alongside rather than assigned over it.
    (req as Request & { valid?: unknown }).valid = result.data;
    next();
  };
}

export function validated<T>(req: Request): T {
  return (req as Request & { valid: T }).valid;
}
