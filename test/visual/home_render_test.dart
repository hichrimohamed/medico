import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/home/presentation/home_screen.dart';

import '../support/fakes.dart';
import 'render_harness.dart';

void main() {
  testWidgets('home — phone', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phone,
      name: 'home_phone',
    );
  });

  testWidgets('home — small phone', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phoneSmall,
      name: 'home_phone_small',
    );
  });

  testWidgets('home — 200% text scale', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phone,
      name: 'home_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('home — filtered to an empty specialty', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phone,
      name: 'home_phone_empty',
      after: (tester) async {
        // The empty specialty sits off the end of the horizontal rail.
        await tester.dragUntilVisible(
          find.text('Eye care'),
          find.byType(ListView),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eye care'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('home — phone, dark', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phone,
      name: 'home_phone_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('home — filtered to an empty specialty, dark', (tester) async {
    await render(
      tester,
      child: HomeScreen(
        doctors: FakeDoctorRepository(),
        patient: FakePatientRepository(),
        patientName: 'Ada',
      ),
      device: Device.phone,
      name: 'home_phone_empty_dark',
      brightness: Brightness.dark,
      after: (tester) async {
        await tester.dragUntilVisible(
          find.text('Eye care'),
          find.byType(ListView),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eye care'));
        await tester.pumpAndSettle();
      },
    );
  });
}
