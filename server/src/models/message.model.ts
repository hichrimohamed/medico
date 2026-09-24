import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

export const MESSAGE_AUTHORS = ['patient', 'clinic'] as const;
export type MessageAuthor = (typeof MESSAGE_AUTHORS)[number];

/**
 * A conversation between one patient and the practice.
 *
 * Deliberately *with the practice*, not with a doctor. A thread addressed to a
 * named consultant implies that consultant is reading it, which no clinic can
 * promise and which is the kind of promise that ends with someone's chest pain
 * sitting unread over a weekend. `aboutDoctorId` is what a thread is *about* —
 * the appointment it concerns — not who is obliged to answer.
 *
 * `lastMessageAt`, `lastMessagePreview` and `unreadForPatient` are copies of
 * facts that live in the messages collection. They are denormalised on purpose:
 * the list screen shows exactly these three things per thread, and without them
 * drawing ten rows means ten more queries.
 */
const threadSchema = new Schema(
  {
    patientId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    /** "Blood pressure review" — what the patient can recognise in a list. */
    subject: { type: String, required: true, trim: true, maxlength: 120 },

    /** The doctor this is about, when it is about one. */
    aboutDoctorId: {
      type: Schema.Types.ObjectId,
      ref: 'Doctor',
      default: null,
    },

    lastMessageAt: { type: Date, required: true, index: true },
    lastMessagePreview: { type: String, default: '' },
    lastMessageFrom: { type: String, enum: MESSAGE_AUTHORS, default: 'clinic' },

    /** Messages from the clinic the patient has not opened yet. */
    unreadForPatient: { type: Number, default: 0, min: 0 },

    /** A closed thread is kept and readable; it just takes no new messages. */
    closedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// The list screen's only query: this patient's threads, newest activity first.
threadSchema.index({ patientId: 1, lastMessageAt: -1 });

const messageSchema = new Schema(
  {
    threadId: {
      type: Schema.Types.ObjectId,
      ref: 'Thread',
      required: true,
      index: true,
    },
    /**
     * Who wrote it — a side, not a person. The clinic is a rota, and a message
     * from "the clinic" is answerable by whoever is on it.
     */
    from: { type: String, enum: MESSAGE_AUTHORS, required: true },
    body: { type: String, required: true, trim: true, maxlength: 4000 },
    sentAt: { type: Date, required: true, index: true },

    /** When the patient read it. Only ever set on a clinic message. */
    readAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// Reading a thread: its messages in the order they were sent.
messageSchema.index({ threadId: 1, sentAt: 1 });

for (const schema of [threadSchema, messageSchema]) {
  schema.set('toJSON', {
    virtuals: true,
    versionKey: false,
    transform: (_doc, ret: Record<string, unknown>) => {
      ret.id = ret._id;
      delete ret._id;
      return ret;
    },
  });
}

export type Thread = InferSchemaType<typeof threadSchema>;
export type ThreadDoc = HydratedDocument<Thread>;
export const ThreadModel = model('Thread', threadSchema);

export type Message = InferSchemaType<typeof messageSchema>;
export type MessageDoc = HydratedDocument<Message>;
export const MessageModel = model('Message', messageSchema);
