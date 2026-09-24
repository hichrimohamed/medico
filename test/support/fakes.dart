import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/app/app_scope.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/core/auth/session.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/appointments/data/appointment.dart';
import 'package:medico/features/auth/data/auth_service.dart';
import 'package:medico/features/doctors/data/availability.dart';
import 'package:medico/features/doctors/data/doctor.dart';
import 'package:medico/features/doctors/data/doctor_repository.dart';
import 'package:medico/features/doctors/data/patient_repository.dart';
import 'package:medico/features/messages/data/message.dart';
import 'package:medico/features/messages/data/messages_repository.dart';
import 'package:medico/features/profile/data/profile.dart';
import 'package:medico/features/profile/data/profile_repository.dart';

import 'fixtures.dart';

/// A directory that answers from memory.
///
/// It filters the way the server does — by field, against the practitioner
/// name the catalogue pairs with it — so a screen that asks for "Cardiology"
/// gets the cardiologist, and one that asks for a field nobody practises gets
/// the empty state rather than an error.
class FakeDoctorRepository implements DoctorRepository {
  FakeDoctorRepository({
    this.doctors = kSampleDoctors,
    this.fields = kSampleSpecialtyFields,
    this.openCountPerDay = 8,
    this.takenLabels = const {'10:00', '13:30', '15:00'},
    this.failure,
  });

  final List<Doctor> doctors;
  final List<String> fields;
  final int openCountPerDay;

  /// Slots the fake reports as already booked, so the unbookable state is
  /// reachable without a second patient.
  final Set<String> takenLabels;

  /// Thrown instead of answering, for the failure paths.
  final ApiException? failure;

  int listCalls = 0;
  String? lastSpecialtyField;

  @override
  Future<List<Doctor>> list({String? specialtyField, String? query}) async {
    listCalls++;
    lastSpecialtyField = specialtyField;
    if (specialtyField == null || specialtyField.isEmpty) return doctors;

    final practitioner = SpecialtyCatalogue.byField(specialtyField).practitioner;
    return doctors
        .where((doctor) => doctor.specialty == practitioner)
        .toList(growable: false);
  }

  @override
  Future<List<String>> specialtyFields() async => fields;

  @override
  Future<Doctor> byId(String id) async {
    if (failure != null) throw failure!;
    return doctors.firstWhere(
      (doctor) => doctor.id == id,
      orElse: () => throw const ApiException(
        ApiErrorCode.notFound,
        'We could not find that doctor.',
      ),
    );
  }

  @override
  Future<List<AvailabilityDay>> availability(
    String doctorId, {
    DateTime? from,
    int days = 7,
  }) async {
    final start = from ?? DateTime.now();
    return List<AvailabilityDay>.generate(days, (index) {
      final date = DateTime(start.year, start.month, start.day + index);
      return AvailabilityDay(
        date: date,
        weekday: date.weekday,
        slots: List<AvailabilitySlot>.generate(openCountPerDay, (slot) {
          final hour = 9 + slot ~/ 2;
          final minute = slot.isEven ? 0 : 30;
          final label = '${hour.toString().padLeft(2, '0')}:'
              '${minute.toString().padLeft(2, '0')}';
          return AvailabilitySlot(
            startsAt: DateTime.utc(date.year, date.month, date.day, hour, minute),
            label: label,
            available: !takenLabels.contains(label),
          );
        }),
        openCount: openCountPerDay,
      );
    });
  }
}

class FakePatientRepository implements PatientRepository {
  FakePatientRepository({
    Set<String>? favourites,
    List<Appointment>? appointments,
    DateTime? now,
    this.failure,
  })  : favouriteIds = favourites ?? {'d2'},
        _appointments = appointments ?? const [],
        _now = now ?? kNow;

  final Set<String> favouriteIds;
  final List<({String doctorId, DateTime startsAt})> booked = [];

  final List<Appointment> _appointments;

  /// The clock this fake splits upcoming from past on.
  ///
  /// It defaults to [kNow] — the fixed instant the fixtures are written around
  /// and the screens are handed. It used to read `DateTime.now()`, so the
  /// suite agreed with itself only until the real date drifted past a
  /// fixture's: the tests passed on the day they were written and started
  /// failing two days later, which is the worst kind of red.
  final DateTime _now;

  /// Thrown instead of answering, for the failure paths.
  final ApiException? failure;

  /// Thrown on writes only, so a screen can load and then be refused — which
  /// is where the optimistic updates have to put themselves back.
  ApiException? writeFailure;

  final List<String> cancelled = [];
  AppointmentFilter? lastFilter;

  @override
  Future<List<Doctor>> favourites() async {
    if (failure != null) throw failure!;
    return kSampleDoctors
        .where((doctor) => favouriteIds.contains(doctor.id))
        .toList(growable: false);
  }

  @override
  Future<void> setFavourite(String doctorId, {required bool saved}) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;
    if (saved) {
      favouriteIds.add(doctorId);
    } else {
      favouriteIds.remove(doctorId);
    }
  }

  @override
  Future<void> book({
    required String doctorId,
    required DateTime startsAt,
    String? reason,
  }) async {
    booked.add((doctorId: doctorId, startsAt: startsAt));
  }

  /// Filters the way the server does, so a test that switches tabs is
  /// checking the screen and not a list that ignores the question.
  @override
  Future<List<Appointment>> appointments(AppointmentFilter filter) async {
    if (failure != null) throw failure!;
    lastFilter = filter;

    final now = _now.toUtc();
    return _appointments.where((appointment) {
      if (cancelled.contains(appointment.id) || appointment.isCancelled) {
        return filter == AppointmentFilter.cancelled;
      }
      final upcoming = appointment.startsAt.isAfter(now);
      return switch (filter) {
        AppointmentFilter.upcoming => upcoming,
        AppointmentFilter.past => !upcoming,
        AppointmentFilter.cancelled => false,
      };
    }).toList(growable: false);
  }

  @override
  Future<void> cancelAppointment(String id) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;
    cancelled.add(id);
  }
}

/// Conversations from memory, filtered the way the server filters them.
class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({
    List<MessageThread>? threads,
    Map<String, List<Message>>? messages,
    this.failure,
  })  : _threads = [...?threads],
        _messages = {...?messages};

  final List<MessageThread> _threads;
  final Map<String, List<Message>> _messages;

  /// Thrown instead of answering, for the failure paths.
  final ApiException? failure;

  /// Thrown on writes only, so a screen can load and then be refused.
  ApiException? writeFailure;

  final List<String> readThreads = [];
  final List<({String threadId, String body})> sent = [];
  bool? lastUnreadOnly;

  @override
  Future<ThreadList> threads({bool unreadOnly = false}) async {
    if (failure != null) throw failure!;
    lastUnreadOnly = unreadOnly;

    final visible = unreadOnly
        ? _threads.where((thread) => thread.hasUnread).toList(growable: false)
        : List<MessageThread>.unmodifiable(_threads);

    return (
      threads: visible,
      unreadThreads: _threads.where((thread) => thread.hasUnread).length,
    );
  }

  @override
  Future<Conversation> conversation(String threadId) async {
    if (failure != null) throw failure!;
    final thread = _threads.firstWhere(
      (thread) => thread.id == threadId,
      orElse: () => throw const ApiException(
        ApiErrorCode.notFound,
        'We could not find that conversation.',
      ),
    );
    // A copy, not the store's own list. The HTTP repository parses a fresh
    // list on every call, and a fake that hands out its internals lets a
    // screen's own append and the fake's append land on the same object —
    // which shows up as every sent message appearing twice.
    return (
      thread: thread,
      messages: List<Message>.unmodifiable(_messages[threadId] ?? const []),
    );
  }

  @override
  Future<MessageThread> start({
    required String subject,
    required String body,
    String? aboutDoctorId,
  }) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;

    final thread = MessageThread(
      id: 't${_threads.length + 1}',
      subject: subject.trim(),
      lastMessageAt: DateTime.now().toUtc(),
      lastMessagePreview: body.trim(),
      lastMessageFrom: MessageAuthor.patient,
    );
    _threads.insert(0, thread);
    _messages[thread.id] = [
      Message(
        id: 'm-${thread.id}',
        from: MessageAuthor.patient,
        body: body.trim(),
        sentAt: thread.lastMessageAt,
      ),
    ];
    return thread;
  }

  @override
  Future<Message> send(String threadId, String body) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;

    sent.add((threadId: threadId, body: body.trim()));
    final message = Message(
      id: 'm${sent.length}',
      from: MessageAuthor.patient,
      body: body.trim(),
      sentAt: DateTime.now().toUtc(),
    );
    _messages.putIfAbsent(threadId, () => []).add(message);
    return message;
  }

  @override
  Future<void> markRead(String threadId) async {
    if (failure != null) throw failure!;
    readThreads.add(threadId);
  }
}

/// Stand-in for the backend so every screen state is reachable in a test.
///
/// This used to be `DemoAuthService` in `lib/`, and it moved here when the
/// client was wired to the real API — a fake that ships inside the app is one
/// misplaced default away from being the thing that answers a patient.
///
/// Driven by the email:
///   * `locked@…`   → the account-locked path
///   * `offline@…`  → the network-failure path
///   * `taken@…`    → sign-up against an address already registered
///   * password `wrongpass` → the bad-credentials path
///   * anything else → success after a realistic delay
class DemoAuthService implements AuthService {
  const DemoAuthService({
    this.latency = const Duration(milliseconds: 1100),
    this.session,
  });

  final Duration latency;

  /// Given one, this fake moves the session the way the real service does —
  /// which is what lets a test watch the app follow a sign-out back to the
  /// form. Without one it only decides success or failure.
  final SessionController? session;

  @override
  Future<void> signIn({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    await Future<void>.delayed(latency);
    final address = email.trim().toLowerCase();

    if (address.startsWith('offline@')) {
      throw const AuthException(
        AuthFailure.network,
        "We couldn't reach Medico. Check your connection and try again.",
      );
    }
    if (address.startsWith('locked@')) {
      throw const AuthException(
        AuthFailure.accountLocked,
        'This account is locked after too many attempts. Reset your password '
        'to unlock it, or call the clinic on 0800 555 100.',
      );
    }
    if (password == 'wrongpass') {
      throw const AuthException(
        AuthFailure.invalidCredentials,
        "That email and password don't match. Check the password, or reset it "
        'if you are not sure.',
      );
    }
    await session?.begin(kDemoSession, remember: remember);
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (email.trim().toLowerCase().startsWith('taken@')) {
      throw const AuthException(
        AuthFailure.emailTaken,
        'There is already a Medico account with this email. Sign in instead, '
        'or reset the password.',
      );
    }
    await session?.begin(kDemoSession, remember: true);
  }

  @override
  Future<void> signInWithProvider(SsoProvider provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(latency);
    if (email.trim().toLowerCase().startsWith('offline@')) {
      throw const AuthException(
        AuthFailure.network,
        "We couldn't reach Medico. Check your connection and try again.",
      );
    }
  }

  @override
  Future<void> signOut() async => session?.end();
}

/// A profile that answers from memory, and remembers what it was asked.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? profile, this.failure})
      : _profile = profile ?? kDemoProfile;

  Profile _profile;

  /// Thrown instead of answering, for the failure paths.
  final ApiException? failure;

  /// Thrown on writes only, so a screen can load and then be refused.
  ApiException? writeFailure;

  final List<String> renamedTo = [];
  final List<({String current, String next})> passwordChanges = [];
  final List<String> deleteAttempts = [];
  bool deleted = false;

  @override
  Future<Profile> load() async {
    if (failure != null) throw failure!;
    return _profile;
  }

  @override
  Future<Profile> rename(String name) async {
    if (writeFailure != null) throw writeFailure!;
    renamedTo.add(name.trim());
    _profile = Profile(
      id: _profile.id,
      name: name.trim(),
      email: _profile.email,
      memberSince: _profile.memberSince,
      savedDoctors: _profile.savedDoctors,
      upcomingAppointments: _profile.upcomingAppointments,
      unreadThreads: _profile.unreadThreads,
    );
    return _profile;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (writeFailure != null) throw writeFailure!;
    passwordChanges.add((current: currentPassword, next: newPassword));
  }

  @override
  Future<void> deleteAccount(String password) async {
    deleteAttempts.add(password);
    if (writeFailure != null) throw writeFailure!;
    deleted = true;
  }
}

/// A patient who is already signed in, which is the state every screen behind
/// the sign-in form is reached in.
const Session kDemoSession = Session(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  user: MedicoUser(id: 'u1', name: 'Ada Lovelace', email: 'ada@example.com'),
);

/// Services with nothing real behind them, for a widget test that only needs
/// the tree to be well formed.
///
/// Signed in by default: the home and doctor screens ask for saved doctors,
/// and a scope that is signed out would quietly answer "none" and hide the
/// very state a test is checking.
AppServices fakeServices({
  AuthService? auth,
  DoctorRepository? doctors,
  PatientRepository? patient,
  MessagesRepository? messages,
  ProfileRepository? profile,
  Session? signedInAs = kDemoSession,
}) {
  final session = SessionController(store: InMemorySessionStore());
  if (signedInAs != null) {
    session.begin(signedInAs, remember: false);
  }

  return AppServices(
    session: session,
    // A client that refuses rather than one that might connect: a test that
    // reaches the network by accident should fail loudly here, not depend on
    // whether a server happens to be running on the machine.
    //
    // `/auth/me` is the exception. The app checks a restored session against
    // it on every launch, so answering it is part of being a plausible
    // backend rather than a hole in the rule.
    api: ApiClient(
      baseUrl: 'http://localhost:0/api/v1',
      session: session,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(kDemoSession.user.toJson())),
            200,
          );
        }
        throw StateError('Unexpected request in a test: ${request.url}');
      }),
    ),
    auth: auth ?? DemoAuthService(session: session),
    doctors: doctors ?? FakeDoctorRepository(),
    patient: patient ?? FakePatientRepository(),
    messages: messages ?? FakeMessagesRepository(threads: kSampleThreads),
    profile: profile ?? FakeProfileRepository(),
  );
}

/// Wraps [child] in an [AppScope], which is where a screen that was pushed by
/// name finds its services.
Widget withFakeServices(Widget child, {AppServices? services}) {
  return AppScope(services: services ?? fakeServices(), child: child);
}
