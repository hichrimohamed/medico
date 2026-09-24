import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/app/app.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/profile/data/profile.dart';
import 'package:medico/features/profile/presentation/profile_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';

Widget _app(FakeProfileRepository profile) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(child: ProfileScreen(profile: profile)),
      ),
    ),
    services: fakeServices(profile: profile),
  );
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 2000);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('it shows who the clinic has on file', (tester) async {
    await tester.pumpWidget(_app(FakeProfileRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('ada@example.com'), findsWidgets);
    expect(find.text('With Medico since March 2026'), findsOneWidget);
  });

  testWidgets('the counts come from the server, not from list lengths',
      (tester) async {
    await tester.pumpWidget(_app(FakeProfileRepository()));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
  });

  testWidgets('renaming sends the new name and shows it', (tester) async {
    final profile = FakeProfileRepository();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Ada King');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(profile.renamedTo, ['Ada King']);
    expect(find.text('Ada King'), findsWidgets);
  });

  testWidgets('email is shown but not editable', (tester) async {
    await tester.pumpWidget(_app(FakeProfileRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    // No sheet opened: changing it means proving the new address is theirs.
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('changing the password needs the current one', (tester) async {
    final profile = FakeProfileRepository();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'old-password-1');
    await tester.enterText(find.byType(TextFormField).last, 'a-longer-new-one');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(profile.passwordChanges.single.current, 'old-password-1');
    expect(profile.passwordChanges.single.next, 'a-longer-new-one');
  });

  testWidgets('it says a password change ends other sessions', (tester) async {
    await tester.pumpWidget(_app(FakeProfileRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('signs you out everywhere else'),
      findsOneWidget,
    );
  });

  group('deleting the account', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.dragUntilVisible(
        find.text('Delete account'),
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
    }

    testWidgets('it spells out what goes, before asking', (tester) async {
      await tester.pumpWidget(_app(FakeProfileRepository()));
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('Delete your account'), findsOneWidget);
      // Twice on purpose: once on the card that offers it, once in the sheet
      // that asks. This is the warning you want repeated.
      expect(find.textContaining('cannot be undone'), findsNWidgets(2));
      expect(
        find.textContaining('Deleting ada@example.com removes'),
        findsOneWidget,
      );
      expect(
        find.textContaining('your 2 upcoming appointments'),
        findsOneWidget,
        reason: 'the real number, not a generic warning',
      );
      expect(find.textContaining('go back to the clinic'), findsOneWidget);
      // The gentler thing to do is offered alongside.
      expect(find.textContaining('sign out instead'), findsOneWidget);
    });

    testWidgets('it lists only what the patient actually has', (tester) async {
      final empty = FakeProfileRepository(
        profile: const Profile(
          id: 'u2',
          name: 'New Patient',
          email: 'new@example.com',
          memberSince: null,
        ),
      );
      await tester.pumpWidget(_app(empty));
      await tester.pumpAndSettle();
      await openSheet(tester);

      // Telling someone with no appointments that their appointments will go
      // is noise on the screen where skimming costs most.
      expect(find.textContaining('upcoming appointment'), findsNothing);
      expect(find.textContaining('saved doctors'), findsNothing);
      expect(find.textContaining('your messages with the clinic'), findsOneWidget);
    });

    testWidgets('it will not delete without the password', (tester) async {
      final profile = FakeProfileRepository();
      await tester.pumpWidget(_app(profile));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();

      expect(profile.deleteAttempts, isEmpty);
      expect(profile.deleted, isFalse);
      expect(find.text('Delete your account'), findsOneWidget,
          reason: 'the sheet stays open with the error');
    });

    testWidgets('"Keep my account" keeps it', (tester) async {
      final profile = FakeProfileRepository();
      await tester.pumpWidget(_app(profile));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();

      expect(profile.deleted, isFalse);
      expect(find.text('Delete your account'), findsNothing);
    });

    testWidgets('a wrong password is refused and the account survives',
        (tester) async {
      final profile = FakeProfileRepository();
      profile.writeFailure = const ApiException(
        ApiErrorCode.invalidCredentials,
        'That password is not right.',
      );
      await tester.pumpWidget(_app(profile));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();

      expect(profile.deleteAttempts, ['wrong-password']);
      expect(profile.deleted, isFalse);
      expect(find.text('That password is not right.'), findsOneWidget);
    });

    testWidgets('confirming deletes it and ends the session', (tester) async {
      final profile = FakeProfileRepository();
      final services = fakeServices(profile: profile);

      await tester.pumpWidget(MedicoApp(services: services));
      await tester.pumpAndSettle();
      expect(services.session.isSignedIn, isTrue);

      // Into the profile tab through the real bottom bar.
      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.enterText(find.byType(TextFormField), 'medico1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();

      expect(profile.deleted, isTrue);
      expect(services.session.isSignedIn, isFalse,
          reason: 'there is no account left to be signed in to');
      expect(find.text('Welcome back'), findsOneWidget,
          reason: 'and the app follows the session back to sign-in');
    });
  });

  testWidgets('a profile that will not load says so, and offers a retry',
      (tester) async {
    await tester.pumpWidget(
      _app(FakeProfileRepository(failure: ApiException.offline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load your profile'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // Nothing destructive is reachable when we do not know whose account it is.
    expect(find.text('Delete account'), findsNothing);
  });
}
