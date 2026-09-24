import 'package:flutter/widgets.dart';

import '../core/api/api_client.dart';
import '../core/auth/session_controller.dart';
import '../core/auth/session_store.dart';
import '../core/config/api_config.dart';
import '../features/auth/data/auth_service.dart';
import '../features/auth/data/http_auth_service.dart';
import '../features/doctors/data/doctor_repository.dart';
import '../features/doctors/data/patient_repository.dart';
import '../features/messages/data/messages_repository.dart';
import '../features/profile/data/profile_repository.dart';

/// Everything the screens need that is not a widget.
///
/// Assembled once at the root and handed down. There is no service locator and
/// no dependency-injection package: a screen names what it needs in its
/// constructor, and [AppScope] is only the default supplier when nothing else
/// passed one in. That keeps every screen testable with a plain constructor
/// call, which is how the existing tests are written.
class AppServices {
  AppServices({
    required this.session,
    required this.api,
    required this.auth,
    required this.doctors,
    required this.patient,
    required this.messages,
    required this.profile,
  });

  /// The wiring as it runs on a device.
  factory AppServices.live({String? baseUrl, SessionStore? store}) {
    final session = SessionController(store: store);
    final api = ApiClient(
      baseUrl: baseUrl ?? ApiConfig.baseUrl,
      session: session,
    );
    return AppServices(
      session: session,
      api: api,
      auth: HttpAuthService(api: api, session: session),
      doctors: HttpDoctorRepository(api),
      patient: HttpPatientRepository(api),
      messages: HttpMessagesRepository(api),
      profile: HttpProfileRepository(api),
    );
  }

  final SessionController session;
  final ApiClient api;
  final AuthService auth;
  final DoctorRepository doctors;
  final PatientRepository patient;
  final MessagesRepository messages;
  final ProfileRepository profile;
}

/// Puts [AppServices] in the tree.
///
/// An [InheritedNotifier] on the session, so a widget that reads the scope is
/// rebuilt when the patient signs in or out — the greeting picks up a name
/// change without anyone wiring a callback for it.
class AppScope extends InheritedNotifier<SessionController> {
  AppScope({super.key, required this.services, required super.child})
      : super(notifier: services.session);

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(
      scope != null,
      'No AppScope in the tree. A screen that reaches for a service without '
      'being given one needs an AppScope above it — MedicoApp installs one, '
      'and a test can wrap the widget under test in another.',
    );
    return scope!.services;
  }

  /// For a widget that can work without services — used by the screens that
  /// take an optional one in their constructor.
  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      super.updateShouldNotify(oldWidget) || services != oldWidget.services;
}
