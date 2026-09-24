import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/profile/presentation/profile_screen.dart';

import '../support/fakes.dart';
import 'render_harness.dart';

/// The screen lives inside the home Scaffold, which supplies the canvas.
Widget _screen(Widget child) => Scaffold(body: SafeArea(child: child));

void main() {
  testWidgets('profile — phone', (tester) async {
    await render(
      tester,
      child: _screen(ProfileScreen(profile: FakeProfileRepository())),
      device: Device.phone,
      name: 'profile_phone',
    );
  });

  testWidgets('profile — could not load', (tester) async {
    await render(
      tester,
      child: _screen(ProfileScreen(
        profile: FakeProfileRepository(failure: ApiException.offline),
      )),
      device: Device.phone,
      name: 'profile_phone_error',
    );
  });

  testWidgets('profile — 200% text scale', (tester) async {
    await render(
      tester,
      child: _screen(ProfileScreen(profile: FakeProfileRepository())),
      device: Device.phone,
      name: 'profile_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('profile — phone, dark', (tester) async {
    await render(
      tester,
      child: _screen(ProfileScreen(profile: FakeProfileRepository())),
      device: Device.phone,
      name: 'profile_phone_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('profile — deleting the account', (tester) async {
    await render(
      tester,
      child: _screen(ProfileScreen(profile: FakeProfileRepository())),
      device: Device.phone,
      name: 'profile_phone_delete',
      after: (tester) async {
        await tester.dragUntilVisible(
          find.text('Delete account'),
          find.byType(CustomScrollView),
          const Offset(0, -120),
        );
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();
      },
    );
  });
}
