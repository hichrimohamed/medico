import 'package:flutter/material.dart';

/// A clinical specialty.
///
/// Two names, deliberately: the rail browses by field ("Neurology" — short
/// enough to fit a chip without breaking mid-word), while a doctor is labelled
/// by what they are ("Neurologist").
class Specialty {
  const Specialty({
    required this.field,
    required this.practitioner,
    required this.icon,
  });

  final String field;
  final String practitioner;
  final IconData icon;
}

class Credential {
  const Credential({
    required this.title,
    required this.place,
    required this.period,
  });

  factory Credential.fromJson(Map<String, dynamic> json) => Credential(
        title: (json['title'] ?? '') as String,
        place: (json['place'] ?? '') as String,
        period: (json['period'] ?? '') as String,
      );

  final String title;
  final String place;
  final String period;
}

class Review {
  const Review({
    required this.author,
    required this.rating,
    required this.body,
    required this.when,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        author: (json['author'] ?? '') as String,
        rating: _toDouble(json['rating']),
        body: (json['body'] ?? '') as String,
        when: (json['when'] ?? '') as String,
      );

  final String author;
  final double rating;
  final String body;
  final String when;
}

class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.pricePerSession,
    this.specialtyField = '',
    this.openSlots = 0,
    this.photo,
    this.qualifications = const [],
    this.yearsExperience = 0,
    this.patientCount = 0,
    this.bio = '',
    this.followUpFee = 0,
    this.followUpWindowDays = 30,
    this.sessionMinutes = 30,
    this.experience = const [],
    this.education = const [],
    this.reviews = const [],
  });

  final String id;
  final String name;

  /// What this doctor is called — "Cardiologist".
  final String specialty;

  /// What they practise — "Cardiology". The rail filters on this one; the
  /// server stores both rather than have either side derive one from the other
  /// with string surgery.
  final String specialtyField;

  final double rating;
  final int pricePerSession;

  /// Free slots in the week being shown. Not stored by the server — slots are
  /// generated on read — so it is filled in from `/doctors/:id/availability`
  /// where a screen has asked for it, and left at zero where it has not.
  final int openSlots;

  /// The doctor's portrait, as the server names it.
  ///
  /// Today that is a bundled asset path — the illustrated avatars ship with
  /// the app, so a directory renders with no image requests at all. It may
  /// equally be an `https://` URL once the practice hosts real photographs;
  /// [MedicoAvatar] draws either, and falls back to initials when it is null
  /// or cannot be loaded. A grey silhouette reads as a broken image, and a
  /// patient who thinks the app is broken does not book an appointment.
  final String? photo;

  final List<String> qualifications;
  final int yearsExperience;
  final int patientCount;
  final String bio;

  /// Charged for a second appointment inside [followUpWindowDays].
  final int followUpFee;
  final int followUpWindowDays;
  final int sessionMinutes;

  final List<Credential> experience;
  final List<Credential> education;
  final List<Review> reviews;

  /// Built from `GET /doctors` and `GET /doctors/:id`, which return the same
  /// shape — the list is not a thinner projection, so one reader serves both.
  ///
  /// Every field is defaulted rather than asserted. A directory that refuses
  /// to render because one doctor is missing a bio is worse than one that
  /// renders the doctor without it.
  factory Doctor.fromJson(Map<String, dynamic> json, {int openSlots = 0}) {
    return Doctor(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      specialty: (json['specialty'] ?? '') as String,
      specialtyField: (json['specialtyField'] ?? '') as String,
      rating: _toDouble(json['rating']),
      pricePerSession: _toInt(json['pricePerSession']),
      openSlots: openSlots,
      qualifications: _toStringList(json['qualifications']),
      yearsExperience: _toInt(json['yearsExperience']),
      patientCount: _toInt(json['patientCount']),
      bio: (json['bio'] ?? '') as String,
      photo: json['photoUrl'] as String?,
      followUpFee: _toInt(json['followUpFee']),
      followUpWindowDays: _toInt(json['followUpWindowDays'], fallback: 30),
      sessionMinutes: _toInt(json['sessionMinutes'], fallback: 30),
      experience: _toList(json['experience'], Credential.fromJson),
      education: _toList(json['education'], Credential.fromJson),
      reviews: _toList(json['reviews'], Review.fromJson),
    );
  }

  /// The same doctor with a slot count attached, so the card can say "8 slots"
  /// without the model having to be mutable.
  Doctor withOpenSlots(int count) => Doctor(
        id: id,
        name: name,
        specialty: specialty,
        specialtyField: specialtyField,
        rating: rating,
        pricePerSession: pricePerSession,
        openSlots: count,
        photo: photo,
        qualifications: qualifications,
        yearsExperience: yearsExperience,
        patientCount: patientCount,
        bio: bio,
        followUpFee: followUpFee,
        followUpWindowDays: followUpWindowDays,
        sessionMinutes: sessionMinutes,
        experience: experience,
        education: education,
        reviews: reviews,
      );

  /// "MBBS, FCPS, FRCP (Edin)" — empty when nothing is on file.
  String get qualificationLine => qualifications.join(', ');

  /// "2500+" once the count is round enough to be an approximation.
  String get patientCountLabel =>
      patientCount >= 1000 ? '$patientCount+' : '$patientCount';

  /// Surname only, for the compact card headings.
  String get initials {
    final parts = name.replaceFirst('Dr. ', '').split(' ')
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// The specialties the rail can show.
///
/// This stays on the client on purpose. `GET /doctors/specialties` knows which
/// fields have doctors in them and how many — it does not know what a
/// Pulmonologist is called or which glyph means "lungs", and it should not:
/// those are typography and iconography, and they belong to the design system.
/// The API says *which*, this says *how it looks*, and [SpecialtyCatalogue.byField]
/// is where the two meet.
abstract final class SpecialtyCatalogue {
  const SpecialtyCatalogue._();

  static const List<Specialty> specialties = [
    Specialty(
      field: 'Neurology',
      practitioner: 'Neurologist',
      icon: Icons.psychology_outlined,
    ),
    Specialty(
      field: 'Cardiology',
      practitioner: 'Cardiologist',
      icon: Icons.monitor_heart_outlined,
    ),
    Specialty(
      field: 'Pulmonology',
      practitioner: 'Pulmonologist',
      icon: Icons.air_rounded,
    ),
    Specialty(
      field: 'Orthopedics',
      practitioner: 'Orthopedist',
      icon: Icons.personal_injury_outlined,
    ),
    Specialty(
      field: 'Paediatrics',
      practitioner: 'Paediatrician',
      icon: Icons.child_care_outlined,
    ),
    Specialty(
      field: 'Eye care',
      practitioner: 'Ophthalmologist',
      icon: Icons.visibility_outlined,
    ),
  ];

  /// The catalogue entry for a field the server reported.
  ///
  /// A field with no entry here — a specialty added to the clinic before the
  /// app ships an icon for it — still gets a chip, with a generic glyph and
  /// the field as its own practitioner label. Showing it plainly beats hiding
  /// a doctor the patient could have booked.
  static Specialty byField(String field) {
    for (final specialty in specialties) {
      if (specialty.field.toLowerCase() == field.toLowerCase()) {
        return specialty;
      }
    }
    return Specialty(
      field: field,
      practitioner: field,
      icon: Icons.medical_services_outlined,
    );
  }
}

// ---------------------------------------------------------------- JSON bits

double _toDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _toStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

List<T> _toList<T>(Object? value, T Function(Map<String, dynamic>) read) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(read)
      .toList(growable: false);
}

/// Month names without pulling in `intl` for one label.
const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> kWeekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];
