import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    // Set here, not in a setup file.
    //
    // `tests/setup.ts` used to do this with `process.env.X ??= …` at the top
    // of the module. In ESM every `import` in a file is evaluated *before* its
    // statements, so `src/db/connect.js` — and through it `config/env.ts` and
    // its `dotenv/config` — had already loaded the real `.env` by the time
    // those lines ran. `??=` then found MONGODB_URI set to the development
    // database and left it, and `beforeEach`'s "empty every collection"
    // emptied the developer's own data. Vitest applies this before the test
    // module graph loads, which is the only place early enough.
    env: {
      NODE_ENV: 'test',
      MONGODB_URI: 'mongodb://127.0.0.1:27017/medico_test',
      JWT_ACCESS_SECRET: 'test-access-secret-that-is-long-enough-000000',
      JWT_REFRESH_SECRET: 'test-refresh-secret-that-is-long-enough-00000',
      CORS_ORIGINS: '',
    },
    setupFiles: ['./tests/setup.ts'],
    // Suites share one Mongo database, so they must not interleave.
    fileParallelism: false,
    testTimeout: 20_000,
  },
});
