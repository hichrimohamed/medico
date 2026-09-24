import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/messages/data/message.dart';
import 'package:medico/features/messages/presentation/thread_screen.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

FakeMessagesRepository _loaded() => FakeMessagesRepository(
      threads: kSampleThreads,
      messages: kSampleMessages,
    );

Widget _app(FakeMessagesRepository messages, {MessageThread? thread}) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: ThreadScreen(
        thread: thread ?? kSampleThreads.first,
        messages: messages,
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

  testWidgets('it shows the conversation, both sides of it', (tester) async {
    await tester.pumpWidget(_app(_loaded()));
    await tester.pumpAndSettle();

    expect(find.text('Blood pressure review'), findsOneWidget);
    expect(find.textContaining('140 over 90'), findsOneWidget);
    expect(find.textContaining('keep going with the same dose'), findsOneWidget);
    // What it is about, not who is answering.
    expect(find.text('About your care with Dr. Thomas Moore'), findsOneWidget);
  });

  testWidgets('opening it marks it read', (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    expect(messages.readThreads, ['t1']);
  });

  testWidgets('a thread with nothing waiting is not marked again',
      (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages, thread: kSampleThreads.last));
    await tester.pumpAndSettle();

    expect(messages.readThreads, isEmpty);
  });

  testWidgets('sending adds the message and clears the box', (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'That is clear, thank you.');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();

    expect(messages.sent.single.threadId, 't1');
    expect(messages.sent.single.body, 'That is clear, thank you.');
    expect(find.text('That is clear, thank you.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a message that will not send keeps what was typed',
      (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    messages.writeFailure = ApiException.offline;

    await tester.enterText(find.byType(TextField), 'Please could you check?');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();

    // Principle 3: every failure keeps what the patient already typed.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Please could you check?',
    );
    expect(
      find.text("We couldn't reach Medico. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('an empty message is not sent', (tester) async {
    final messages = _loaded();
    await tester.pumpWidget(_app(messages));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();

    expect(messages.sent, isEmpty);
  });

  testWidgets('the urgent-care line sits above the keyboard', (tester) async {
    await tester.pumpWidget(_app(_loaded()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not for urgent help'), findsOneWidget);
  });

  testWidgets('a closed conversation is readable, not writable',
      (tester) async {
    final closed = MessageThread(
      id: 't9',
      subject: 'Old business',
      lastMessageAt: kNow,
      lastMessagePreview: 'Thanks.',
      isClosed: true,
    );
    final messages = FakeMessagesRepository(
      threads: [closed],
      messages: {
        't9': [
          Message(
            id: 'm9',
            from: MessageAuthor.clinic,
            body: 'Anything else, start a new conversation.',
            sentAt: kNow,
          ),
        ],
      },
    );

    await tester.pumpWidget(_app(messages, thread: closed));
    await tester.pumpAndSettle();

    expect(find.textContaining('Anything else'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('has been closed'), findsOneWidget);
  });

  testWidgets('a conversation that will not open says so', (tester) async {
    await tester.pumpWidget(
      _app(FakeMessagesRepository(failure: ApiException.offline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not open this conversation'), findsOneWidget);
    expect(find.byType(TextField), findsNothing,
        reason: 'nothing to reply to yet');
  });
}
