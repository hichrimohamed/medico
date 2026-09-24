import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medico/app/app.dart';
import 'package:medico/app/app_scope.dart';
import 'package:medico/core/api/api_client.dart';
import 'package:medico/core/auth/session_controller.dart';
import 'package:medico/core/auth/session_store.dart';
import 'package:medico/features/auth/data/http_auth_service.dart';
import 'package:medico/features/doctors/data/doctor_repository.dart';
import 'package:medico/features/doctors/data/patient_repository.dart';
import 'package:medico/features/messages/data/messages_repository.dart';
import 'package:medico/features/profile/data/profile_repository.dart';

import '../../support/fakes.dart';

/// Everything 401s, which is what a device holding a token the server has
/// forgotten actually meets.
AppServices _revokedServices() {
  final session = SessionController(store: InMemorySessionStore());
  session.begin(kDemoSession, remember: true);

  final api = ApiClient(
    baseUrl: 'https://api.test/v1',
    session: session,
    httpClient: MockClient((request) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'},
          })),
          401,
        )),
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

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 1600);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('and the same when the app was opened on a deep link',
      (tester) async {
    // `--route=/messages`, a notification tap, a universal link.
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/messages';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    final services = _revokedServices();
    await tester.pumpWidget(MedicoApp(services: services));
    await tester.pumpAndSettle();

    expect(services.session.isSignedIn, isFalse);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a session the server has forgotten returns to sign-in',
      (tester) async {
    final services = _revokedServices();
    await tester.pumpWidget(MedicoApp(services: services));
    await tester.pumpAndSettle();

    expect(services.session.isSignedIn, isFalse,
        reason: 'a dead refresh chain must not be left on the device');
    expect(find.text('Welcome back'), findsOneWidget,
        reason: 'and the patient has to end up somewhere they can act');
  });
}
