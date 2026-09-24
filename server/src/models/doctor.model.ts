import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

const credentialSchema = new Schema(
  {
    title: { type: String, required: true },
    place: { type: String, required: true },
    period: { type: String, required: true },
  },
  { _id: false },
);

const reviewSchema = new Schema(
  {
    author: { type: String, required: true },
    rating: { type: Number, required: true, min: 1, max: 5 },
    body: { type: String, required: true },
    when: { type: String, required: true },
  },
  { _id: false },
);

/**
 * Mirrors `Doctor` in lib/features/doctors/data/doctor.dart.
 *
 * `specialtyField` is what the home screen's rail filters on ("Neurology");
 * `specialty` is what a doctor is called ("Neurologist"). Both are stored
 * because the client shows them in different places and should not be deriving
 * one from the other with string surgery.
 */
const doctorSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    specialty: { type: String, required: true, index: true },
    specialtyField: { type: String, required: true, index: true },

    rating: { type: Number, required: true, min: 0, max: 5 },
    pricePerSession: { type: Number, required: true, min: 0 },
    sessionMinutes: { type: Number, default: 30 },
    followUpFee: { type: Number, default: 0 },
    followUpWindowDays: { type: Number, default: 30 },

    qualifications: [{ type: String }],
    yearsExperience: { type: Number, default: 0 },
    patientCount: { type: Number, default: 0 },
    bio: { type: String, default: '' },
    photoUrl: { type: String, default: null },

    experience: [credentialSchema],
    education: [credentialSchema],
    reviews: [reviewSchema],

    /// Clinic hours as minutes from midnight, local to the clinic.
    /// 540 = 09:00, 960 = 16:00.
    workingHours: {
      startMinute: { type: Number, default: 540 },
      endMinute: { type: Number, default: 960 },
      /// 1 = Monday … 7 = Sunday.
      weekdays: { type: [Number], default: [1, 2, 3, 4, 5] },
      /// Minutes the clinic is closed, e.g. lunch 12:00–13:00.
      breakStartMinute: { type: Number, default: 720 },
      breakEndMinute: { type: Number, default: 780 },
    },
  },
  { timestamps: true },
);

doctorSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: (_doc, ret: Record<string, unknown>) => {
    ret.id = ret._id;
    delete ret._id;
    return ret;
  },
});

export type Doctor = InferSchemaType<typeof doctorSchema>;
export type DoctorDoc = HydratedDocument<Doctor>;
export const DoctorModel = model('Doctor', doctorSchema);
