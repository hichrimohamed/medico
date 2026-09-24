import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/app/app.dart';
import 'package:medico/features/doctors/data/doctor.dart';
import 'package:medico/features/doctors/presentation/doctor_detail_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

final Doctor _doctor =
    kSampleDoctors.firstWhere((doctor) => doctor.id == 'd2');

final _doctors = FakeDoctorRepository();
final _patient = FakePatientRepository();

Widget _app() => MaterialApp(
      theme: AppTheme.light,
      home: DoctorDetailScreen(
        doctor: _doctor,
        doctors: _doctors,
        patient: _patient,
      ),
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

  testWidgets('Next sends the patient to availability before it can confirm',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // It switched tabs rather than confirming a booking that has no time.
    expect(find.text('Pick a time'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('choosing a slot turns the action into a concrete confirmation',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirm'), findsOneWidget);
    expect(find.textContaining('09:30'), findsWidgets);
  });

  testWidgets('a booked slot cannot be selected', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirm'), findsNothing,
        reason: 'a taken slot must not become a bookable selection');
  });

  testWidgets('changing the day clears a slot picked for the previous one',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirm'), findsOneWidget);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}').last);
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget,
        reason: 'the old time is not valid for the new day');
  });

  testWidgets('the bio expands and collapses', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('tapping a doctor on home opens their page', (tester) async {
    // A remembered session opens the app on the directory, not on the form.
    await tester.pumpWidget(MedicoApp(services: fakeServices()));
    await tester.pumpAndSettle();

    expect(find.text('Hello Ada 👋'), findsOneWidget);

    await tester.tap(find.text('Dr. William James'));
    await tester.pumpAndSettle();

    expect(find.text('Availability'), findsWidgets);
    expect(find.text('Neurologist'), findsWidgets);
  });

  testWidgets('with no session the app opens on sign-in', (tester) async {
    await tester.pumpWidget(
      MedicoApp(services: fakeServices(signedInAs: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
