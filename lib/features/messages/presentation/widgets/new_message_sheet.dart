import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../ui/ui.dart';
import '../../data/message.dart';
import '../../data/messages_repository.dart';
import '../messages_screen.dart' show UrgentCareNote;

/// Starting a conversation.
///
/// A subject and a first message, which is the whole of what the server needs.
/// It asks for a subject rather than deriving one from the first line, because
/// the subject is what the patient will scan for in a list three weeks later —
/// "Blood pressure review" beats "Hi, I wanted to ask about".
Future<MessageThread?> showNewMessageSheet({
  required BuildContext context,
  required MessagesRepository messages,
}) {
  return showMedicoSheet<MessageThread>(
    context: context,
    title: 'New message',
    // Leaving by accident would lose what they typed.
    dismissible: false,
    builder: (context) => _NewMessageForm(messages: messages),
  );
}

class _NewMessageForm extends StatefulWidget {
  const _NewMessageForm({required this.messages});

  final MessagesRepository messages;

  @override
  State<_NewMessageForm> createState() => _NewMessageFormState();
}

class _NewMessageFormState extends State<_NewMessageForm> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _sending = false;
  String? _failure;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _sending = true;
      _failure = null;
    });

    try {
      final thread = await widget.messages.start(
        subject: _subject.text,
        body: _body.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(thread);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicoBannerSlot(
              child: _failure == null
                  ? null
                  : MedicoBanner(
                      key: ValueKey<String>(_failure!),
                      message: _failure!,
                    ),
            ),
            MedicoTextField(
              label: 'Subject',
              hint: 'Blood pressure review',
              controller: _subject,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Give it a short subject, so you can find it again.'
                  : null,
            ),
            const SizedBox(height: Insets.md),
            MedicoTextField(
              label: 'Message',
              hint: 'What would you like to ask the clinic?',
              controller: _body,
              enabled: !_sending,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Write your message.' : null,
            ),
            const SizedBox(height: Insets.md),
            const UrgentCareNote(),
            const SizedBox(height: Insets.lg),
            MedicoButton(
              label: 'Send',
              busyLabel: 'Sending',
              busy: _sending,
              onPressed: _sending ? null : _send,
            ),
            const SizedBox(height: Insets.xs),
            MedicoButton.quiet(
              label: 'Cancel',
              onPressed:
                  _sending ? null : () => Navigator.of(context).pop(),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
