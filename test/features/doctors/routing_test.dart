import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/app/app_scope.dart';
import 'package:medico/app/routes.dart';
import 'package:medico/features/auth/presentation/login_screen.dart';
import 'package:medico/features/doctors/presentation/doctor_detail_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

Widget _appAt(String route, {Object? arguments, AppServices? services}) =>
    withFakeServices(
      MaterialApp(
        theme: AppTheme.light,
        initialRoute: route,
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          arguments == null
              ? settings
              : RouteSettings(name: settings.name, arguments: arguments),
        ),
        onUnknownRoute: AppRoutes.onUnknownRoute,
      ),
      services: services,
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 1600);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('a deep link carrying an id opens that doctor', (tester) async {
    await tester.pumpWidget(_appAt('/doctor?id=d2'));
    await tester.pumpAndSettle();

    final screen = tester.widget<DoctorDetailScreen>(
      find.byType(DoctorDetailScreen),
    );
    // The link carries an id and nothing else, so the screen is opened on the
    // id and fetches the doctor itself.
    expect(screen.doctorId, 'd2');
    expect(find.text('Dr. Thomas Moore'), findsWidgets);
  });

  testWidgets('an id passed as an argument resolves too', (tester) async {
    await tester.pumpWidget(_appAt('/doctor', arguments: 'd3'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DoctorDetailScreen>(find.byType(DoctorDetailScreen))
          .doctorId,
      'd3',
    );
    expect(find.text('Dr. Amina Farouk'), findsWidgets);
  });

  testWidgets('a pushed Doctor is used directly', (tester) async {
    final doctor = kSampleDoctors.last;
    await tester.pumpWidget(_appAt('/doctor', arguments: doctor));
    await tester.pumpAndSettle();

    expect(
      tester.widget<DoctorDetailScreen>(find.byType(DoctorDetailScreen)).doctor?.id,
      doctor.id,
    );
  });

  testWidgets('a link with no id at all falls back to the front door',
      (tester) async {
    await tester.pumpWidget(_appAt('/doctor'));
    await tester.pumpAndSettle();

    // Flutter reports the unresolvable initial route and then falls back to
    // '/' by itself. Draining it keeps the expected notice from failing the
    // test — the behaviour under test is where the app ends up.
    final reported = tester.takeException();
    expect(
      reported.toString(),
      contains('Could not navigate to initial route'),
    );

    expect(find.byType(DoctorDetailScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a link to a doctor who is gone says so, and offers a retry',
      (tester) async {
    // The directory lives on the server now, so a stale id cannot be rejected
    // before the screen opens — the screen opens, asks, and reports the answer.
    await tester.pumpWidget(_appAt('/doctor?id=no-longer-here'));
    await tester.pumpAndSettle();

    expect(find.text('We could not open that doctor'), findsOneWidget);
    expect(find.text('We could not find that doctor.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
