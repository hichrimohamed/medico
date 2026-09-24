import { connectDatabase, disconnectDatabase } from './db/connect.js';
import { DoctorModel } from './models/doctor.model.js';
import { MessageModel, ThreadModel } from './models/message.model.js';
import { UserModel } from './models/user.model.js';
import { hashPassword } from './utils/password.js';

/**
 * The clinic's directory.
 *
 * `photoUrl` holds a bundled asset path rather than a hosted image: the
 * illustrated portraits ship inside the app, so the directory draws with no
 * image requests at all. The field takes an `https://` URL just as happily —
 * `MedicoAvatar` renders either — for the day the practice has photographs of
 * its own.
 */
const doctors = [
  {
    name: 'Dr. William James',
    photoUrl: 'assets/images/doctors/james.png',
    specialty: 'Neurologist',
    specialtyField: 'Neurology',
    rating: 4.8,
    pricePerSession: 95,
    yearsExperience: 14,
    patientCount: 1800,
    followUpFee: 45,
    bio: 'Dr. William James is a consultant neurologist with 14 years of experience in headache medicine, epilepsy and movement disorders.',
    qualifications: ['MBBS', 'MRCP (Neurology)', 'PhD'],
  },
  {
    name: 'Dr. Thomas Moore',
    photoUrl: 'assets/images/doctors/moore.png',
    specialty: 'Cardiologist',
    specialtyField: 'Cardiology',
    rating: 4.8,
    pricePerSession: 84,
    yearsExperience: 12,
    patientCount: 2500,
    followUpFee: 40,
    bio: 'Dr. Thomas Moore is a board-certified cardiologist with over 12 years of experience in cardiovascular medicine. He specialises in interventional cardiology, heart failure management and preventive care, and runs the clinic’s arrhythmia service.',
    qualifications: ['MBBS', 'FCPS', 'FRCP (Edin)', 'FCCP (USA)', 'FACC (USA)', 'FESC'],
    experience: [
      { title: 'Consultant Cardiologist', place: 'Medico Heart Centre', period: '2019 — now' },
      { title: 'Interventional Cardiology Fellow', place: "St Vincent's Hospital", period: '2016 — 2019' },
      { title: 'Registrar, Internal Medicine', place: 'Royal City Hospital', period: '2013 — 2016' },
    ],
    education: [
      { title: 'Fellowship, Cardiology', place: 'Royal College of Physicians, Edinburgh', period: '2018' },
      { title: 'FCPS, Internal Medicine', place: 'College of Physicians and Surgeons', period: '2015' },
      { title: 'MBBS', place: 'University Medical School', period: '2011' },
    ],
    reviews: [
      { author: 'Hannah W.', rating: 5, body: 'Explained my results in plain language and drew me a diagram. First time I have understood my own heart.', when: '2 weeks ago' },
      { author: 'Marcus T.', rating: 5, body: 'Ran late by about fifteen minutes, but he did not rush me once he started. Worth the wait.', when: 'last month' },
      { author: 'Priya S.', rating: 4, body: 'Very thorough. I would have liked more time to ask questions at the end of the appointment.', when: 'last month' },
    ],
  },
  {
    name: 'Dr. Amina Farouk',
    photoUrl: 'assets/images/doctors/farouk.png',
    specialty: 'Pulmonologist',
    specialtyField: 'Pulmonology',
    rating: 4.9,
    pricePerSession: 78,
    yearsExperience: 9,
    patientCount: 1400,
    followUpFee: 35,
    bio: 'Dr. Amina Farouk treats asthma, COPD and sleep-disordered breathing, and leads the clinic’s pulmonary rehabilitation programme.',
    qualifications: ['MBBS', 'MRCP', 'Diploma in Sleep Medicine'],
  },
  {
    name: 'Dr. Priya Raman',
    photoUrl: 'assets/images/doctors/raman.png',
    specialty: 'Paediatrician',
    specialtyField: 'Paediatrics',
    rating: 5,
    pricePerSession: 70,
    yearsExperience: 11,
    patientCount: 3200,
    followUpFee: 30,
    bio: 'Dr. Priya Raman sees children from birth to sixteen, with a special interest in childhood allergy and developmental review.',
    qualifications: ['MBBS', 'MRCPCH'],
    workingHours: { startMinute: 540, endMinute: 900, weekdays: [1, 2, 3, 4, 5, 6], breakStartMinute: 720, breakEndMinute: 780 },
  },
  {
    name: 'Dr. Noah Abebe',
    photoUrl: 'assets/images/doctors/abebe.png',
    specialty: 'Ophthalmologist',
    specialtyField: 'Eye care',
    rating: 4.9,
    pricePerSession: 88,
    yearsExperience: 13,
    patientCount: 2600,
    followUpFee: 40,
    bio: 'Dr. Noah Abebe is an ophthalmologist working in cataract surgery, glaucoma and diabetic eye disease, and runs the clinic’s retinal screening clinic.',
    qualifications: ['MBBS', 'FRCOphth'],
  },
  {
    name: 'Dr. Hugo Lindqvist',
    photoUrl: 'assets/images/doctors/lindqvist.png',
    specialty: 'Orthopedist',
    specialtyField: 'Orthopedics',
    rating: 4.7,
    pricePerSession: 110,
    yearsExperience: 16,
    patientCount: 2100,
    followUpFee: 55,
    bio: 'Dr. Hugo Lindqvist is an orthopaedic surgeon specialising in knee and shoulder injuries, and in getting people back to sport after them.',
    qualifications: ['MD', 'FRCS (Orth)'],
  },
];

async function seed() {
  await connectDatabase();

  await DoctorModel.deleteMany({});
  const created = await DoctorModel.insertMany(doctors);
  console.log(`Seeded ${created.length} doctors`);

  // A known account so the app can be signed into immediately. Skipped if it
  // already exists, so re-seeding never clobbers a changed password.
  const email = 'ada@example.com';
  const existing = await UserModel.findOne({ email });
  if (!existing) {
    await UserModel.create({
      name: 'Ada Lovelace',
      email,
      passwordHash: await hashPassword('medico1234'),
    });
    console.log(`Seeded demo patient ${email} / medico1234`);
  } else {
    console.log(`Demo patient ${email} already exists, left alone`);
  }

  await seedConversations();

  await disconnectDatabase();
}

/**
 * A couple of conversations for the demo patient, so the Messages tab has
 * something in it on a fresh database. Skipped if there are any already, so
 * re-seeding never doubles them up or resurrects one the patient replied to.
 */
async function seedConversations() {
  const patient = await UserModel.findOne({ email: 'ada@example.com' });
  if (!patient) return;

  if (await ThreadModel.countDocuments({ patientId: patient._id })) {
    console.log('Demo patient already has conversations, left alone');
    return;
  }

  const moore = await DoctorModel.findOne({ name: 'Dr. Thomas Moore' });
  const hour = 60 * 60 * 1000;
  const now = Date.now();

  const conversations = [
    {
      subject: 'Blood pressure review',
      aboutDoctorId: moore?._id ?? null,
      messages: [
        {
          from: 'patient' as const,
          body: 'I have been taking the readings twice a day as asked. They are '
            + 'coming out around 140 over 90 in the mornings.',
          at: now - 30 * hour,
        },
        {
          from: 'clinic' as const,
          body: 'Thank you for sending those through. Please keep going with the '
            + 'same dose until your appointment, and bring the readings with you.',
          at: now - 28 * hour,
        },
      ],
      unread: 1,
    },
    {
      subject: 'Repeat prescription',
      aboutDoctorId: null,
      messages: [
        {
          from: 'patient' as const,
          body: 'Could I have another month of the same prescription please?',
          at: now - 4 * 24 * hour,
        },
        {
          from: 'clinic' as const,
          body: 'That is ready at the pharmacy from tomorrow morning.',
          at: now - 4 * 24 * hour + hour,
        },
      ],
      unread: 0,
    },
  ];

  for (const conversation of conversations) {
    const last = conversation.messages[conversation.messages.length - 1]!;

    const thread = await ThreadModel.create({
      patientId: patient._id,
      subject: conversation.subject,
      aboutDoctorId: conversation.aboutDoctorId,
      lastMessageAt: new Date(last.at),
      lastMessagePreview: last.body,
      lastMessageFrom: last.from,
      unreadForPatient: conversation.unread,
    });

    await MessageModel.insertMany(
      conversation.messages.map((message, index) => ({
        threadId: thread._id,
        from: message.from,
        body: message.body,
        sentAt: new Date(message.at),
        readAt:
          message.from === 'clinic' && index < conversation.messages.length - conversation.unread
            ? new Date(message.at)
            : null,
      })),
    );
  }

  console.log(`Seeded ${conversations.length} conversations for ada@example.com`);
}

seed().catch((error) => {
  console.error('Seed failed', error);
  process.exit(1);
});
