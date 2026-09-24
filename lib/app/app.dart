import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../theme/app_theme.dart';
import 'app_scope.dart';
import 'routes.dart';

class MedicoApp extends StatefulWidget {
  const MedicoApp({super.key, this.services});

  /// Supplied by tests. Null means the real wiring against the real API.
  final AppServices? services;

  @override
  State<MedicoApp> createState() => _MedicoAppState();
}

class _MedicoAppState extends State<MedicoApp> {
  late final AppServices _services = widget.services ?? AppServices.live();
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// Whether the patient was signed in at the last notification, so that the
  /// listener can tell "signed out just now" from "was never signed in".
  ///
  /// Set in [initState], not with a `late` initialiser: a lazy field is
  /// evaluated on first read, which would be inside the listener, *after* the
  /// session had already emptied. It would always read false and the app would
  /// never follow a sign-out anywhere.
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = _services.session.isSignedIn;
    _services.session.addListener(_onSessionChanged);
    // `main` awaits this before the first frame so the app opens on the right
    // screen; repeating it here is what makes the widget work on its own, and
    // a second call is a no-op.
    _services.session.restore().then((_) => _validateSession());
  }

  @override
  void dispose() {
    _services.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// A remembered session is not trusted on sight: its access token is fifteen
  /// minutes old at best, and the refresh token behind it may have been
  /// revoked from another device since. One call to `/auth/me` settles it —
  /// [ApiClient] rotates underneath if the access token has merely expired,
  /// and a 401 here means the whole chain is dead.
  ///
  /// Deliberately not awaited before the first frame. Starting the app is not
  /// worth a round trip on a bad network, and if this does end the session the
  /// listener below moves the patient to sign-in.
  Future<void> _validateSession() async {
    if (!mounted || !_services.session.isSignedIn) return;
    try {
      await _services.api.get('/auth/me');
    } on ApiException catch (error) {
      // Offline is not a revoked session. Being locked out of the app on a
      // train is a worse answer than a directory that says it could not load.
      if (error.code == ApiErrorCode.network) return;
      await _services.session.end();
    }
  }

  /// The session can end from anywhere — the sign-out button, or a refresh the
  /// server refused three screens deep. Wherever it happens, the patient ends
  /// up back at sign-in with nothing behind them to go back to.
  void _onSessionChanged() {
    final signedIn = _services.session.isSignedIn;
    final wasSignedIn = _wasSignedIn;
    _wasSignedIn = signedIn;

    if (wasSignedIn && !signedIn) {
      _navigator.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
    }
  }

  /// Where the app opens: the platform's route when it gave one, the home
  /// screen for a signed-in patient, the form otherwise.
  String get _initialRoute {
    if (!_services.session.isSignedIn) return AppRoutes.login;

    // `flutter run --route=…`, a notification tap, or a universal link. The
    // platform sends '/' when there is none, and '/' is the sign-in screen,
    // which is not where a signed-in patient belongs.
    final deepLink = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (deepLink.isNotEmpty && deepLink != AppRoutes.login) return deepLink;

    return AppRoutes.home;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: MaterialApp(
        title: 'Medico',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigator,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // The patient already told their phone which they want. Asking again
        // in a settings screen would be a second answer to a question they
        // have answered — and one more thing to get out of sync.
        themeMode: ThemeMode.system,
        // A patient who is already signed in should never see the sign-in
        // form flash past. `main` restores the stored session before the first
        // frame, so by the time this is read the answer is known.
        //
        // A deep link wins over the default — that is the whole point of one —
        // but only once there is a session to open it with. Somebody following
        // a reminder to their appointments while signed out has to sign in
        // first, and lands on the form rather than on a screen that would have
        // nothing to show.
        initialRoute: _initialRoute,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        onUnknownRoute: AppRoutes.onUnknownRoute,
      ),
    );
  }
}
