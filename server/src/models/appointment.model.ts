import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

export const APPOINTMENT_STATUSES = ['booked', 'cancelled'] as const;
export type AppointmentStatus = (typeof APPOINTMENT_STATUSES)[number];

/**
 * A booked slot.
 *
 * The important line in this file is the partial unique index at the bottom.
 * Checking "is this slot free?" and then inserting is two operations, and two
 * patients tapping Confirm at the same moment both pass the check. The index
 * makes the database the referee: the second insert fails with a duplicate key
 * error, which the service turns into `slot_taken`.
 *
 * It is partial so that a cancelled appointment frees the slot again rather
 * than blocking it forever.
 */
const appointmentSchema = new Schema(
  {
    patientId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    doctorId: {
      type: Schema.Types.ObjectId,
      ref: 'Doctor',
      required: true,
      index: true,
    },
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    status: {
      type: String,
      enum: APPOINTMENT_STATUSES,
      default: 'booked',
      index: true,
    },
    cancelledAt: { type: Date, default: null },
    reason: { type: String, default: '', maxlength: 500 },
  },
  { timestamps: true },
);

appointmentSchema.index(
  { doctorId: 1, startsAt: 1 },
  {
    unique: true,
    partialFilterExpression: { status: 'booked' },
    name: 'one_booking_per_doctor_slot',
  },
);

// A patient cannot be in two places at once either.
appointmentSchema.index(
  { patientId: 1, startsAt: 1 },
  {
    unique: true,
    partialFilterExpression: { status: 'booked' },
    name: 'one_booking_per_patient_slot',
  },
);

appointmentSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: (_doc, ret: Record<string, unknown>) => {
    ret.id = ret._id;
    delete ret._id;
    return ret;
  },
});

export type Appointment = InferSchemaType<typeof appointmentSchema>;
export type AppointmentDoc = HydratedDocument<Appointment>;
export const AppointmentModel = model('Appointment', appointmentSchema);
