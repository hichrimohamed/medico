import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { makeDoctor, registerPatient } from './helpers.js';

const app = createApp();

describe('directory', () => {
  it('filters by the field the home screen rail uses', async () => {
    await makeDoctor();
    await makeDoctor({
      name: 'Dr. Amina Farouk',
      specialty: 'Pulmonologist',
      specialtyField: 'Pulmonology',
    });

    const res = await request(app).get('/api/v1/doctors?specialty=Pulmonology').expect(200);

    expect(res.body.total).toBe(1);
    expect(res.body.doctors[0].name).toBe('Dr. Amina Farouk');
  });

  it('returns an empty list, not an error, when a specialty has nobody', async () => {
    await makeDoctor();

    const res = await request(app).get('/api/v1/doctors?specialty=Dermatology').expect(200);

    // The app has a designed empty state for this; a 404 would send it down
    // the error path instead.
    expect(res.body.doctors).toEqual([]);
    expect(res.body.total).toBe(0);
  });

  it('treats a search term as text, not as a regular expression', async () => {
    await makeDoctor({ name: 'Dr. Thomas Moore' });

    // Would match everything if it were compiled as a pattern.
    const res = await request(app).get('/api/v1/doctors?q=.*').expect(200);

    expect(res.body.total).toBe(0);
  });

  it('finds a doctor by part of their name, case-insensitively', async () => {
    await makeDoctor({ name: 'Dr. Thomas Moore' });

    const res = await request(app).get('/api/v1/doctors?q=thomas').expect(200);
    expect(res.body.total).toBe(1);
  });

  it('answers a bad doctor id with not-found rather than a cast error', async () => {
    const res = await request(app).get('/api/v1/doctors/not-an-object-id').expect(404);
    expect(res.body.error.code).toBe('not_found');
  });

  it('reports no slots on a day the doctor does not work', async () => {
    const doctor = await makeDoctor({
      workingHours: {
        startMinute: 540,
        endMinute: 960,
        weekdays: [1],
        breakStartMinute: -1,
        breakEndMinute: -1,
      },
    });

    const res = await request(app)
      .get(`/api/v1/doctors/${doctor._id}/availability?days=7`)
      .expect(200);

    const open = res.body.days.filter((d: { slots: unknown[] }) => d.slots.length > 0);
    expect(open).toHaveLength(1);
    expect(open[0].weekday).toBe(1);
  });

  it('leaves no slot inside the lunch break', async () => {
    const doctor = await makeDoctor({
      workingHours: {
        startMinute: 540,
        endMinute: 960,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        breakStartMinute: 720,
        breakEndMinute: 780,
      },
    });

    const res = await request(app)
      .get(`/api/v1/doctors/${doctor._id}/availability?days=3`)
      .expect(200);

    const labels: string[] = res.body.days.flatMap(
      (day: { slots: { label: string }[] }) => day.slots.map((s) => s.label),
    );
    expect(labels).not.toContain('12:00');
    expect(labels).not.toContain('12:30');
    expect(labels).toContain('13:00');
  });

  it('saves and unsaves a doctor without duplicating them', async () => {
    const doctor = await makeDoctor();
    const { accessToken } = await registerPatient(app, 'ada@example.com');
    const auth = { authorization: `Bearer ${accessToken}` };

    await request(app).put(`/api/v1/me/favourites/${doctor._id}`).set(auth).expect(204);
    await request(app).put(`/api/v1/me/favourites/${doctor._id}`).set(auth).expect(204);

    const saved = await request(app).get('/api/v1/me/favourites').set(auth).expect(200);
    expect(saved.body.doctors).toHaveLength(1);

    await request(app).delete(`/api/v1/me/favourites/${doctor._id}`).set(auth).expect(204);

    const empty = await request(app).get('/api/v1/me/favourites').set(auth).expect(200);
    expect(empty.body.doctors).toHaveLength(0);
  });

  it('keeps favourites behind authentication', async () => {
    await request(app).get('/api/v1/me/favourites').expect(401);
  });
});
