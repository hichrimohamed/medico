import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/appointments/presentation/appointments_screen.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';
import 'render_harness.dart';

/// The screen lives inside the home Scaffold, which supplies the canvas the
/// cards sit on. Rendering it bare would put white cards on a white page.
Widget _screen(Widget child) => Scaffold(body: SafeArea(child: child));

void main() {
  testWidgets('appointments — upcoming', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(appointments: kSampleAppointments),
        now: kNow,
      )),
      device: Device.phone,
      name: 'appointments_phone',
    );
  });

  testWidgets('appointments — past and cancelled', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(appointments: kSampleAppointments),
        now: kNow,
      )),
      device: Device.phone,
      name: 'appointments_phone_past',
      after: (tester) async {
        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('appointments — nothing booked', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(appointments: const []),
        now: kNow,
        onFindDoctor: () {},
      )),
      device: Device.phone,
      name: 'appointments_phone_empty',
    );
  });

  testWidgets('appointments — could not load', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(failure: ApiException.offline),
        now: kNow,
      )),
      device: Device.phone,
      name: 'appointments_phone_error',
    );
  });

  testWidgets('appointments — 200% text scale', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(appointments: kSampleAppointments),
        now: kNow,
      )),
      device: Device.phone,
      name: 'appointments_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('appointments — phone, dark', (tester) async {
    await render(
      tester,
      child: _screen(AppointmentsScreen(
        patient: FakePatientRepository(appointments: kSampleAppointments),
        now: kNow,
      )),
      device: Device.phone,
      name: 'appointments_phone_dark',
      brightness: Brightness.dark,
    );
  });
}
