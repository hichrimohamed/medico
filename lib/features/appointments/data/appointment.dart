import '../../doctors/data/doctor.dart';

/// Which appointments a patient is asking to see.
///
/// The two wire values are what `GET /appointments` takes. They are paired
/// here rather than at the call site because the pairing is the meaning:
/// "Past" is appointments that were kept, not everything with a date behind
/// it, and a cancelled one belongs under Cancelled whichever side of today it
/// falls on. Between them the three cover every appointment exactly once.
enum AppointmentFilter {
  upcoming('Upcoming', status: 'booked', when: 'upcoming'),
  past('Past', status: 'booked', when: 'past'),
  cancelled('Cancelled', status: 'cancelled', when: 'all');

  const AppointmentFilter(this.label, {required this.status, required this.when});

  final String label;
  final String status;
  final String when;
}

/// Where an appointment stands right now.
///
/// Derived from the clock rather than stored: the server records `booked` or
/// `cancelled`, and whether a booked appointment is still ahead, happening, or
/// done is a question about the time, not a third state to keep in sync.
enum AppointmentState { scheduled, inProgress, completed, cancelled }

/// One booked slot, with enough of the doctor attached to draw a card.
///
/// `GET /appointments` populates the doctor with name, specialty, rating and
/// price, so a list of six appointments is one request rather than seven.
class Appointment {
  const Appointment({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.doctor,
    this.isCancelled = false,
    this.reason = '',
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctorId'];

    return Appointment(
      id: (json['id'] ?? '') as String,
      startsAt: _instant(json['startsAt']),
      endsAt: _instant(json['endsAt']),
      isCancelled: json['status'] == 'cancelled',
      reason: (json['reason'] ?? '') as String,
      doctor: doctor is Map<String, dynamic>
          ? Doctor.fromJson(doctor)
          // Not populated — an appointment with a doctor we cannot name is
          // still an appointment the patient has to turn up to.
          : const Doctor(
              id: '',
              name: 'Your doctor',
              specialty: '',
              rating: 0,
              pricePerSession: 0,
            ),
    );
  }

  final String id;

  /// In UTC, which is also the clinic's clock — see [clinicHour].
  final DateTime startsAt;
  final DateTime endsAt;

  final Doctor doctor;
  final bool isCancelled;
  final String reason;

  AppointmentState stateAt(DateTime now) {
    if (isCancelled) return AppointmentState.cancelled;
    final at = now.toUtc();
    if (at.isAfter(endsAt)) return AppointmentState.completed;
    if (at.isAfter(startsAt)) return AppointmentState.inProgress;
    return AppointmentState.scheduled;
  }

  /// Only a scheduled appointment can be called off. One that has already
  /// started is a conversation with the clinic, not a button.
  bool canCancelAt(DateTime now) =>
      stateAt(now) == AppointmentState.scheduled;

  /// "09:00" — the clinic's own clock, the same one the slot chip showed when
  /// this was booked.
  ///
  /// Deliberately *not* the device's timezone. The server generates slots in
  /// UTC, so a patient who booked the 09:00 slot must not open this screen and
  /// read 11:00. The day the clinic is not in UTC, both this and the slot
  /// labels move together — see "Time zones" in `server/README.md`.
  String get clinicTime => _hhmm(startsAt);

  String get clinicEndTime => _hhmm(endsAt);

  /// The calendar day, as the clinic reckons it.
  DateTime get clinicDay =>
      DateTime(startsAt.toUtc().year, startsAt.toUtc().month, startsAt.toUtc().day);

  /// "Wed 23 Sep"
  String get dayLabel {
    final day = startsAt.toUtc();
    return '${kWeekdayNames[day.weekday - 1]} ${day.day} '
        '${kMonthNames[day.month - 1].substring(0, 3)}';
  }

  /// The number and the month, for the date block on the card.
  String get dayOfMonth => '${startsAt.toUtc().day}';
  String get monthShort =>
      kMonthNames[startsAt.toUtc().month - 1].substring(0, 3);

  static String _hhmm(DateTime value) {
    final at = value.toUtc();
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  static DateTime _instant(Object? value) =>
      DateTime.tryParse(value is String ? value : '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
