import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/messages/presentation/messages_screen.dart';
import 'package:medico/features/messages/presentation/thread_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

FakeMessagesRepository _loaded() => FakeMessagesRepository(
      threads: kSampleThreads,
      messages: kSampleMessages,
    );

Widget _app(FakeMessagesRepository messages) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SafeArea(child: MessagesScreen(messages: messages))),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ThreadScreen(
              thread: kSampleThreads.first,
              messages: messages,
            ),
          ),
        ),
        settings: settings,
      ),
    ),
    services: fakeServices(messages: messages),
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

  testWidgets('it lists the conversations the server sent', (tester) async {
    await tester.pumpWidget(_app(_loaded()));
    await tester.pumpAndSettle();

    expect(find.text('Blood pressure review'), findsOneWidget);
    expect(find.text('Repeat prescription'), findsOneWidget);
    // What a thread is *about*, not who replies to it.
    expect(find.text('About Dr. Thomas Moore'), findsOneWidget);
  });

  testWidgets('a conversation waiting is marked, and counted once',
      (tester) async {
    await tester.pumpWidget(_app(_loaded()));
    await tester.pumpAndSettle();

    // One badge on the row and one count on the chip. Two messages in one
    // thread would still be one thing to go and look at, which is why the
    // chip counts threads rather than messages.
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('the unread filter is the server\'s question', (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(messages.lastUnreadOnly, isTrue);
    expect(find.text('Blood pressure review'), findsOneWidget);
    expect(find.text('Repeat prescription'), findsNothing);
  });

  testWidgets('it says what this is not for, without being asked',
      (tester) async {
    await tester.pumpWidget(_app(_loaded()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not the way to get urgent help'),
      findsOneWidget,
    );
    expect(find.textContaining('999'), findsOneWidget);
  });

  testWidgets('opening a conversation reads it, and the list follows',
      (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blood pressure review'));
    await tester.pumpAndSettle();

    expect(messages.readThreads, ['t1']);
    expect(find.textContaining('140 over 90'), findsOneWidget);
  });

  testWidgets('no messages at all says what the screen is for', (tester) async {
    await tester.pumpWidget(_app(FakeMessagesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
  });

  testWidgets('nothing unread is a different fact from nothing at all',
      (tester) async {
    final messages = FakeMessagesRepository(
      threads: [kSampleThreads.last], // the one already read
    );
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing waiting'), findsOneWidget);
    await tester.tap(find.text('Show all conversations'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat prescription'), findsOneWidget);
  });

  testWidgets('a list that will not load says so, and offers a retry',
      (tester) async {
    await tester.pumpWidget(
      _app(FakeMessagesRepository(failure: ApiException.offline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load your messages'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('starting a conversation asks for a subject and a message',
      (tester) async {
    final messages = FakeMessagesRepository();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start a conversation'));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);

    // Sending nothing says what is missing rather than failing silently.
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(
      find.text('Give it a short subject, so you can find it again.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).first, 'Test results');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Are my blood results back yet?',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsNothing);
  });
}
