import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/messages/presentation/messages_screen.dart';
import 'package:medico/features/messages/presentation/thread_screen.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';
import 'render_harness.dart';

/// The list sits inside the home Scaffold, which supplies the canvas.
Widget _screen(Widget child) => Scaffold(body: SafeArea(child: child));

FakeMessagesRepository _repository() => FakeMessagesRepository(
      threads: kSampleThreads,
      messages: kSampleMessages,
    );

void main() {
  testWidgets('messages — conversations', (tester) async {
    await render(
      tester,
      child: _screen(MessagesScreen(messages: _repository())),
      device: Device.phone,
      name: 'messages_phone',
    );
  });

  testWidgets('messages — nothing yet', (tester) async {
    await render(
      tester,
      child: _screen(MessagesScreen(messages: FakeMessagesRepository())),
      device: Device.phone,
      name: 'messages_phone_empty',
    );
  });

  testWidgets('messages — could not load', (tester) async {
    await render(
      tester,
      child: _screen(
        MessagesScreen(
          messages: FakeMessagesRepository(failure: ApiException.offline),
        ),
      ),
      device: Device.phone,
      name: 'messages_phone_error',
    );
  });

  testWidgets('messages — 200% text scale', (tester) async {
    await render(
      tester,
      child: _screen(MessagesScreen(messages: _repository())),
      device: Device.phone,
      name: 'messages_phone_text200',
      textScale: 2,
    );
  });

  testWidgets('messages — phone, dark', (tester) async {
    await render(
      tester,
      child: _screen(MessagesScreen(messages: _repository())),
      device: Device.phone,
      name: 'messages_phone_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('thread — a conversation', (tester) async {
    await render(
      tester,
      child: ThreadScreen(
        thread: kSampleThreads.first,
        messages: _repository(),
      ),
      device: Device.phone,
      name: 'thread_phone',
    );
  });

  testWidgets('thread — phone, dark', (tester) async {
    await render(
      tester,
      child: ThreadScreen(
        thread: kSampleThreads.first,
        messages: _repository(),
      ),
      device: Device.phone,
      name: 'thread_phone_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('thread — 200% text scale', (tester) async {
    await render(
      tester,
      child: ThreadScreen(
        thread: kSampleThreads.first,
        messages: _repository(),
      ),
      device: Device.phone,
      name: 'thread_phone_text200',
      textScale: 2,
    );
  });
}
