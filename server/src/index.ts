import { createApp } from './app.js';
import { env } from './config/env.js';
import { connectDatabase, disconnectDatabase } from './db/connect.js';

// Importing the models registers their schemas and indexes before connect.
import './models/user.model.js';
import './models/doctor.model.js';
import './models/appointment.model.js';
import './models/token.model.js';

async function main() {
  await connectDatabase();
  const server = createApp().listen(env.PORT, () => {
    console.log(`Medico API on :${env.PORT} (${env.NODE_ENV})`);
  });

  // Finish in-flight requests before exiting; a patient mid-booking should not
  // get a socket hang-up because a deploy started.
  const shutdown = async (signal: string) => {
    console.log(`${signal} received, shutting down`);
    server.close(async () => {
      await disconnectDatabase();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
}

main().catch((error) => {
  console.error('Failed to start', error);
  process.exit(1);
});
