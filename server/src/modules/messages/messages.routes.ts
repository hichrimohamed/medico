import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validateBody, validateQuery, validated } from '../../middleware/validate.js';
import { DoctorModel } from '../../models/doctor.model.js';
import { MessageModel, ThreadModel, type ThreadDoc } from '../../models/message.model.js';
import { AppError } from '../../utils/errors.js';

const startSchema = z.object({
  subject: z.string().trim().min(2, 'Give it a short subject.').max(120),
  body: z.string().trim().min(1, 'Write your message.').max(4000),
  aboutDoctorId: z.string().min(1).optional(),
});

const sendSchema = z.object({
  body: z.string().trim().min(1, 'Write your message.').max(4000),
});

const listQuery = z.object({
  unread: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

export const messagesRouter = Router();
messagesRouter.use(requireAuth);

/**
 * Finds a thread that belongs to the signed-in patient.
 *
 * Scoped by patient in the query, not checked afterwards: a thread id that
 * exists but belongs to somebody else and one that never existed give the same
 * answer, so this cannot be used to find out who else the practice is talking
 * to.
 */
async function ownThread(id: unknown, patientId: string): Promise<ThreadDoc> {
  const thread = await ThreadModel.findOne({ _id: id, patientId }).catch(() => null);
  if (!thread) throw AppError.notFound('We could not find that conversation.');
  return thread;
}

/** A short, single-line stand-in for the message in a list row. */
function preview(body: string): string {
  const flat = body.replace(/\s+/g, ' ').trim();
  return flat.length <= 140 ? flat : `${flat.slice(0, 139)}…`;
}

messagesRouter.get('/', validateQuery(listQuery), async (req, res) => {
  const { unread } = validated<{ unread: boolean }>(req);

  const filter: Record<string, unknown> = { patientId: req.userId };
  if (unread) filter.unreadForPatient = { $gt: 0 };

  const threads = await ThreadModel.find(filter)
    .sort({ lastMessageAt: -1 })
    .populate('aboutDoctorId', 'name specialty specialtyField photoUrl');

  res.json({
    threads: threads.map((thread) => thread.toJSON()),
    // The badge on the tab bar: conversations waiting, not messages waiting.
    // Two unread messages in one thread is one thing to go and look at.
    unreadThreads: await ThreadModel.countDocuments({
      patientId: req.userId,
      unreadForPatient: { $gt: 0 },
    }),
  });
});

messagesRouter.post('/', validateBody(startSchema), async (req, res) => {
  const { subject, body, aboutDoctorId } = req.body as z.infer<typeof startSchema>;

  if (aboutDoctorId) {
    const doctor = await DoctorModel.findById(aboutDoctorId).catch(() => null);
    if (!doctor) throw AppError.notFound('We could not find that doctor.');
  }

  const sentAt = new Date();
  const thread = await ThreadModel.create({
    patientId: req.userId,
    subject,
    aboutDoctorId: aboutDoctorId ?? null,
    lastMessageAt: sentAt,
    lastMessagePreview: preview(body),
    lastMessageFrom: 'patient',
    // The patient wrote it, so there is nothing here they have not read.
    unreadForPatient: 0,
  });

  await MessageModel.create({
    threadId: thread._id,
    from: 'patient',
    body,
    sentAt,
  });

  res.status(201).json(thread.toJSON());
});

messagesRouter.get('/:id/messages', async (req, res) => {
  const thread = await ownThread(req.params.id, req.userId!);

  const messages = await MessageModel.find({ threadId: thread._id }).sort({ sentAt: 1 });

  await thread.populate('aboutDoctorId', 'name specialty specialtyField photoUrl');

  res.json({
    thread: thread.toJSON(),
    messages: messages.map((message) => message.toJSON()),
  });
});

messagesRouter.post('/:id/messages', validateBody(sendSchema), async (req, res) => {
  const thread = await ownThread(req.params.id, req.userId!);

  if (thread.closedAt) {
    throw AppError.badRequest(
      'forbidden',
      'This conversation has been closed. Start a new one and we will pick it up.',
    );
  }

  const sentAt = new Date();
  const message = await MessageModel.create({
    threadId: thread._id,
    from: 'patient',
    body: req.body.body,
    sentAt,
  });

  thread.lastMessageAt = sentAt;
  thread.lastMessagePreview = preview(req.body.body);
  thread.lastMessageFrom = 'patient';
  await thread.save();

  res.status(201).json(message.toJSON());
});

messagesRouter.post('/:id/read', async (req, res) => {
  const thread = await ownThread(req.params.id, req.userId!);

  const now = new Date();
  await MessageModel.updateMany(
    { threadId: thread._id, from: 'clinic', readAt: null },
    { $set: { readAt: now } },
  );

  thread.unreadForPatient = 0;
  await thread.save();

  res.json(thread.toJSON());
});
