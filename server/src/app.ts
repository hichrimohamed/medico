import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { doctorsRouter } from './modules/doctors/doctors.routes.js';
import { appointmentsRouter } from './modules/appointments/appointments.routes.js';
import { meRouter } from './modules/me/me.routes.js';
import { messagesRouter } from './modules/messages/messages.routes.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(
    cors({
      // A native app sends no Origin header, so `!origin` is allowed. Browser
      // callers must be on the configured list.
      origin(origin, callback) {
        if (!origin || env.corsOrigins.length === 0) return callback(null, true);
        callback(null, env.corsOrigins.includes(origin));
      },
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '100kb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptime: process.uptime() });
  });

  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/doctors', doctorsRouter);
  app.use('/api/v1/appointments', appointmentsRouter);
  app.use('/api/v1/me', meRouter);
  app.use('/api/v1/threads', messagesRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
