import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../../doctors/data/doctor.dart';
import '../data/message.dart';
import '../data/messages_repository.dart';
import 'messages_screen.dart' show UrgentCareNote;

/// One conversation, read and replied to.
///
/// Reached with the [MessageThread] already in hand from the list, or with a
/// [threadId] alone from a link or a notification.
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    this.thread,
    this.threadId,
    this.messages,
  }) : assert(
          thread != null || threadId != null,
          'A thread, or an id to fetch one with.',
        );

  final MessageThread? thread;
  final String? threadId;
  final MessagesRepository? messages;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  MessagesRepository get _repository =>
      widget.messages ?? AppScope.of(context).messages;

  final _composer = TextEditingController();
  final _scroll = ScrollController();

  MessageThread? _thread;
  List<Message> _messages = const [];

  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _started = false;

  MessageThread? get thread => _thread ?? widget.thread;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final id = thread?.id ?? widget.threadId!;
    try {
      final conversation = await _repository.conversation(id);
      if (!mounted) return;
      setState(() {
        _thread = conversation.thread;
        _messages = conversation.messages;
        _loading = false;
      });
      _scrollToEnd();

      // Opening a conversation is reading it. Done after the messages are on
      // screen, and its failure is not the patient's problem — the worst case
      // is a dot that comes back.
      if (conversation.thread.hasUnread) {
        try {
          await _repository.markRead(id);
        } on ApiException {
          // Left unread; it will be marked on the next open.
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      context.announce(error.message, urgent: true);
    }
  }

  void _scrollToEnd() {
    // After layout, or there is nothing to scroll yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    final id = thread?.id;
    if (body.isEmpty || id == null || _sending) return;

    setState(() => _sending = true);
    try {
      final sent = await _repository.send(id, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _sending = false;
        _composer.clear();
      });
      _scrollToEnd();
      context.announce('Message sent.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      // The text stays in the box. Principle 3: a failure keeps what the
      // patient already typed.
      showMedicoSnack(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = thread;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: MedicoAppBar(
        title: current?.subject ?? 'Conversation',
      ),
      body: Column(
        children: [
          if (current?.aboutDoctor != null)
            _AboutStrip(doctor: current!.aboutDoctor!),
          Expanded(child: _body(current)),
          if (current != null && !current.isClosed && _error == null)
            _Composer(
              controller: _composer,
              sending: _sending,
              onSend: _send,
            )
          else if (current?.isClosed ?? false)
            const _ClosedNote(),
        ],
      ),
    );
  }

  Widget _body(MessageThread? current) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: MedicoCard(
            child: MedicoEmptyState.failure(
              title: 'We could not open this conversation',
              message: _error!,
              onAction: _load,
            ),
          ),
        ),
      );
    }

    if (_loading && _messages.isEmpty) {
      return const Center(
        child: MedicoLoadingRegion(
          label: 'Loading the conversation',
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (current == null) return const SizedBox.shrink();

    // Date separators, and one timestamp per run rather than one per bubble:
    // four messages sent in the same minute do not need the minute printed
    // four times.
    final items = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (lastDay == null || message.day != lastDay) {
        items.add(_DaySeparator(day: message.day));
        lastDay = message.day;
      }

      final next = i + 1 < _messages.length ? _messages[i + 1] : null;
      final endsRun = next == null ||
          next.from != message.from ||
          next.day != message.day ||
          next.timeLabel != message.timeLabel;

      items.add(_Bubble(message: message, showTime: endsRun));
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md,
      ),
      children: items,
    );
  }
}

/// What the conversation is about, when it is about an appointment. Not who is
/// answering it.
class _AboutStrip extends StatelessWidget {
  const _AboutStrip({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.xs,
        Insets.gutter,
        Insets.xs,
      ),
      color: c.surface,
      child: Row(
        children: [
          MedicoAvatar(
            name: doctor.name,
            initials: doctor.initials,
            size: 28,
          ),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              'About your care with ${doctor.name}',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';

    final month = kMonthNames[day.month - 1].substring(0, 3);
    final weekday = kWeekdayNames[day.weekday - 1];
    if (day.year == now.year) return '$weekday ${day.day} $month';
    return '$weekday ${day.day} $month ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Center(
        child: Text(
          _label,
          style: context.text.bodySmall?.copyWith(color: context.colors.inkMuted),
        ),
      ),
    );
  }
}

/// One message.
///
/// The patient's own messages are brand-filled and sit right; the clinic's are
/// on the surface colour and sit left. Colour is not the only signal — the
/// side and the alignment carry it too, which is what keeps the thread legible
/// in greyscale.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.showTime = true});

  final Message message;

  /// False for a bubble in the middle of a run from the same side.
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mine = message.fromPatient;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Semantics(
              container: true,
              label: '${mine ? 'You' : 'The clinic'} at ${message.timeLabel}. '
                  '${message.body}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm + 2,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  color: mine ? c.brand.solid : c.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(Radii.lg),
                    topRight: const Radius.circular(Radii.lg),
                    bottomLeft: Radius.circular(mine ? Radii.lg : Radii.sm),
                    bottomRight: Radius.circular(mine ? Radii.sm : Radii.lg),
                  ),
                ),
                child: Text(
                  message.body,
                  style: context.text.bodyLarge?.copyWith(
                    color: mine ? c.brand.onSolid : c.ink,
                  ),
                ),
              ),
            ),
          ),
          if (showTime) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xxs),
              child: Text(
                message.timeLabel,
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      color: c.surface,
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        children: [
          const UrgentCareNote(compact: true),
          const SizedBox(height: Insets.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: context.text.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Write a message',
                    filled: true,
                    fillColor: c.canvas,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.xl),
                      borderSide: BorderSide(color: c.control),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.xl),
                      borderSide: BorderSide(color: c.control),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.xs),
              _SendButton(sending: sending, onPressed: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      container: true,
      button: true,
      label: 'Send message',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: Layout.minTapTarget,
        child: Material(
          color: c.brand.solid,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: sending ? null : onPressed,
            child: Center(
              child: sending
                  ? SizedBox.square(
                      dimension: IconSize.md,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(c.brand.onSolid),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: IconSize.md,
                      color: c.brand.onSolid,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Text(
        'This conversation has been closed. Start a new one and the clinic '
        'will pick it up.',
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
      ),
    );
  }
}
