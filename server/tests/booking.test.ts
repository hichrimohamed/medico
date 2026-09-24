import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { AppointmentModel } from '../src/models/appointment.model.js';
import { futureSlot, makeDoctor, registerPatient } from './helpers.js';

const app = createApp();

describe('booking', () => {
  it('books a slot the doctor actually offers', async () => {
    const doctor = await makeDoctor();
    const { accessToken } = await registerPatient(app, 'ada@example.com');
    const startsAt = futureSlot();

    const res = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt })
      .expect(201);

    expect(res.body.status).toBe('booked');
    expect(new Date(res.body.endsAt).getTime() - new Date(res.body.startsAt).getTime())
      .toBe(30 * 60 * 1000);
  });

  it('refuses a time the doctor does not offer', async () => {
    const doctor = await makeDoctor({
      workingHours: {
        startMinute: 540,
        endMinute: 960,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        breakStartMinute: -1,
        breakEndMinute: -1,
      },
    });
    const { accessToken } = await registerPatient(app, 'ada@example.com');

    const res = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt: futureSlot(2, 3) })
      .expect(400);

    expect(res.body.error.code).toBe('slot_in_past');
  });

  it('refuses a time in the past', async () => {
    const doctor = await makeDoctor();
    const { accessToken } = await registerPatient(app, 'ada@example.com');

    const res = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt: futureSlot(-2) })
      .expect(400);

    expect(res.body.error.code).toBe('slot_in_past');
  });

  /**
   * The reason the unique index exists.
   *
   * Ten patients tap Confirm on the same slot at the same moment. Any
   * "is it free?" check in application code passes for all ten, because none
   * of them has written yet. Exactly one row may survive.
   */
  it('lets exactly one of ten simultaneous patients win a slot', async () => {
    const doctor = await makeDoctor();
    const startsAt = futureSlot();

    const patients = await Promise.all(
      Array.from({ length: 10 }, (_, i) =>
        registerPatient(app, `patient${i}@example.com`),
      ),
    );

    const results = await Promise.all(
      patients.map((patient) =>
        request(app)
          .post('/api/v1/appointments')
          .set('authorization', `Bearer ${patient.accessToken}`)
          .send({ doctorId: String(doctor._id), startsAt }),
      ),
    );

    const created = results.filter((r) => r.status === 201);
    const refused = results.filter((r) => r.status === 409);

    expect(created).toHaveLength(1);
    expect(refused).toHaveLength(9);
    expect(refused.every((r) => r.body.error.code === 'slot_taken')).toBe(true);

    const stored = await AppointmentModel.countDocuments({
      doctorId: doctor._id,
      startsAt,
      status: 'booked',
    });
    expect(stored).toBe(1);
  });

  it('stops one patient double-booking themselves across two doctors', async () => {
    const [first, second] = await Promise.all([
      makeDoctor(),
      makeDoctor({ name: 'Dr. Amina Farouk' }),
    ]);
    const { accessToken } = await registerPatient(app, 'ada@example.com');
    const startsAt = futureSlot();

    await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(first._id), startsAt })
      .expect(201);

    const res = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(second._id), startsAt })
      .expect(409);

    expect(res.body.error.message).toContain('already have an appointment');
  });

  it('frees the slot again once cancelled', async () => {
    const doctor = await makeDoctor();
    const ada = await registerPatient(app, 'ada@example.com');
    const bob = await registerPatient(app, 'bob@example.com');
    const startsAt = futureSlot();

    const booked = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${ada.accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt })
      .expect(201);

    await request(app)
      .post(`/api/v1/appointments/${booked.body.id}/cancel`)
      .set('authorization', `Bearer ${ada.accessToken}`)
      .expect(200);

    // The partial index only covers status: 'booked', so the slot reopens.
    await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${bob.accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt })
      .expect(201);
  });

  it('will not cancel someone else’s appointment', async () => {
    const doctor = await makeDoctor();
    const ada = await registerPatient(app, 'ada@example.com');
    const mallory = await registerPatient(app, 'mallory@example.com');

    const booked = await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${ada.accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt: futureSlot() })
      .expect(201);

    // 404, not 403: confirming it exists would leak that Ada has an
    // appointment at that time.
    await request(app)
      .post(`/api/v1/appointments/${booked.body.id}/cancel`)
      .set('authorization', `Bearer ${mallory.accessToken}`)
      .expect(404);
  });

  it('drops a booked slot out of the availability it reports', async () => {
    const doctor = await makeDoctor();
    const { accessToken } = await registerPatient(app, 'ada@example.com');
    const startsAt = futureSlot();

    await request(app)
      .post('/api/v1/appointments')
      .set('authorization', `Bearer ${accessToken}`)
      .send({ doctorId: String(doctor._id), startsAt })
      .expect(201);

    const res = await request(app)
      .get(`/api/v1/doctors/${doctor._id}/availability?days=7`)
      .expect(200);

    const slot = res.body.days
      .flatMap((day: { slots: { startsAt: string; available: boolean }[] }) => day.slots)
      .find((s: { startsAt: string }) => s.startsAt === startsAt.toISOString());

    expect(slot).toBeDefined();
    expect(slot.available).toBe(false);
  });
});
