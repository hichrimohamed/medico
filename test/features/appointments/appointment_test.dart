import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/appointments/data/appointment.dart';
import 'package:medico/features/doctors/data/availability.dart';

/// One appointment as `GET /appointments` sends it, doctor populated.
const Map<String, dynamic> _booked = {
  'id': 'a1',
  'patientId': 'u1',
  'doctorId': {
    'id': 'd2',
    'name': 'Dr. Thomas Moore',
    'specialty': 'Cardiologist',
    'specialtyField': 'Cardiology',
    'rating': 4.8,
    'pricePerSession': 84,
  },
  'startsAt': '2026-09-23T09:00:00.000Z',
  'endsAt': '2026-09-23T09:30:00.000Z',
  'status': 'booked',
  'cancelledAt': null,
  'reason': 'Blood pressure review',
};

void main() {
  test('the populated doctor is read, so a list is one request', () {
    final appointment = Appointment.fromJson(_booked);

    expect(appointment.id, 'a1');
    expect(appointment.doctor.name, 'Dr. Thomas Moore');
    expect(appointment.doctor.specialty, 'Cardiologist');
    expect(appointment.reason, 'Blood pressure review');
    expect(appointment.isCancelled, isFalse);
  });

  test('an unpopulated doctor still leaves an appointment to turn up to', () {
    final appointment = Appointment.fromJson({
      ..._booked,
      'doctorId': '68c1f0a1b2c3d4e5f6a7b8c9',
    });

    expect(appointment.doctor.name, 'Your doctor');
    expect(appointment.startsAt, DateTime.utc(2026, 9, 23, 9));
  });

  test('where it stands is read off the clock, not stored', () {
    final appointment = Appointment.fromJson(_booked);

    expect(
      appointment.stateAt(DateTime.utc(2026, 9, 22, 12)),
      AppointmentState.scheduled,
    );
    expect(
      appointment.stateAt(DateTime.utc(2026, 9, 23, 9, 15)),
      AppointmentState.inProgress,
    );
    expect(
      appointment.stateAt(DateTime.utc(2026, 9, 23, 10)),
      AppointmentState.completed,
    );
  });

  test('a cancelled appointment is cancelled whenever you ask', () {
    final appointment =
        Appointment.fromJson({..._booked, 'status': 'cancelled'});

    for (final when in [
      DateTime.utc(2026, 9, 22),
      DateTime.utc(2026, 9, 23, 9, 15),
      DateTime.utc(2027),
    ]) {
      expect(appointment.stateAt(when), AppointmentState.cancelled);
      expect(appointment.canCancelAt(when), isFalse);
    }
  });

  test('only an appointment still ahead can be cancelled', () {
    final appointment = Appointment.fromJson(_booked);

    expect(appointment.canCancelAt(DateTime.utc(2026, 9, 22)), isTrue);
    expect(appointment.canCancelAt(DateTime.utc(2026, 9, 23, 9, 15)), isFalse);
    expect(appointment.canCancelAt(DateTime.utc(2026, 9, 24)), isFalse);
  });

  test('the time shown is the one on the slot that was booked', () {
    // The invariant that matters: a patient who tapped the 09:00 chip must not
    // open this screen and read 11:00. The label comes from the server, the
    // appointment time is formatted here, and the two have to agree.
    const slot = {
      'startsAt': '2026-09-23T09:00:00.000Z',
      'label': '09:00',
      'available': true,
    };
    final booked = AvailabilitySlot.fromJson(slot);
    final appointment = Appointment.fromJson({
      ..._booked,
      'startsAt': booked.startsAt.toIso8601String(),
    });

    expect(appointment.clinicTime, booked.label);
    expect(appointment.clinicEndTime, '09:30');
  });

  test('the date reads the way a person says it', () {
    final appointment = Appointment.fromJson(_booked);

    expect(appointment.dayLabel, 'Wed 23 Sep');
    expect(appointment.dayOfMonth, '23');
    expect(appointment.monthShort, 'Sep');
  });

  test('a record with nothing usable in it does not throw', () {
    final appointment = Appointment.fromJson(const {});

    expect(appointment.id, isEmpty);
    expect(appointment.doctor.name, 'Your doctor');
    expect(appointment.stateAt(DateTime.utc(2026)), AppointmentState.completed);
  });
}
