import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/doctors/presentation/saved_doctors_screen.dart';

import '../support/fakes.dart';
import 'render_harness.dart';

/// The screen lives inside the home Scaffold, which supplies the canvas the
/// cards sit on. Rendering it bare would put white cards on a white page.
Widget _screen(Widget child) => Scaffold(body: SafeArea(child: child));

void main() {
  testWidgets('saved — a few kept doctors', (tester) async {
    await render(
      tester,
      child: _screen(SavedDoctorsScreen(
        patient: FakePatientRepository(favourites: {'d2', 'd3', 'd5'}),
      )),
      device: Device.phone,
      name: 'saved_phone',
    );
  });

  testWidgets('saved — nothing kept', (tester) async {
    await render(
      tester,
      child: _screen(SavedDoctorsScreen(
        patient: FakePatientRepository(favourites: {}),
        onFindDoctor: () {},
      )),
      device: Device.phone,
      name: 'saved_phone_empty',
    );
  });

  testWidgets('saved — could not load', (tester) async {
    await render(
      tester,
      child: _screen(SavedDoctorsScreen(
        patient: FakePatientRepository(failure: ApiException.offline),
      )),
      device: Device.phone,
      name: 'saved_phone_error',
    );
  });

  testWidgets('saved — 200% text scale', (tester) async {
    await render(
      tester,
      child: _screen(SavedDoctorsScreen(
        patient: FakePatientRepository(favourites: {'d2', 'd3'}),
      )),
      device: Device.phone,
      name: 'saved_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('saved — phone, dark', (tester) async {
    await render(
      tester,
      child: _screen(SavedDoctorsScreen(
        patient: FakePatientRepository(favourites: {'d2', 'd3', 'd5'}),
      )),
      device: Device.phone,
      name: 'saved_phone_dark',
      brightness: Brightness.dark,
    );
  });
}
