// The environment is set in vitest.config.ts, which is the only place that
// runs before this file's own imports pull in dotenv. See the note there.
import mongoose from 'mongoose';
import { afterAll, beforeAll, beforeEach } from 'vitest';
import { connectDatabase, disconnectDatabase } from '../src/db/connect.js';

import '../src/models/user.model.js';
import '../src/models/doctor.model.js';
import '../src/models/appointment.model.js';
import '../src/models/token.model.js';
import '../src/models/message.model.js';

const uri = process.env.MONGODB_URI ?? '';

/**
 * The suite empties every collection between tests, so it must never be
 * pointed at a database somebody is using. This has happened: the env was set
 * too late, the tests connected to the development database, and `beforeEach`
 * wiped a seeded directory, a patient and their appointments.
 *
 * A name that does not end in `_test` is not a mistake to warn about, it is a
 * reason to refuse to start.
 */
function assertDisposable(target: string) {
  const name = target.split('/').pop()?.split('?')[0] ?? '';
  if (!name.endsWith('_test')) {
    throw new Error(
      `Refusing to run: the test suite deletes every document, and ` +
        `"${name}" is not a test database. Expected a name ending in "_test" ` +
        `(configured in vitest.config.ts).`,
    );
  }
}

beforeAll(async () => {
  assertDisposable(uri);
  await connectDatabase(uri);
});

beforeEach(async () => {
  // Collections are emptied rather than dropped: dropping takes the unique
  // indexes with it, and those indexes are the thing under test.
  const collections = await mongoose.connection.db!.collections();
  await Promise.all(collections.map((c) => c.deleteMany({})));
});

afterAll(async () => {
  await disconnectDatabase();
});
