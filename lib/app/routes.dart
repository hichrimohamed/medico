import 'package:flutter/material.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/doctors/data/doctor.dart';
import '../features/doctors/presentation/doctor_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/messages/data/message.dart';
import '../features/messages/presentation/thread_screen.dart';

abstract final class AppRoutes {
  const AppRoutes._();

  static const String login = '/';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';

  /// The appointments tab, addressable on its own so a reminder — "your
  /// appointment with Dr Moore is tomorrow" — can open the list it is about
  /// rather than the front page.
  static const String appointments = '/appointments';

  /// The saved doctors tab, addressable for the same reason.
  static const String saved = '/saved';

  static const String messages = '/messages';

  static const String profile = '/profile';

  /// One conversation. Takes a [MessageThread] or a thread id, so a "the
  /// clinic has replied" notification can open the thread it is about.
  static const String thread = '/thread';
  static const String doctor = '/doctor';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Parsed as a URI so a link can carry parameters — `/doctor?id=d2` has to
    // work when it arrives from a notification, not just from a push() that
    // already holds the object.
    final uri = Uri.parse(settings.name ?? login);

    return switch (uri.path) {
      login => _page(const LoginScreen(), settings),
      signUp => _page(const SignUpScreen(), settings),
      forgotPassword => _page(
          ForgotPasswordScreen(initialEmail: settings.arguments as String?),
          settings,
        ),
      home => _page(const HomeScreen(), settings),
      appointments => _page(const HomeScreen(initialTab: 1), settings),
      saved => _page(const HomeScreen(initialTab: 2), settings),
      messages => _page(const HomeScreen(initialTab: 3), settings),
      profile => _page(const HomeScreen(initialTab: 4), settings),
      thread => _threadRoute(settings, uri),
      doctor => _doctorRoute(settings, uri),
      _ => null,
    };
  }

  /// Resolves the doctor from a pushed object, an id argument, or `?id=`.
  ///
  /// A card on the home screen already holds the doctor and passes it whole,
  /// which is why tapping one opens instantly. A link from a notification has
  /// nothing but an id, and the screen fetches it — the directory is on the
  /// server now, so the route cannot resolve it here without blocking the
  /// transition on a request.
  ///
  /// Returns null only when there is no id at all, so a malformed link lands
  /// on the front door instead of a screen with nothing to show.
  static Route<dynamic>? _doctorRoute(RouteSettings settings, Uri uri) {
    final argument = settings.arguments;
    if (argument is Doctor) {
      return _page(DoctorDetailScreen(doctor: argument), settings);
    }

    final id = argument is String ? argument : uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    return _page(DoctorDetailScreen(doctorId: id), settings);
  }

  /// Resolves a conversation from a pushed thread or an id, the same way a
  /// doctor is resolved.
  static Route<dynamic>? _threadRoute(RouteSettings settings, Uri uri) {
    final argument = settings.arguments;
    if (argument is MessageThread) {
      return _page(ThreadScreen(thread: argument), settings);
    }

    final id = argument is String ? argument : uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    return _page(ThreadScreen(threadId: id), settings);
  }

  /// A link to something that no longer exists lands on the front door rather
  /// than a black screen.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) =>
      _page(const LoginScreen(), const RouteSettings(name: login));

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
