import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/appointments/data/appointment.dart';
import 'package:medico/features/doctors/data/doctor_repository.dart';
import 'package:medico/features/doctors/data/patient_repository.dart';

/// One doctor exactly as `GET /doctors` sends them, fields and all.
const Map<String, dynamic> _moore = {
  'id': '68c1f0a1b2c3d4e5f6a7b8c9',
  'name': 'Dr. Thomas Moore',
  'specialty': 'Cardiologist',
  'specialtyField': 'Cardiology',
  'rating': 4.8,
  'pricePerSession': 84,
  'sessionMinutes': 30,
  'followUpFee': 40,
  'followUpWindowDays': 30,
  'qualifications': ['MBBS', 'FCPS'],
  'yearsExperience': 12,
  'patientCount': 2500,
  'bio': 'A cardiologist.',
  'experience': [
    {
      'title': 'Consultant Cardiologist',
      'place': 'Medico Heart Centre',
      'period': '2019 — now',
    },
  ],
  'education': [
    {'title': 'MBBS', 'place': 'University Medical School', 'period': '2011'},
  ],
  'reviews': [
    {
      'author': 'Hannah W.',
      'rating': 5,
      'body': 'Clear and kind.',
      'when': '2 weeks ago',
    },
  ],
};

/// `http.Response(String, …)` encodes as latin-1 unless a charset says
/// otherwise, and these fixtures carry the em dashes the real records do.
/// Building from bytes keeps the test honest about what a server sends.
http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

({ApiClient api, List<Uri> urls}) _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  final urls = <Uri>[];
  return (
    api: ApiClient(
      baseUrl: 'https://api.test/v1',
      session: SessionController(store: InMemorySessionStore()),
      httpClient: MockClient((request) {
        urls.add(request.url);
        return handler(request);
      }),
    ),
    urls: urls,
  );
}

void main() {
  group('doctors', () {
    test('the list is read whole, with every nested credential', () async {
      final client = _client((request) async => _ok({
            'doctors': [_moore],
            'page': 1,
            'perPage': 50,
            'total': 1,
            'hasMore': false,
          }));

      final doctors = await HttpDoctorRepository(client.api).list();

      expect(doctors, hasLength(1));
      final moore = doctors.single;
      expect(moore.id, '68c1f0a1b2c3d4e5f6a7b8c9');
      expect(moore.name, 'Dr. Thomas Moore');
      expect(moore.specialty, 'Cardiologist');
      expect(moore.specialtyField, 'Cardiology');
      expect(moore.rating, 4.8);
      expect(moore.pricePerSession, 84);
      expect(moore.qualificationLine, 'MBBS, FCPS');
      expect(moore.patientCountLabel, '2500+');
      expect(moore.initials, 'TM');
      expect(moore.experience.single.place, 'Medico Heart Centre');
      expect(moore.experience.single.period, '2019 — now',
          reason: 'an em dash must survive the wire');
      expect(moore.education.single.period, '2011');
      expect(moore.reviews.single.author, 'Hannah W.');
    });

    test('a filter goes to the server as the field, not the practitioner',
        () async {
      final client = _client((request) async => _ok({'doctors': []}));

      await HttpDoctorRepository(client.api)
          .list(specialtyField: 'Cardiology', query: '  moore  ');

      expect(client.urls.single.queryParameters['specialty'], 'Cardiology');
      expect(client.urls.single.queryParameters['q'], 'moore');
    });

    test('a doctor missing half their record still renders', () async {
      final client = _client((request) async => _ok({
            'doctors': [
              {'id': 'd9', 'name': 'Dr. New Start', 'specialty': 'Neurologist'},
            ],
          }));

      final doctor = (await HttpDoctorRepository(client.api).list()).single;

      // A directory that refuses to draw because one bio is missing is worse
      // than one that draws the doctor without it.
      expect(doctor.name, 'Dr. New Start');
      expect(doctor.rating, 0);
      expect(doctor.bio, isEmpty);
      expect(doctor.qualifications, isEmpty);
      expect(doctor.sessionMinutes, 30, reason: 'the schema default');
    });

    test('specialties come back as fields in the server order', () async {
      final client = _client((request) async => _ok({
            'specialties': [
              {'field': 'Cardiology', 'doctorCount': 1},
              {'field': 'Neurology', 'doctorCount': 1},
            ],
          }));

      expect(
        await HttpDoctorRepository(client.api).specialtyFields(),
        ['Cardiology', 'Neurology'],
      );
    });

    test("availability keeps the clinic's own label and the real instant",
        () async {
      final client = _client((request) async => _ok({
            'doctorId': 'd2',
            'sessionMinutes': 30,
            'days': [
              {
                'date': '2026-09-22',
                'weekday': 2,
                'openCount': 1,
                'slots': [
                  {
                    'startsAt': '2026-09-22T09:00:00.000Z',
                    'label': '09:00',
                    'available': true,
                  },
                  {
                    'startsAt': '2026-09-22T09:30:00.000Z',
                    'label': '09:30',
                    'available': false,
                  },
                ],
              },
            ],
          }));

      final week = await HttpDoctorRepository(client.api).availability(
        'd2',
        from: DateTime.utc(2026, 9, 22),
        days: 7,
      );

      expect(client.urls.single.queryParameters['days'], '7');
      expect(client.urls.single.path, '/v1/doctors/d2/availability');

      final day = week.single;
      expect(day.weekday, 2);
      expect(day.openCount, 1);
      expect(day.sameDayAs(DateTime(2026, 9, 22)), isTrue);
      expect(day.slots.first.label, '09:00');
      expect(day.slots.first.startsAt, DateTime.utc(2026, 9, 22, 9));
      expect(day.slots.last.available, isFalse);
    });
  });

  group('the patient', () {
    test('saved doctors come back as a set of ids', () async {
      final client = _client((request) async => _ok({
            'doctors': [_moore],
          }));

      final saved = await HttpPatientRepository(client.api).favourites();

      expect(saved.single.id, '68c1f0a1b2c3d4e5f6a7b8c9');
      expect(saved.single.name, 'Dr. Thomas Moore',
          reason: 'the endpoint populates them, so the list screen needs no '
              'second request');
    });

    test('the heart is one control over two verbs', () async {
      final methods = <String>[];
      final client = _client((request) async {
        methods.add('${request.method} ${request.url.path}');
        return http.Response('', 204);
      });

      final patient = HttpPatientRepository(client.api);
      await patient.setFavourite('d2', saved: true);
      await patient.setFavourite('d2', saved: false);

      expect(methods, [
        'PUT /v1/me/favourites/d2',
        'DELETE /v1/me/favourites/d2',
      ]);
    });

    test('a booking sends the instant, in UTC', () async {
      late Map<String, dynamic> sent;
      final client = _client((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok({'id': 'a1'}, 201);
      });

      await HttpPatientRepository(client.api).book(
        doctorId: 'd2',
        // A local time, as the screen holds it.
        startsAt: DateTime.utc(2026, 9, 23, 9, 30).toLocal(),
        reason: '  chest pain  ',
      );

      expect(sent['doctorId'], 'd2');
      expect(
        DateTime.parse(sent['startsAt'] as String).toUtc(),
        DateTime.utc(2026, 9, 23, 9, 30),
        reason: 'the server books on the instant, not on a wall clock',
      );
      expect(sent['reason'], 'chest pain');
    });

    test('the appointments list carries the filter the screen chose', () async {
      final client = _client((request) async => _ok({
            'appointments': [
              {
                'id': 'a1',
                'doctorId': _moore,
                'startsAt': '2026-09-23T09:00:00.000Z',
                'endsAt': '2026-09-23T09:30:00.000Z',
                'status': 'booked',
                'reason': 'Blood pressure review',
              },
            ],
          }));

      final appointments = await HttpPatientRepository(client.api)
          .appointments(AppointmentFilter.past);

      expect(client.urls.single.path, '/v1/appointments');
      expect(client.urls.single.queryParameters['status'], 'booked');
      expect(client.urls.single.queryParameters['when'], 'past');

      final appointment = appointments.single;
      expect(appointment.id, 'a1');
      expect(appointment.doctor.name, 'Dr. Thomas Moore');
      expect(appointment.clinicTime, '09:00');
      expect(appointment.reason, 'Blood pressure review');
    });

    test('cancelling posts to the appointment, and nothing else', () async {
      final methods = <String>[];
      final client = _client((request) async {
        methods.add('${request.method} ${request.url.path}');
        return _ok({'id': 'a1', 'status': 'cancelled'});
      });

      await HttpPatientRepository(client.api).cancelAppointment('a1');

      expect(methods, ['POST /v1/appointments/a1/cancel']);
    });

    test('an empty reason is left out rather than sent blank', () async {
      late Map<String, dynamic> sent;
      final client = _client((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok({'id': 'a1'}, 201);
      });

      await HttpPatientRepository(client.api).book(
        doctorId: 'd2',
        startsAt: DateTime.utc(2026, 9, 23, 9, 30),
        reason: '   ',
      );

      expect(sent.containsKey('reason'), isFalse);
    });
  });
}
