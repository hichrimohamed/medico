import 'dotenv/config';
import { z } from 'zod';

/**
 * Configuration is validated once, at boot.
 *
 * A server that starts with a missing JWT secret and only discovers it when
 * the first patient signs in has turned a deployment mistake into an outage.
 * This throws before the port is bound.
 */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  MONGODB_URI: z.string().min(1),

  // Separate secrets by design: a leaked access secret must not be able to
  // mint refresh tokens.
  JWT_ACCESS_SECRET: z.string().min(32, 'use at least 32 characters'),
  JWT_REFRESH_SECRET: z.string().min(32, 'use at least 32 characters'),

  ACCESS_TOKEN_TTL: z.string().default('15m'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),

  CORS_ORIGINS: z.string().default(''),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  const detail = parsed.error.issues
    .map((issue) => `  ${issue.path.join('.')}: ${issue.message}`)
    .join('\n');
  throw new Error(`Invalid environment configuration:\n${detail}`);
}

export const env = {
  ...parsed.data,
  isProduction: parsed.data.NODE_ENV === 'production',
  corsOrigins: parsed.data.CORS_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
};

export type Env = typeof env;
