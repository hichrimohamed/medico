import 'dart:io' show Platform;

/// Where the API lives.
///
/// Overridable at build time so a TestFlight build does not need a code
/// change:
///
/// ```
/// flutter run --dart-define=MEDICO_API_BASE_URL=https://api.medico.example/api/v1
/// ```
///
/// The default is the local server, and it differs by platform for one
/// annoying reason: the Android emulator is a virtual machine, so `localhost`
/// there is the emulator itself, not the developer's laptop. `10.0.2.2` is the
/// address it gives the host. The iOS simulator shares the host's network and
/// needs no such trick.
abstract final class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('MEDICO_API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (Platform.isAndroid) return 'http://10.0.2.2:4000/api/v1';
    return 'http://localhost:4000/api/v1';
  }
}
