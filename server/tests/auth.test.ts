import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { UserModel } from '../src/models/user.model.js';
import { registerPatient } from './helpers.js';

const app = createApp();
const credentials = { email: 'ada@example.com', password: 'hunter2hunter2' };

describe('auth', () => {
  it('signs a new patient up and returns a usable session', async () => {
    const session = await registerPatient(app, credentials.email);

    expect(session.accessToken).toBeTruthy();
    expect(session.refreshToken).toBeTruthy();

    const me = await request(app)
      .get('/api/v1/auth/me')
      .set('authorization', `Bearer ${session.accessToken}`)
      .expect(200);

    expect(me.body.email).toBe(credentials.email);
    // The whole point of `select: false` on the hash.
    expect(me.body.passwordHash).toBeUndefined();
  });

  it('refuses a second account on the same email', async () => {
    await registerPatient(app, credentials.email);

    const res = await request(app)
      .post('/api/v1/auth/sign-up')
      .send({ name: 'Someone Else', email: credentials.email, password: 'hunter2hunter2' })
      .expect(409);

    expect(res.body.error.code).toBe('email_taken');
  });

  it('answers a wrong password and an unknown email identically', async () => {
    await registerPatient(app, credentials.email);

    const wrongPassword = await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: credentials.email, password: 'not-the-password' })
      .expect(401);

    const unknownEmail = await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: 'nobody@example.com', password: 'not-the-password' })
      .expect(401);

    // Any difference here is a way to enumerate who is a patient here.
    expect(wrongPassword.body).toEqual(unknownEmail.body);
    expect(wrongPassword.body.error.code).toBe('invalid_credentials');
  });

  it('locks the account after five failures and says how to recover', async () => {
    await registerPatient(app, credentials.email);

    for (let attempt = 0; attempt < 4; attempt++) {
      await request(app)
        .post('/api/v1/auth/sign-in')
        .send({ email: credentials.email, password: 'wrong' })
        .expect(401);
    }

    const locked = await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: credentials.email, password: 'wrong' })
      .expect(423);

    expect(locked.body.error.code).toBe('account_locked');
    expect(locked.body.error.message).toContain('Reset your password');

    // Even the right password is refused while locked.
    const stillLocked = await request(app)
      .post('/api/v1/auth/sign-in')
      .send(credentials)
      .expect(423);
    expect(stillLocked.body.error.code).toBe('account_locked');
  });

  it('forgets past failures once a sign-in succeeds', async () => {
    await registerPatient(app, credentials.email);

    await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: credentials.email, password: 'wrong' })
      .expect(401);

    await request(app).post('/api/v1/auth/sign-in').send(credentials).expect(200);

    const user = await UserModel.findOne({ email: credentials.email }).select(
      '+failedSignInCount',
    );
    expect(user?.failedSignInCount).toBe(0);
  });

  it('rotates the refresh token and retires the old one', async () => {
    const session = await registerPatient(app, credentials.email);

    const refreshed = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(200);

    expect(refreshed.body.refreshToken).not.toBe(session.refreshToken);

    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: refreshed.body.refreshToken })
      .expect(200);
  });

  /**
   * Replay is the signal that a refresh token has been copied. The honest
   * client and the thief both hold one; the only safe move is to end every
   * session and make the real patient sign in.
   */
  it('kills every session when a retired refresh token comes back', async () => {
    const session = await registerPatient(app, credentials.email);

    const rotated = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(200);

    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(401);

    // The token the honest client holds is now dead too.
    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken })
      .expect(401);
  });

  it('stops a signed-out refresh token working', async () => {
    const session = await registerPatient(app, credentials.email);

    await request(app)
      .post('/api/v1/auth/sign-out')
      .send({ refreshToken: session.refreshToken })
      .expect(204);

    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(401);
  });

  it('never reveals whether a reset address is registered', async () => {
    await registerPatient(app, credentials.email);

    const known = await request(app)
      .post('/api/v1/auth/password-reset/request')
      .send({ email: credentials.email })
      .expect(200);

    const unknown = await request(app)
      .post('/api/v1/auth/password-reset/request')
      .send({ email: 'nobody@example.com' })
      .expect(200);

    expect(known.body.message).toBe(unknown.body.message);
  });

  it('resets the password, unlocks the account and ends other sessions', async () => {
    const session = await registerPatient(app, credentials.email);

    const requested = await request(app)
      .post('/api/v1/auth/password-reset/request')
      .send({ email: credentials.email })
      .expect(200);

    await request(app)
      .post('/api/v1/auth/password-reset/confirm')
      .send({ token: requested.body.devToken, password: 'a-brand-new-password' })
      .expect(204);

    await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: credentials.email, password: 'a-brand-new-password' })
      .expect(200);

    // Whoever forced the reset must not still be signed in elsewhere.
    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken })
      .expect(401);
  });

  it('will not reuse a reset token', async () => {
    await registerPatient(app, credentials.email);

    const requested = await request(app)
      .post('/api/v1/auth/password-reset/request')
      .send({ email: credentials.email })
      .expect(200);

    await request(app)
      .post('/api/v1/auth/password-reset/confirm')
      .send({ token: requested.body.devToken, password: 'a-brand-new-password' })
      .expect(204);

    await request(app)
      .post('/api/v1/auth/password-reset/confirm')
      .send({ token: requested.body.devToken, password: 'another-password' })
      .expect(400);
  });

  it('rejects a missing or malformed bearer token', async () => {
    await request(app).get('/api/v1/auth/me').expect(401);
    await request(app)
      .get('/api/v1/auth/me')
      .set('authorization', 'Bearer not-a-jwt')
      .expect(401);
  });

  it('reports validation problems per field', async () => {
    const res = await request(app)
      .post('/api/v1/auth/sign-up')
      .send({ name: 'A', email: 'not-an-email', password: 'short' })
      .expect(400);

    expect(res.body.error.code).toBe('validation_failed');
    const fields = res.body.error.details.map((d: { field: string }) => d.field);
    expect(fields).toEqual(expect.arrayContaining(['name', 'email', 'password']));
  });
});
