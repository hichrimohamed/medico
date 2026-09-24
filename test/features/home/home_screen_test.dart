import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/app/app.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/doctors/data/availability.dart';
import 'package:medico/features/doctors/data/doctor.dart';
import 'package:medico/features/doctors/data/doctor_repository.dart';
import 'package:medico/features/home/presentation/home_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

/// Fails until it is told to stop, so the retry can be seen to work.
class _FlakyDirectory implements DoctorRepository {
  bool broken = true;
  int listCalls = 0;

  @override
  Future<List<Doctor>> list({String? specialtyField, String? query}) async {
    listCalls++;
    if (broken) throw ApiException.offline;
    return kSampleDoctors;
  }

  @override
  Future<List<String>> specialtyFields() async {
    if (broken) throw ApiException.offline;
    return kSampleSpecialtyFields;
  }

  @override
  Future<Doctor> byId(String id) async => kSampleDoctors.first;

  @override
  Future<List<AvailabilityDay>> availability(
    String doctorId, {
    DateTime? from,
    int days = 7,
  }) async =>
      const [];
}

Widget _app({DoctorRepository? doctors, FakePatientRepository? patient}) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: HomeScreen(
        doctors: doctors ?? FakeDoctorRepository(),
        patient: patient ?? FakePatientRepository(),
        patientName: 'Ada',
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
    view.physicalSize = const Size(420, 1800);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('the directory is what the server sent', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Dr. William James'), findsOneWidget);
    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
    // The rail is built from the fields the server reports.
    expect(find.text('Neurology'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
  });

  testWidgets('the slot count on the lead card comes from availability',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('8 slots'), findsOneWidget);
  });

  testWidgets('filtering asks the server for the field, not the practitioner',
      (tester) async {
    final directory = FakeDoctorRepository();
    await tester.pumpWidget(_app(doctors: directory));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cardiology'));
    await tester.pumpAndSettle();

    expect(directory.lastSpecialtyField, 'Cardiology');
    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
    expect(find.text('Dr. William James'), findsNothing);
  });

  testWidgets('a specialty nobody practises is an empty state, not an error',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Eye care'),
      find.byType(ListView).first,
      const Offset(-120, 0),
    );
    await tester.tap(find.text('Eye care'));
    await tester.pumpAndSettle();

    expect(find.text('No ophthalmologists free this week'), findsOneWidget);
    expect(find.text('Show all doctors'), findsOneWidget);
  });

  testWidgets('a directory that will not load says so, and the retry works',
      (tester) async {
    final directory = _FlakyDirectory();
    await tester.pumpWidget(_app(doctors: directory));
    await tester.pumpAndSettle();

    expect(find.text('We could not load the directory'), findsOneWidget);
    expect(
      find.text("We couldn't reach Medico. Check your connection and try again."),
      findsOneWidget,
    );

    directory.broken = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('We could not load the directory'), findsNothing);
    expect(find.text('Dr. William James'), findsOneWidget);
  });

  testWidgets('the heart saves to the server, and puts itself back if that '
      'fails', (tester) async {
    final patient = FakePatientRepository(favourites: {});
    await tester.pumpWidget(_app(patient: patient));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Save this doctor').first);
    await tester.pumpAndSettle();

    expect(patient.favouriteIds, contains('d1'));
  });

  testWidgets('signing out ends the session and returns to the form',
      (tester) async {
    final services = fakeServices();
    await tester.pumpWidget(MedicoApp(services: services));
    await tester.pumpAndSettle();

    expect(services.session.isSignedIn, isTrue);

    await tester.tap(find.bySemanticsLabel('Sign out'));
    await tester.pumpAndSettle();

    // It asks first — one tap from the patient's own name is one tap from an
    // accidental sign-out.
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(services.session.isSignedIn, isTrue);

    await tester.tap(find.bySemanticsLabel('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(services.session.isSignedIn, isFalse);
    expect(find.text('Welcome back'), findsOneWidget,
        reason: 'the app follows the session back to sign-in');
  });
}
