import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { AppointmentModel } from '../../models/appointment.model.js';
import { DoctorModel } from '../../models/doctor.model.js';
import { MessageModel, ThreadModel } from '../../models/message.model.js';
import { PasswordResetModel, RefreshTokenModel } from '../../models/token.model.js';
import { UserModel } from '../../models/user.model.js';
import { AppError } from '../../utils/errors.js';
import { hashPassword, verifyPassword } from '../../utils/password.js';

/** The signed-in patient: their profile, their saved doctors, their account. */
export const meRouter = Router();
meRouter.use(requireAuth);

const updateSchema = z.object({
  name: z.string().trim().min(2, 'That name looks too short.').max(120),
});

const passwordSchema = z.object({
  currentPassword: z.string().min(1, 'Enter your current password.'),
  newPassword: z
    .string()
    .min(8, 'Use at least 8 characters. Longer is safer than complicated.')
    .max(200),
});

/**
 * Deleting an account asks for the password again.
 *
 * The session alone is not enough. A phone is unlocked and in somebody else's
 * hand often enough, and this is the one action in the app that cannot be
 * undone — so it costs one more thing only the patient knows.
 */
const deleteSchema = z.object({
  password: z.string().min(1, 'Enter your password to confirm.'),
});

async function currentUser(userId: string) {
  const user = await UserModel.findById(userId);
  if (!user) throw AppError.unauthorized();
  return user;
}

meRouter.get('/', async (req, res) => {
  const user = await currentUser(req.userId!);

  // The counts the profile screen shows. Three cheap indexed counts beats
  // three list endpoints the screen would only measure the length of.
  const [upcomingAppointments, unreadThreads] = await Promise.all([
    AppointmentModel.countDocuments({
      patientId: user._id,
      status: 'booked',
      startsAt: { $gte: new Date() },
    }),
    ThreadModel.countDocuments({ patientId: user._id, unreadForPatient: { $gt: 0 } }),
  ]);

  res.json({
    ...user.toJSON(),
    savedDoctors: user.favouriteDoctorIds.length,
    upcomingAppointments,
    unreadThreads,
  });
});

meRouter.patch('/', validateBody(updateSchema), async (req, res) => {
  const user = await currentUser(req.userId!);

  // Name only. Changing an email address means proving the new one belongs to
  // the patient, and an unverified change is how someone locks a patient out
  // of their own records — so it is not half-done here.
  user.name = req.body.name;
  await user.save();

  res.json(user.toJSON());
});

meRouter.post('/password', validateBody(passwordSchema), async (req, res) => {
  const { currentPassword, newPassword } = req.body as z.infer<typeof passwordSchema>;

  const user = await UserModel.findById(req.userId).select('+passwordHash');
  if (!user) throw AppError.unauthorized();

  if (!(await verifyPassword(currentPassword, user.passwordHash))) {
    throw AppError.badRequest(
      'invalid_credentials',
      'That is not your current password.',
    );
  }

  user.passwordHash = await hashPassword(newPassword);
  await user.save();

  // Every other session goes. A password change is usually the answer to
  // "somebody else has been in here", and leaving their session alive would
  // make the change theatre.
  await RefreshTokenModel.deleteMany({ userId: user._id });
  await PasswordResetModel.deleteMany({ userId: user._id });

  res.status(204).end();
});

meRouter.delete('/', validateBody(deleteSchema), async (req, res) => {
  const user = await UserModel.findById(req.userId).select('+passwordHash');
  if (!user) throw AppError.unauthorized();

  if (!(await verifyPassword(req.body.password, user.passwordHash))) {
    throw AppError.badRequest('invalid_credentials', 'That password is not right.');
  }

  // Everything that points at this patient, in an order that leaves nothing
  // orphaned if this fails halfway: the children first, the user last. A
  // half-deleted account that can still be signed into is worse than one that
  // is still there.
  //
  // Appointments are deleted rather than cancelled, which also hands the slots
  // back: the index that prevents double booking is partial on
  // `status: 'booked'`, so removing the row reopens the time for somebody else.
  //
  // TODO(retention): a real practice cannot erase clinical history on request —
  // appointments and messages usually carry a statutory retention period, and
  // this would become "close the account, keep the record, and stop it being
  // reachable". That is a policy decision, not a code one.
  const threads = await ThreadModel.find({ patientId: user._id }).select('_id');
  await MessageModel.deleteMany({ threadId: { $in: threads.map((t) => t._id) } });
  await ThreadModel.deleteMany({ patientId: user._id });
  await AppointmentModel.deleteMany({ patientId: user._id });
  await RefreshTokenModel.deleteMany({ userId: user._id });
  await PasswordResetModel.deleteMany({ userId: user._id });
  await user.deleteOne();

  res.status(204).end();
});

meRouter.get('/favourites', async (req, res) => {
  const user = await UserModel.findById(req.userId).populate('favouriteDoctorIds');
  if (!user) throw AppError.unauthorized();
  res.json({
    doctors: (user.favouriteDoctorIds as unknown as { toJSON(): unknown }[]).map((d) =>
      d.toJSON(),
    ),
  });
});

meRouter.put('/favourites/:doctorId', async (req, res) => {
  const doctor = await DoctorModel.findById(req.params.doctorId).catch(() => null);
  if (!doctor) throw AppError.notFound('We could not find that doctor.');

  // $addToSet, not push: tapping the heart twice must not store it twice.
  await UserModel.updateOne(
    { _id: req.userId },
    { $addToSet: { favouriteDoctorIds: doctor._id } },
  );
  res.status(204).end();
});

meRouter.delete('/favourites/:doctorId', async (req, res) => {
  await UserModel.updateOne(
    { _id: req.userId },
    { $pull: { favouriteDoctorIds: req.params.doctorId } },
  );
  res.status(204).end();
});
