import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/auth/data/auth_service.dart';
import 'package:medico/features/auth/presentation/login_screen.dart';
import 'package:medico/theme/app_theme.dart';

/// Controllable stand-in so each failure path can be exercised without
/// depending on the demo service's email conventions.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.failure});

  final AuthException? failure;
  int signInCalls = 0;
  int signOutCalls = 0;
  String? lastEmail;
  String? lastPassword;
  bool? lastRemember;

  @override
  Future<void> signIn({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    lastRemember = remember;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithProvider(SsoProvider provider) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => signOutCalls++;
}

Widget _app(AuthService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: LoginScreen(authService: service),
    routes: {
      '/home': (_) => const Scaffold(body: Text('HOME')),
      '/forgot-password': (_) => const Scaffold(body: Text('RESET')),
    },
  );
}

void main() {
  // The default 800x600 test surface puts the submit button below the fold.
  // A tall phone-shaped viewport keeps the whole form reachable.
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

  testWidgets('an empty form names both missing fields rather than failing '
      'silently', (tester) async {
    final service = _FakeAuthService();
    await tester.pumpWidget(_app(service));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the email address you use for Medico.'),
        findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(service.signInCalls, 0, reason: 'must not hit the network');
  });

  testWidgets('a malformed address is caught before the request', (tester) async {
    final service = _FakeAuthService();
    await tester.pumpWidget(_app(service));

    await tester.enterText(find.byType(TextFormField).first, 'ada@example');
    await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('That does not look like an email address. Check for a typo.'),
      findsOneWidget,
    );
    expect(service.signInCalls, 0);
  });

  testWidgets('sign-in trims the address and reaches the service',
      (tester) async {
    final service = _FakeAuthService();
    await tester.pumpWidget(_app(service));

    await tester.enterText(find.byType(TextFormField).first, '  ada@example.com ');
    await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(service.lastEmail, 'ada@example.com');
    expect(service.lastPassword, 'hunter2hunter2');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a rejected sign-in explains itself and keeps what was typed',
      (tester) async {
    final service = _FakeAuthService(
      failure: const AuthException(
        AuthFailure.invalidCredentials,
        "That email and password don't match.",
      ),
    );
    await tester.pumpWidget(_app(service));

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("That email and password don't match."), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    // Nothing is more hostile than clearing the form on failure.
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('a locked account offers the way out, not just the bad news',
      (tester) async {
    final service = _FakeAuthService(
      failure: const AuthException(
        AuthFailure.accountLocked,
        'This account is locked.',
      ),
    );
    await tester.pumpWidget(_app(service));

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('RESET'), findsOneWidget);
  });

  testWidgets('the password stays hidden until asked for', (tester) async {
    await tester.pumpWidget(_app(_FakeAuthService()));

    EditableText passwordField() => tester.widget<EditableText>(
          find.byType(EditableText).last,
        );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('the form locks while the request is in flight', (tester) async {
    final completer = _BlockingAuthService();
    await tester.pumpWidget(_app(completer));

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'hunter2hunter2');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Signing in'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'a second tap must not fire a second request',
    );

    completer.release();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}

class _BlockingAuthService extends _FakeAuthService {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> signIn({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    signInCalls++;
    await _gate.future;
  }
}
