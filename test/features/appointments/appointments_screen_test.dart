import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/appointments/data/appointment.dart';
import 'package:medico/features/appointments/presentation/appointments_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

Widget _app(FakePatientRepository patient, {VoidCallback? onFindDoctor}) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: AppointmentsScreen(
            patient: patient,
            now: kNow,
            onFindDoctor: onFindDoctor,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 1600);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('it opens on what is coming, not on everything', (tester) async {
    final patient = FakePatientRepository(appointments: kSampleAppointments);
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    expect(patient.lastFilter, AppointmentFilter.upcoming);
    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
    expect(find.text('Dr. Priya Raman'), findsOneWidget);
    // The one from last week and the cancelled one are on other tabs.
    expect(find.text('Dr. William James'), findsNothing);
    expect(find.text('Dr. Hugo Lindqvist'), findsNothing);
  });

  testWidgets('an appointment says who, when and where it stands',
      (tester) async {
    await tester.pumpWidget(
      _app(FakePatientRepository(appointments: kSampleAppointments)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cardiologist'), findsOneWidget);
    expect(find.text('09:00 – 09:30'), findsOneWidget);
    expect(find.text('Scheduled'), findsNWidgets(2));
    expect(find.text('23'), findsOneWidget);
    expect(find.text('Sep'), findsNWidgets(2));
  });

  testWidgets('the filter is the server\'s question, not a local sort',
      (tester) async {
    final patient = FakePatientRepository(appointments: kSampleAppointments);
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(patient.lastFilter, AppointmentFilter.past);
    expect(find.text('Dr. William James'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(patient.lastFilter, AppointmentFilter.cancelled);
    expect(find.text('Dr. Hugo Lindqvist'), findsOneWidget);
    expect(find.text('Cancelled'), findsNWidgets(2)); // the chip and the badge
  });

  testWidgets('only an appointment still ahead can be called off',
      (tester) async {
    final patient = FakePatientRepository(appointments: kSampleAppointments);
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    expect(find.text('Cancel appointment'), findsNWidgets(2));

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel appointment'), findsNothing,
        reason: 'an appointment that has happened is not a button');
  });

  testWidgets('cancelling asks first, and "Keep it" keeps it', (tester) async {
    final patient = FakePatientRepository(appointments: kSampleAppointments);
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel appointment').first);
    await tester.pumpAndSettle();

    expect(find.text('Cancel this appointment?'), findsOneWidget);
    // Never "Cancel" and "OK" on a dialog about cancelling.
    expect(find.text('Keep it'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(patient.cancelled, isEmpty);
    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
  });

  testWidgets('confirming cancels it at the server and the list follows',
      (tester) async {
    final patient = FakePatientRepository(appointments: kSampleAppointments);
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel appointment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel appointment'));
    await tester.pumpAndSettle();

    expect(patient.cancelled, ['a1']);
    expect(find.text('Dr. Thomas Moore'), findsNothing,
        reason: 'it is no longer upcoming');
    expect(find.textContaining('Appointment cancelled'), findsOneWidget);
  });

  testWidgets('nothing booked offers the one thing that would fix it',
      (tester) async {
    var asked = false;
    await tester.pumpWidget(
      _app(FakePatientRepository(appointments: const []),
          onFindDoctor: () => asked = true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing booked yet'), findsOneWidget);
    await tester.tap(find.text('Find a doctor'));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
  });

  testWidgets('a list that will not load says so, and the retry works',
      (tester) async {
    await tester.pumpWidget(
      _app(FakePatientRepository(failure: ApiException.offline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load your appointments'), findsOneWidget);
    expect(
      find.text("We couldn't reach Medico. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}
