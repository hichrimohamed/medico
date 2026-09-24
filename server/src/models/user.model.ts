import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

/**
 * A patient.
 *
 * `passwordHash` carries `select: false` so it never leaves the database
 * unless a query asks for it explicitly. The default shape of a user object is
 * therefore safe to serialise, which is the behaviour you want when someone
 * adds a new endpoint in a hurry.
 */
const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    passwordHash: { type: String, required: true, select: false },

    // Lockout state. The app has a dedicated `account_locked` path with its own
    // recovery action, so this is a first-class field rather than a log line.
    failedSignInCount: { type: Number, default: 0, select: false },
    lockedUntil: { type: Date, default: null, select: false },

    favouriteDoctorIds: [{ type: Schema.Types.ObjectId, ref: 'Doctor' }],
  },
  { timestamps: true },
);

userSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: (_doc, ret: Record<string, unknown>) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.passwordHash;
    delete ret.failedSignInCount;
    delete ret.lockedUntil;
    return ret;
  },
});

export type User = InferSchemaType<typeof userSchema>;
export type UserDoc = HydratedDocument<User>;
export const UserModel = model('User', userSchema);
