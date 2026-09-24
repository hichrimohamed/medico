import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { env } from '../../config/env.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { UserModel } from '../../models/user.model.js';
import { AppError } from '../../utils/errors.js';
import * as service from './auth.service.js';
import {
  refreshSchema,
  resetConfirmSchema,
  resetRequestSchema,
  signInSchema,
  signUpSchema,
} from './auth.schemas.js';

/**
 * Credential endpoints are rate limited per IP.
 *
 * Account lockout alone is not enough: it protects one account from many
 * guesses, and does nothing about one guess against many accounts. Disabled
 * under test so the suite is not throttled by its own speed.
 */
const credentialLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: env.NODE_ENV === 'test' ? 0 : 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
  handler: (_req, res) => {
    res.status(429).json({
      error: {
        code: 'rate_limited',
        message: 'Too many attempts. Wait a few minutes and try again.',
      },
    });
  },
});

export const authRouter = Router();

authRouter.post('/sign-up', credentialLimiter, validateBody(signUpSchema), async (req, res) => {
  res.status(201).json(await service.signUp(req.body));
});

authRouter.post('/sign-in', credentialLimiter, validateBody(signInSchema), async (req, res) => {
  res.json(await service.signIn(req.body));
});

authRouter.post('/refresh', validateBody(refreshSchema), async (req, res) => {
  res.json(await service.refresh(req.body.refreshToken));
});

authRouter.post('/sign-out', validateBody(refreshSchema), async (req, res) => {
  await service.signOut(req.body.refreshToken);
  res.status(204).end();
});

authRouter.post('/sign-out-everywhere', requireAuth, async (req, res) => {
  await service.signOutEverywhere(req.userId!);
  res.status(204).end();
});

authRouter.post(
  '/password-reset/request',
  credentialLimiter,
  validateBody(resetRequestSchema),
  async (req, res) => {
    const { token } = await service.requestPasswordReset(req.body.email);

    // The response is identical either way. Outside production the token comes
    // back so the flow can be exercised without a mail provider.
    res.json({
      message:
        'If there is a Medico account for that address, the reset link is on its way.',
      ...(env.isProduction ? {} : { devToken: token }),
    });
  },
);

authRouter.post(
  '/password-reset/confirm',
  credentialLimiter,
  validateBody(resetConfirmSchema),
  async (req, res) => {
    await service.confirmPasswordReset(req.body.token, req.body.password);
    res.status(204).end();
  },
);

authRouter.get('/me', requireAuth, async (req, res) => {
  const user = await UserModel.findById(req.userId);
  if (!user) throw AppError.unauthorized();
  res.json(user.toJSON());
});
