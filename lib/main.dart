import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app runs edge to edge: the artwork reaches the status bar and the form
  // owns the space above the home indicator. The *colour* of the system bars
  // is not set here — it belongs to the theme, so it follows the patient into
  // dark mode. See `AppTheme.systemOverlay`.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // The session is read from disk before the first frame. It is a local read
  // of a few hundred bytes, and doing it here is what stops a patient who is
  // already signed in seeing the sign-in screen flash past on every launch.
  // Nothing on the network is waited for — see `_validateSession`.
  final services = AppServices.live();
  await services.session.restore();

  runApp(MedicoApp(services: services));
}
