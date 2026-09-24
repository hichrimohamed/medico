import { Router } from 'express';
import { z } from 'zod';
import { validateQuery, validated } from '../../middleware/validate.js';
import { DoctorModel } from '../../models/doctor.model.js';
import { AppointmentModel } from '../../models/appointment.model.js';
import { AppError } from '../../utils/errors.js';
import { buildDays } from '../../utils/slots.js';

const listQuery = z.object({
  /** Matches the home screen's rail, which filters by field ("Neurology"). */
  specialty: z.string().trim().min(1).optional(),
  q: z.string().trim().min(1).max(80).optional(),
  page: z.coerce.number().int().min(1).default(1),
  perPage: z.coerce.number().int().min(1).max(50).default(20),
});

const availabilityQuery = z.object({
  from: z.coerce.date().optional(),
  days: z.coerce.number().int().min(1).max(31).default(7),
});

export const doctorsRouter = Router();

doctorsRouter.get('/specialties', async (_req, res) => {
  // Derived from the directory rather than kept in a second list that can
  // disagree with it.
  const fields = await DoctorModel.aggregate<{ _id: string; count: number }>([
    { $group: { _id: '$specialtyField', count: { $sum: 1 } } },
    { $sort: { _id: 1 } },
  ]);

  res.json({
    specialties: fields.map((entry) => ({ field: entry._id, doctorCount: entry.count })),
  });
});

doctorsRouter.get('/', validateQuery(listQuery), async (req, res) => {
  const { specialty, q, page, perPage } = validated<z.infer<typeof listQuery>>(req);

  const filter: Record<string, unknown> = {};
  if (specialty) {
    filter.$or = [{ specialtyField: specialty }, { specialty }];
  }
  if (q) {
    // Escaped: a patient searching "Dr. O'Brien (cardio)" must not be able to
    // hand us a regular expression.
    const safe = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    filter.name = { $regex: safe, $options: 'i' };
  }

  const [doctors, total] = await Promise.all([
    DoctorModel.find(filter)
      .sort({ rating: -1, name: 1 })
      .skip((page - 1) * perPage)
      .limit(perPage),
    DoctorModel.countDocuments(filter),
  ]);

  res.json({
    doctors: doctors.map((doctor) => doctor.toJSON()),
    page,
    perPage,
    total,
    hasMore: page * perPage < total,
  });
});

doctorsRouter.get('/:id', async (req, res) => {
  const doctor = await DoctorModel.findById(req.params.id).catch(() => null);
  if (!doctor) throw AppError.notFound('We could not find that doctor.');
  res.json(doctor.toJSON());
});

doctorsRouter.get('/:id/availability', validateQuery(availabilityQuery), async (req, res) => {
  const doctor = await DoctorModel.findById(req.params.id).catch(() => null);
  if (!doctor) throw AppError.notFound('We could not find that doctor.');

  const { from, days } = validated<z.infer<typeof availabilityQuery>>(req);
  const start = from ?? new Date();
  const startOfDay = new Date(
    Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()),
  );
  const end = new Date(startOfDay.getTime() + days * 24 * 60 * 60 * 1000);

  const booked = await AppointmentModel.find({
    doctorId: doctor._id,
    status: 'booked',
    startsAt: { $gte: startOfDay, $lt: end },
  }).select('startsAt');

  res.json({
    doctorId: String(doctor._id),
    sessionMinutes: doctor.sessionMinutes,
    days: buildDays(
      doctor,
      startOfDay,
      days,
      new Set(booked.map((entry) => entry.startsAt.getTime())),
    ),
  });
});
