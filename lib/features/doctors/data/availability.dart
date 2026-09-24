/// One bookable time.
///
/// The server sends both the instant and the label. Keeping the label rather
/// than formatting `startsAt` on the client means the chip shows the clinic's
/// 09:30 — the time on the appointment card the patient will be handed — and
/// not 09:30 shifted into whatever timezone the phone is in.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startsAt,
    required this.label,
    required this.available,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      startsAt:
          DateTime.tryParse((json['startsAt'] ?? '') as String)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      label: (json['label'] ?? '') as String,
      available: json['available'] == true,
    );
  }

  /// The instant the appointment begins, in UTC — what `POST /appointments`
  /// takes back.
  final DateTime startsAt;

  /// "09:30", as the clinic reckons it.
  final String label;

  final bool available;
}

/// A day of a doctor's diary, as `/doctors/:id/availability` returns it.
class AvailabilityDay {
  const AvailabilityDay({
    required this.date,
    required this.weekday,
    required this.slots,
    required this.openCount,
  });

  factory AvailabilityDay.fromJson(Map<String, dynamic> json) {
    final slots = (json['slots'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(AvailabilitySlot.fromJson)
            .toList(growable: false) ??
        const <AvailabilitySlot>[];

    return AvailabilityDay(
      date: DateTime.tryParse((json['date'] ?? '') as String) ?? DateTime.now(),
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      slots: slots,
      openCount: (json['openCount'] as num?)?.toInt() ??
          slots.where((slot) => slot.available).length,
    );
  }

  /// Midnight of the day, as a plain calendar date.
  final DateTime date;

  /// 1 = Monday … 7 = Sunday, matching Dart's own `DateTime.weekday`.
  final int weekday;

  final List<AvailabilitySlot> slots;

  /// Slots still free. A closed day is an empty list, not an absent day — the
  /// week strip needs somewhere to put "no slots".
  final int openCount;

  bool sameDayAs(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}
