
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/auth/presentation/forgot_password_screen.dart';
import 'package:medico/features/auth/presentation/login_screen.dart';
import 'package:medico/features/auth/presentation/sign_up_screen.dart';

import 'render_harness.dart';

void main() {
  testWidgets('login — phone', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phone,
      name: 'login_phone',
    );
  });

  testWidgets('login — small phone', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phoneSmall,
      name: 'login_phone_small',
    );
  });

  testWidgets('login — tablet split', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.tablet,
      name: 'login_tablet',
    );
  });

  testWidgets('login — phone landscape', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phoneLandscape,
      name: 'login_phone_landscape',
    );
  });

  testWidgets('login — 200% text scale', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phone,
      name: 'login_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('login — rejected credentials', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phone,
      name: 'login_phone_error',
      after: (tester) async {
        await tester.enterText(
          find.byType(TextFormField).first,
          'locked@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        // Scroll the banner into frame the way the screen does for the patient.
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -240));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('sign up — phone', (tester) async {
    await render(
      tester,
      child: const SignUpScreen(),
      device: Device.phone,
      name: 'sign_up_phone',
    );
  });

  testWidgets('forgot password — phone', (tester) async {
    await render(
      tester,
      child: const ForgotPasswordScreen(initialEmail: 'ada@example.com'),
      device: Device.phone,
      name: 'forgot_password_phone',
    );
  });

  // ------------------------------------------------------------------- dark
  testWidgets('login — phone, dark', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phone,
      name: 'login_phone_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('login — tablet split, dark', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.tablet,
      name: 'login_tablet_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('login — rejected credentials, dark', (tester) async {
    await render(
      tester,
      child: const LoginScreen(),
      device: Device.phone,
      name: 'login_phone_error_dark',
      brightness: Brightness.dark,
      after: (tester) async {
        await tester.enterText(
          find.byType(TextFormField).first,
          'locked@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -240));
        await tester.pumpAndSettle();
      },
    );
  });

  // The artwork panel is the one surface with a light ground baked into a
  // JPEG, so it is the surface most likely to look wrong in dark mode.
  testWidgets('forgot password — phone, dark', (tester) async {
    await render(
      tester,
      child: const ForgotPasswordScreen(initialEmail: 'ada@example.com'),
      device: Device.phone,
      name: 'forgot_password_phone_dark',
      brightness: Brightness.dark,
    );
  });
}
