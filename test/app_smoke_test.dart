import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/app/app.dart';

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 1400);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('the app boots into sign-in and can reach every auth screen',
      (tester) async {
    await tester.pumpWidget(const MedicoApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
