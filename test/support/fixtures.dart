import 'package:medico/features/appointments/data/appointment.dart';
import 'package:medico/features/doctors/data/doctor.dart';
import 'package:medico/features/messages/data/message.dart';
import 'package:medico/features/profile/data/profile.dart';

/// The directory the screens used to carry in their own source.
///
/// It lived in `lib/features/doctors/data/doctor.dart` until the client was
/// wired to the API, and it is kept here for one reason: the golden renders
/// were recorded against these five doctors, so a test that feeds them back in
/// is comparing the screen against the screen, not against a change in the
/// data.
///
/// It is deliberately *not* an exact copy of `server/src/seed.ts`, which has a
/// sixth doctor covering Eye care. Leaving that field empty here is what keeps
/// the "no doctors in this specialty" state reachable from a test.
const List<Doctor> kSampleDoctors = [
  Doctor(
    id: 'd1',
    photo: 'assets/images/doctors/james.png',
    name: 'Dr. William James',
    specialty: 'Neurologist',
    rating: 4.8,
    pricePerSession: 95,
    openSlots: 8,
  ),
  Doctor(
    id: 'd2',
    photo: 'assets/images/doctors/moore.png',
    name: 'Dr. Thomas Moore',
    specialty: 'Cardiologist',
    rating: 4.8,
    pricePerSession: 84,
    openSlots: 5,
    qualifications: [
      'MBBS',
      'FCPS',
      'FRCP (Edin)',
      'FCCP (USA)',
      'FACC (USA)',
      'FESC',
    ],
    yearsExperience: 12,
    patientCount: 2500,
    followUpFee: 40,
    sessionMinutes: 30,
    bio: 'Dr. Thomas Moore is a board-certified cardiologist with over 12 '
        'years of experience in cardiovascular medicine. He specialises in '
        'interventional cardiology, heart failure management and preventive '
        'care, and runs the clinic\'s arrhythmia service. He sees patients '
        'referred for chest pain, palpitations and blood pressure that has '
        'not settled on first-line treatment.',
    experience: [
      Credential(
        title: 'Consultant Cardiologist',
        place: 'Medico Heart Centre',
        period: '2019 — now',
      ),
      Credential(
        title: 'Interventional Cardiology Fellow',
        place: 'St Vincent\'s Hospital',
        period: '2016 — 2019',
      ),
      Credential(
        title: 'Registrar, Internal Medicine',
        place: 'Royal City Hospital',
        period: '2013 — 2016',
      ),
    ],
    education: [
      Credential(
        title: 'Fellowship, Cardiology',
        place: 'Royal College of Physicians, Edinburgh',
        period: '2018',
      ),
      Credential(
        title: 'FCPS, Internal Medicine',
        place: 'College of Physicians and Surgeons',
        period: '2015',
      ),
      Credential(
        title: 'MBBS',
        place: 'University Medical School',
        period: '2011',
      ),
    ],
    reviews: [
      Review(
        author: 'Hannah W.',
        rating: 5,
        body: 'Explained my results in plain language and drew me a diagram. '
            'First time I have understood my own heart.',
        when: '2 weeks ago',
      ),
      Review(
        author: 'Marcus T.',
        rating: 5,
        body: 'Ran late by about fifteen minutes, but he did not rush me '
            'once he started. Worth the wait.',
        when: 'last month',
      ),
      Review(
        author: 'Priya S.',
        rating: 4,
        body: 'Very thorough. I would have liked more time to ask questions '
            'at the end of the appointment.',
        when: 'last month',
      ),
    ],
  ),
  Doctor(
    id: 'd3',
    photo: 'assets/images/doctors/farouk.png',
    name: 'Dr. Amina Farouk',
    specialty: 'Pulmonologist',
    rating: 4.9,
    pricePerSession: 78,
    openSlots: 12,
  ),
  Doctor(
    id: 'd4',
    photo: 'assets/images/doctors/raman.png',
    name: 'Dr. Priya Raman',
    specialty: 'Paediatrician',
    rating: 5.0,
    pricePerSession: 70,
    openSlots: 3,
  ),
  Doctor(
    id: 'd5',
    photo: 'assets/images/doctors/lindqvist.png',
    name: 'Dr. Hugo Lindqvist',
    specialty: 'Orthopedist',
    rating: 4.7,
    pricePerSession: 110,
    openSlots: 6,
  ),
];

/// The fields the rail shows in the golden renders.
///
/// The real `GET /doctors/specialties` sorts by field and reports only fields
/// that have a doctor in them, so it would never send 'Eye care'. This list is
/// the rail as it was recorded — catalogue order, and one field with nobody in
/// it, which is what keeps the empty-results state reachable from a test.
const List<String> kSampleSpecialtyFields = [
  'Neurology',
  'Cardiology',
  'Pulmonology',
  'Orthopedics',
  'Paediatrics',
  'Eye care',
];

/// A fixed clock. "Upcoming" is a question about the time, so a golden render
/// of this screen has to be told what time it is or it changes by itself
/// overnight.
final DateTime kNow = DateTime.utc(2026, 9, 22, 12);

Doctor _doctor(String id) =>
    kSampleDoctors.firstWhere((doctor) => doctor.id == id);

/// One of each state the appointments screen can show.
final List<Appointment> kSampleAppointments = [
  Appointment(
    id: 'a1',
    startsAt: DateTime.utc(2026, 9, 23, 9),
    endsAt: DateTime.utc(2026, 9, 23, 9, 30),
    doctor: _doctor('d2'),
    reason: 'Blood pressure review, and the palpitations are back.',
  ),
  Appointment(
    id: 'a2',
    startsAt: DateTime.utc(2026, 9, 28, 14, 30),
    endsAt: DateTime.utc(2026, 9, 28, 15),
    doctor: _doctor('d4'),
  ),
  Appointment(
    id: 'a3',
    startsAt: DateTime.utc(2026, 9, 15, 11),
    endsAt: DateTime.utc(2026, 9, 15, 11, 30),
    doctor: _doctor('d1'),
  ),
  Appointment(
    id: 'a4',
    startsAt: DateTime.utc(2026, 9, 30, 10),
    endsAt: DateTime.utc(2026, 9, 30, 10, 30),
    doctor: _doctor('d5'),
    isCancelled: true,
  ),
];

/// Two conversations with the practice: one waiting on the patient to read,
/// one they have already dealt with. Mirrors what `npm run seed` writes.
final List<MessageThread> kSampleThreads = [
  MessageThread(
    id: 't1',
    subject: 'Blood pressure review',
    aboutDoctor: _doctor('d2'),
    lastMessageAt: kNow.subtract(const Duration(hours: 2)),
    lastMessagePreview: 'Thank you for sending those through. Please keep '
        'going with the same dose until your appointment.',
    lastMessageFrom: MessageAuthor.clinic,
    unreadCount: 1,
  ),
  MessageThread(
    id: 't2',
    subject: 'Repeat prescription',
    lastMessageAt: kNow.subtract(const Duration(days: 4)),
    lastMessagePreview: 'That is ready at the pharmacy from tomorrow morning.',
    lastMessageFrom: MessageAuthor.clinic,
  ),
];

/// The messages inside those conversations, oldest first.
final Map<String, List<Message>> kSampleMessages = {
  't1': [
    Message(
      id: 'm1',
      from: MessageAuthor.patient,
      body: 'I have been taking the readings twice a day as asked. They are '
          'coming out around 140 over 90 in the mornings.',
      sentAt: kNow.subtract(const Duration(hours: 30)),
    ),
    Message(
      id: 'm2',
      from: MessageAuthor.clinic,
      body: 'Thank you for sending those through. Please keep going with the '
          'same dose until your appointment, and bring the readings with you.',
      sentAt: kNow.subtract(const Duration(hours: 2)),
    ),
  ],
  't2': [
    Message(
      id: 'm3',
      from: MessageAuthor.patient,
      body: 'Could I have another month of the same prescription please?',
      sentAt: kNow.subtract(const Duration(days: 5)),
    ),
    Message(
      id: 'm4',
      from: MessageAuthor.clinic,
      body: 'That is ready at the pharmacy from tomorrow morning.',
      sentAt: kNow.subtract(const Duration(days: 4)),
    ),
  ],
};

/// The signed-in patient as `GET /me` describes them.
final Profile kDemoProfile = Profile(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  memberSince: DateTime.utc(2026, 3, 14),
  savedDoctors: 3,
  upcomingAppointments: 2,
  unreadThreads: 1,
);
