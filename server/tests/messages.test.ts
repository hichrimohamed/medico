import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { MessageModel, ThreadModel } from '../src/models/message.model.js';
import { makeDoctor, registerPatient } from './helpers.js';

const app = createApp();

async function patient(email = 'ada@example.com') {
  const session = await registerPatient(app, email);
  return {
    id: session.user.id,
    auth: { authorization: `Bearer ${session.accessToken}` },
  };
}

/** A message from the practice, as a real one would arrive. */
async function clinicReplies(threadId: string, body: string) {
  const sentAt = new Date();
  await MessageModel.create({ threadId, from: 'clinic', body, sentAt });
  await ThreadModel.updateOne(
    { _id: threadId },
    {
      $set: { lastMessageAt: sentAt, lastMessagePreview: body, lastMessageFrom: 'clinic' },
      $inc: { unreadForPatient: 1 },
    },
  );
}

describe('messages', () => {
  it('starts a conversation and keeps the first message in it', async () => {
    const ada = await patient();

    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Blood pressure review', body: 'Should I keep taking the tablets?' })
      .expect(201);

    expect(started.body.subject).toBe('Blood pressure review');
    expect(started.body.lastMessageFrom).toBe('patient');
    expect(started.body.unreadForPatient).toBe(0);

    const thread = await request(app)
      .get(`/api/v1/threads/${started.body.id}/messages`)
      .set(ada.auth)
      .expect(200);

    expect(thread.body.messages).toHaveLength(1);
    expect(thread.body.messages[0].body).toBe('Should I keep taking the tablets?');
    expect(thread.body.messages[0].from).toBe('patient');
  });

  it('can be about a doctor without being addressed to one', async () => {
    const ada = await patient();
    const doctor = await makeDoctor();

    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({
        subject: 'About my appointment',
        body: 'Can I move it to the afternoon?',
        aboutDoctorId: String(doctor._id),
      })
      .expect(201);

    const list = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);

    // Populated, so the list can draw the doctor without a second request.
    expect(list.body.threads[0].aboutDoctorId.name).toBe('Dr. Thomas Moore');
    expect(list.body.threads[0].id).toBe(started.body.id);
  });

  it('refuses a thread about a doctor who does not exist', async () => {
    const ada = await patient();

    const res = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({
        subject: 'About my appointment',
        body: 'Hello',
        aboutDoctorId: '68c1f0a1b2c3d4e5f6a7b8c9',
      })
      .expect(404);

    expect(res.body.error.code).toBe('not_found');
  });

  it('lists newest activity first', async () => {
    const ada = await patient();

    const first = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Older', body: 'One' })
      .expect(201);
    const second = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Newer', body: 'Two' })
      .expect(201);

    const before = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);
    expect(before.body.threads.map((t: { id: string }) => t.id)).toEqual([
      second.body.id,
      first.body.id,
    ]);

    // A reply on the older thread moves it back to the top, because that is
    // what the patient needs to look at.
    await clinicReplies(first.body.id, 'Here is the answer.');

    const after = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);
    expect(after.body.threads[0].id).toBe(first.body.id);
    expect(after.body.threads[0].lastMessagePreview).toBe('Here is the answer.');
  });

  it('counts conversations waiting, not messages waiting', async () => {
    const ada = await patient();
    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Results', body: 'Are they back?' })
      .expect(201);

    await clinicReplies(started.body.id, 'Not yet.');
    await clinicReplies(started.body.id, 'They are back now.');

    const list = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);

    expect(list.body.threads[0].unreadForPatient).toBe(2);
    // Two messages, one place to go and look.
    expect(list.body.unreadThreads).toBe(1);
  });

  it('filters to the conversations that are waiting', async () => {
    const ada = await patient();
    await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Read', body: 'One' })
      .expect(201);
    const waiting = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Waiting', body: 'Two' })
      .expect(201);
    await clinicReplies(waiting.body.id, 'A reply.');

    const res = await request(app)
      .get('/api/v1/threads?unread=true')
      .set(ada.auth)
      .expect(200);

    expect(res.body.threads).toHaveLength(1);
    expect(res.body.threads[0].subject).toBe('Waiting');
  });

  it('marks a thread read, and stays read', async () => {
    const ada = await patient();
    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Results', body: 'Are they back?' })
      .expect(201);
    await clinicReplies(started.body.id, 'They are back now.');

    const read = await request(app)
      .post(`/api/v1/threads/${started.body.id}/read`)
      .set(ada.auth)
      .expect(200);

    expect(read.body.unreadForPatient).toBe(0);

    const messages = await MessageModel.find({ threadId: started.body.id, from: 'clinic' });
    expect(messages.every((message) => message.readAt !== null)).toBe(true);

    // Reading twice is not an error, and does not go negative.
    const again = await request(app)
      .post(`/api/v1/threads/${started.body.id}/read`)
      .set(ada.auth)
      .expect(200);
    expect(again.body.unreadForPatient).toBe(0);
  });

  it('a reply moves the thread and updates its preview', async () => {
    const ada = await patient();
    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Repeat prescription', body: 'Could I have another month?' })
      .expect(201);

    await request(app)
      .post(`/api/v1/threads/${started.body.id}/messages`)
      .set(ada.auth)
      .send({ body: 'Whenever suits you.' })
      .expect(201);

    const list = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);
    expect(list.body.threads[0].lastMessagePreview).toBe('Whenever suits you.');
    expect(list.body.threads[0].lastMessageFrom).toBe('patient');
  });

  it('will not send to a closed conversation', async () => {
    const ada = await patient();
    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Old business', body: 'Hello' })
      .expect(201);

    await ThreadModel.updateOne({ _id: started.body.id }, { $set: { closedAt: new Date() } });

    const res = await request(app)
      .post(`/api/v1/threads/${started.body.id}/messages`)
      .set(ada.auth)
      .send({ body: 'Still there?' })
      .expect(400);

    expect(res.body.error.code).toBe('forbidden');
  });

  it("another patient's thread is simply not found", async () => {
    const ada = await patient('ada@example.com');
    const grace = await patient('grace@example.com');

    const hers = await request(app)
      .post('/api/v1/threads')
      .set(grace.auth)
      .send({ subject: 'Private', body: 'Something personal' })
      .expect(201);

    // The same answer a made-up id gets, so this cannot be used to find out
    // who else the practice is talking to.
    for (const path of [
      `/api/v1/threads/${hers.body.id}/messages`,
      '/api/v1/threads/68c1f0a1b2c3d4e5f6a7b8c9/messages',
    ]) {
      const res = await request(app).get(path).set(ada.auth).expect(404);
      expect(res.body.error.code).toBe('not_found');
    }

    const list = await request(app).get('/api/v1/threads').set(ada.auth).expect(200);
    expect(list.body.threads).toHaveLength(0);
  });

  it('needs a session', async () => {
    await request(app).get('/api/v1/threads').expect(401);
    await request(app).post('/api/v1/threads').send({ subject: 'x', body: 'y' }).expect(401);
  });

  it('refuses an empty message', async () => {
    const ada = await patient();
    const started = await request(app)
      .post('/api/v1/threads')
      .set(ada.auth)
      .send({ subject: 'Subject', body: 'Body' })
      .expect(201);

    const res = await request(app)
      .post(`/api/v1/threads/${started.body.id}/messages`)
      .set(ada.auth)
      .send({ body: '   ' })
      .expect(400);

    expect(res.body.error.code).toBe('validation_failed');
  });
});
