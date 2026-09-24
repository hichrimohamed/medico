import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validateBody, validateQuery, validated } from '../../middleware/validate.js';
import { AppointmentModel } from '../../models/appointment.model.js';
import { DoctorModel } from '../../models/doctor.model.js';
import { AppError } from '../../utils/errors.js';
import { buildDays } from '../../utils/slots.js';

const bookSchema = z.object({
  doctorId: z.string().min(1),
  startsAt: z.coerce.date(),
  reason: z.string().trim().max(500).optional(),
});

const listQuery = z.object({
  status: z.enum(['booked', 'cancelled', 'all']).default('booked'),
  when: z.enum(['upcoming', 'past', 'all']).default('upcoming'),
});

export const appointmentsRouter = Router();
appointmentsRouter.use(requireAuth);

appointmentsRouter.post('/', validateBody(bookSchema), async (req, res) => {
  const { doctorId, startsAt, reason } = req.body as z.infer<typeof bookSchema>;

  const doctor = await DoctorModel.findById(doctorId).catch(() => null);
  if (!doctor) throw AppError.notFound('We could not find that doctor.');

  if (startsAt.getTime() <= Date.now()) {
    throw AppError.badRequest('slot_in_past', 'That time has already passed. Pick another.');
  }

  // The slot has to be one the doctor actually offers — without this, a
  // crafted request could book 03:00 on a Sunday.
  const [day] = buildDays(doctor, startsAt, 1, new Set());
  const offered = day?.slots.some(
    (slot) => new Date(slot.startsAt).getTime() === startsAt.getTime(),
  );
  if (!offered) {
    throw AppError.badRequest(
      'slot_in_past',
      'That is not one of this doctor’s appointment times.',
    );
  }

  try {
    const appointment = await AppointmentModel.create({
      patientId: req.userId,
      doctorId: doctor._id,
      startsAt,
      endsAt: new Date(startsAt.getTime() + (doctor.sessionMinutes || 30) * 60000),
      reason: reason ?? '',
    });
    res.status(201).json(appointment.toJSON());
  } catch (error) {
    // The unique index is the referee. Two patients tapping Confirm at the
    // same instant both pass any check we could write in here; exactly one
    // survives the insert, and the loser gets a clear answer.
    if (error instanceof mongoose.mongo.MongoServerError && error.code === 11000) {
      const mine = error.message.includes('one_booking_per_patient_slot');
      throw AppError.conflict(
        'slot_taken',
        mine
          ? 'You already have an appointment at that time.'
          : 'Someone just took that time. Pick another slot.',
      );
    }
    throw error;
  }
});

appointmentsRouter.get('/', validateQuery(listQuery), async (req, res) => {
  const { status, when } = validated<z.infer<typeof listQuery>>(req);

  const filter: Record<string, unknown> = { patientId: req.userId };
  if (status !== 'all') filter.status = status;
  if (when === 'upcoming') filter.startsAt = { $gte: new Date() };
  if (when === 'past') filter.startsAt = { $lt: new Date() };

  const appointments = await AppointmentModel.find(filter)
    .sort({ startsAt: when === 'past' ? -1 : 1 })
    .populate('doctorId', 'name specialty specialtyField photoUrl pricePerSession rating');

  res.json({ appointments: appointments.map((entry) => entry.toJSON()) });
});

appointmentsRouter.post('/:id/cancel', async (req, res) => {
  const appointment = await AppointmentModel.findOne({
    _id: req.params.id,
    patientId: req.userId,
  }).catch(() => null);

  // Scoped to the signed-in patient, so a wrong id and someone else's
  // appointment are the same answer — no probing for other people's bookings.
  if (!appointment) throw AppError.notFound('We could not find that appointment.');

  if (appointment.status === 'cancelled') {
    res.json(appointment.toJSON());
    return;
  }

  appointment.status = 'cancelled';
  appointment.cancelledAt = new Date();
  await appointment.save();

  res.json(appointment.toJSON());
});
