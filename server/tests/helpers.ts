import request from 'supertest';
import type { Express } from 'express';
import { DoctorModel } from '../src/models/doctor.model.js';

export async function makeDoctor(overrides: Record<string, unknown> = {}) {
  return DoctorModel.create({
    name: 'Dr. Thomas Moore',
    specialty: 'Cardiologist',
    specialtyField: 'Cardiology',
    rating: 4.8,
    pricePerSession: 84,
    sessionMinutes: 30,
    workingHours: {
      startMinute: 0,
      endMinute: 1440,
      weekdays: [1, 2, 3, 4, 5, 6, 7],
      breakStartMinute: -1,
      breakEndMinute: -1,
    },
    ...overrides,
  });
}

export async function registerPatient(app: Express, email: string) {
  const res = await request(app)
    .post('/api/v1/auth/sign-up')
    .send({ name: 'Ada Lovelace', email, password: 'hunter2hunter2' })
    .expect(201);
  return res.body as { accessToken: string; refreshToken: string; user: { id: string } };
}

/** A slot comfortably in the future, aligned to the session grid. */
export function futureSlot(dayOffset = 2, hour = 10): Date {
  const now = new Date();
  return new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + dayOffset,
      hour,
      0,
      0,
      0,
    ),
  );
}
