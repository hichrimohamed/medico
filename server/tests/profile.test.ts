import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { AppointmentModel } from '../src/models/appointment.model.js';
import { MessageModel, ThreadModel } from '../src/models/message.model.js';
import { RefreshTokenModel } from '../src/models/token.model.js';
import { UserModel } from '../src/models/user.model.js';
import { futureSlot, makeDoctor, registerPatient } from './helpers.js';

const app = createApp();
const password = 'hunter2hunter2';

async function patient(email = 'ada@example.com') {
  const session = await registerPatient(app, email);
  return {
    id: session.user.id,
    refreshToken: session.refreshToken,
    auth: { authorization: `Bearer ${session.accessToken}` },
  };
}

/** A patient with one of everything hanging off them. */
async function patientWithHistory() {
  const ada = await patient();
  const doctor = await makeDoctor();

  await request(app)
    .post('/api/v1/appointments')
    .set(ada.auth)
    .send({ doctorId: String(doctor._id), startsAt: futureSlot().toISOString() })
    .expect(201);

  await request(app)
    .post('/api/v1/threads')
    .set(ada.auth)
    .send({ subject: 'A question', body: 'Something I wanted to ask.' })
    .expect(201);

  await request(app).put(`/api/v1/me/favourites/${doctor._id}`).set(ada.auth).expect(204);

  return { ...ada, doctor };
}

describe('profile', () => {
  it('returns the patient and the counts the screen shows', async () => {
    const ada = await patientWithHistory();

    const res = await request(app).get('/api/v1/me').set(ada.auth).expect(200);

    expect(res.body.name).toBe('Ada Lovelace');
    expect(res.body.email).toBe('ada@example.com');
    expect(res.body.savedDoctors).toBe(1);
    expect(res.body.upcomingAppointments).toBe(1);
    expect(res.body.unreadThreads).toBe(0);
    expect(res.body.createdAt).toBeTruthy();
    // The hash never leaves the database.
    expect(res.body.passwordHash).toBeUndefined();
  });

  it('renames the patient', async () => {
    const ada = await patient();

    const res = await request(app)
      .patch('/api/v1/me')
      .set(ada.auth)
      .send({ name: '  Ada King  ' })
      .expect(200);

    expect(res.body.name).toBe('Ada King');
    expect((await UserModel.findById(ada.id))!.name).toBe('Ada King');
  });

  it('refuses a name that is not one', async () => {
    const ada = await patient();

    const res = await request(app)
      .patch('/api/v1/me')
      .set(ada.auth)
      .send({ name: ' A ' })
      .expect(400);

    expect(res.body.error.code).toBe('validation_failed');
  });

  it('changes the password, and the new one works', async () => {
    const ada = await patient();

    await request(app)
      .post('/api/v1/me/password')
      .set(ada.auth)
      .send({ currentPassword: password, newPassword: 'a-longer-new-password' })
      .expect(204);

    await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: 'ada@example.com', password: 'a-longer-new-password' })
      .expect(200);

    await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: 'ada@example.com', password })
      .expect(401);
  });

  it('a password change ends every other session', async () => {
    const ada = await patient();
    expect(await RefreshTokenModel.countDocuments({ userId: ada.id })).toBe(1);

    await request(app)
      .post('/api/v1/me/password')
      .set(ada.auth)
      .send({ currentPassword: password, newPassword: 'a-longer-new-password' })
      .expect(204);

    // The token the phone is holding is dead: a password change is usually the
    // answer to somebody else being in the account.
    expect(await RefreshTokenModel.countDocuments({ userId: ada.id })).toBe(0);
    await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: ada.refreshToken })
      .expect(401);
  });

  it('will not change a password without the current one', async () => {
    const ada = await patient();

    const res = await request(app)
      .post('/api/v1/me/password')
      .set(ada.auth)
      .send({ currentPassword: 'not-my-password', newPassword: 'a-longer-new-password' })
      .expect(400);

    expect(res.body.error.code).toBe('invalid_credentials');
    // And the old one still works, so a wrong guess changes nothing.
    await request(app)
      .post('/api/v1/auth/sign-in')
      .send({ email: 'ada@example.com', password })
      .expect(200);
  });

  describe('deleting the account', () => {
    it('takes everything the patient left behind with it', async () => {
      const ada = await patientWithHistory();

      await request(app)
        .delete('/api/v1/me')
        .set(ada.auth)
        .send({ password })
        .expect(204);

      expect(await UserModel.countDocuments({ _id: ada.id })).toBe(0);
      expect(await AppointmentModel.countDocuments({ patientId: ada.id })).toBe(0);
      expect(await ThreadModel.countDocuments({ patientId: ada.id })).toBe(0);
      expect(await MessageModel.countDocuments({})).toBe(0);
      expect(await RefreshTokenModel.countDocuments({ userId: ada.id })).toBe(0);
    });

    it('hands the appointment slot back to the clinic', async () => {
      const doctor = await makeDoctor();
      const slot = futureSlot();

      const ada = await patient('ada@example.com');
      await request(app)
        .post('/api/v1/appointments')
        .set(ada.auth)
        .send({ doctorId: String(doctor._id), startsAt: slot.toISOString() })
        .expect(201);

      // Somebody else cannot have that time while Ada holds it.
      const grace = await patient('grace@example.com');
      await request(app)
        .post('/api/v1/appointments')
        .set(grace.auth)
        .send({ doctorId: String(doctor._id), startsAt: slot.toISOString() })
        .expect(409);

      await request(app).delete('/api/v1/me').set(ada.auth).send({ password }).expect(204);

      // Now they can.
      await request(app)
        .post('/api/v1/appointments')
        .set(grace.auth)
        .send({ doctorId: String(doctor._id), startsAt: slot.toISOString() })
        .expect(201);
    });

    it('needs the password, not just the session', async () => {
      const ada = await patient();

      const res = await request(app)
        .delete('/api/v1/me')
        .set(ada.auth)
        .send({ password: 'not-my-password' })
        .expect(400);

      expect(res.body.error.code).toBe('invalid_credentials');
      expect(await UserModel.countDocuments({ _id: ada.id })).toBe(1);
    });

    it('leaves the session unusable afterwards', async () => {
      const ada = await patient();

      await request(app).delete('/api/v1/me').set(ada.auth).send({ password }).expect(204);

      // The access token has not expired yet, but there is nobody behind it.
      await request(app).get('/api/v1/me').set(ada.auth).expect(401);
      await request(app)
        .post('/api/v1/auth/sign-in')
        .send({ email: 'ada@example.com', password })
        .expect(401);
    });

    it('touches nobody else', async () => {
      const ada = await patientWithHistory();
      const grace = await patient('grace@example.com');
      await request(app)
        .post('/api/v1/threads')
        .set(grace.auth)
        .send({ subject: 'Hers', body: 'Still here afterwards.' })
        .expect(201);

      await request(app).delete('/api/v1/me').set(ada.auth).send({ password }).expect(204);

      expect(await UserModel.countDocuments({ _id: grace.id })).toBe(1);
      expect(await ThreadModel.countDocuments({ patientId: grace.id })).toBe(1);
      expect(await MessageModel.countDocuments({})).toBe(1);
      await request(app).get('/api/v1/me').set(grace.auth).expect(200);
    });
  });

  it('every profile route needs a session', async () => {
    await request(app).get('/api/v1/me').expect(401);
    await request(app).patch('/api/v1/me').send({ name: 'Nobody' }).expect(401);
    await request(app).post('/api/v1/me/password').send({}).expect(401);
    await request(app).delete('/api/v1/me').send({ password }).expect(401);
  });
});
