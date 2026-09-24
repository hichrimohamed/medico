import { Schema, model, type InferSchemaType } from 'mongoose';

/**
 * Refresh tokens are stored hashed, exactly like passwords.
 *
 * A database dump should not hand the reader a working set of sessions. The
 * token itself is only ever in the client's hands; we keep a SHA-256 of it so
 * we can recognise and revoke it.
 *
 * `expiresAt` carries a TTL index, so Mongo removes dead rows without a cron.
 */
const refreshTokenSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },

    /// Set when this token is rotated, pointing at its replacement. If a token
    /// that was already rotated is presented again, it was probably stolen —
    /// the service revokes the whole chain.
    replacedByHash: { type: String, default: null },
  },
  { timestamps: true },
);

refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export type RefreshToken = InferSchemaType<typeof refreshTokenSchema>;
export const RefreshTokenModel = model('RefreshToken', refreshTokenSchema);

/**
 * Password reset tokens. Also hashed, also short-lived — the app tells the
 * patient the link expires in 30 minutes, so this is that promise in code.
 */
const passwordResetSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true },
    usedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

passwordResetSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export type PasswordReset = InferSchemaType<typeof passwordResetSchema>;
export const PasswordResetModel = model('PasswordReset', passwordResetSchema);
