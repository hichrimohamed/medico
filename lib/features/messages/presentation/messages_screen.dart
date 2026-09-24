import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../data/message.dart';
import '../data/messages_repository.dart';
import 'widgets/new_message_sheet.dart';

/// Conversations with the practice.
///
/// Deliberately *with the practice* and not with a named doctor. A thread
/// addressed to a consultant implies that consultant is reading it, and a
/// clinic cannot promise that — which is the same reason the screen says, out
/// loud and above the keyboard, that this is not the way to reach anyone in an
/// emergency.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.messages,
    this.bottomInset = 0,
  });

  final MessagesRepository? messages;

  /// Room for the floating tab bar this screen sits under.
  final double bottomInset;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  MessagesRepository get _messages =>
      widget.messages ?? AppScope.of(context).messages;

  List<MessageThread> _threads = const [];
  int _unreadThreads = 0;
  bool _unreadOnly = false;

  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load({bool? unreadOnly}) async {
    final filter = unreadOnly ?? _unreadOnly;
    setState(() {
      _unreadOnly = filter;
      _loading = true;
      _error = null;
    });

    try {
      final result = await _messages.threads(unreadOnly: filter);
      if (!mounted) return;
      setState(() {
        _threads = result.threads;
        _unreadThreads = result.unreadThreads;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      context.announce(error.message, urgent: true);
    }
  }

  /// Opening a thread reads it, so the list is re-read on the way back: the
  /// unread dot has to be gone when the patient returns to it.
  Future<void> _open(MessageThread thread) async {
    await Navigator.of(context).pushNamed(AppRoutes.thread, arguments: thread);
    if (mounted) await _load();
  }

  Future<void> _startNew() async {
    final started = await showNewMessageSheet(
      context: context,
      messages: _messages,
    );
    if (started == null || !mounted) return;

    await _load();
    if (mounted) await _open(started);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(onCompose: _startNew)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.lg),
              child: MedicoChipBar(
                children: [
                  MedicoChip(
                    label: 'All',
                    selected: !_unreadOnly,
                    onTap: () {
                      if (!_unreadOnly) return;
                      _load(unreadOnly: false);
                    },
                  ),
                  MedicoChip(
                    label: 'Unread',
                    selected: _unreadOnly,
                    count: _unreadThreads == 0 ? null : _unreadThreads,
                    onTap: () {
                      if (_unreadOnly) return;
                      _load(unreadOnly: true);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: MedicoEmptyState.failure(
                    title: 'We could not load your messages',
                    message: _error!,
                    onAction: _load,
                  ),
                ),
              ),
            )
          else if (_loading)
            const SliverToBoxAdapter(child: _ListSkeleton())
          else if (_threads.isEmpty)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: _unreadOnly
                      ? MedicoEmptyState(
                          compact: true,
                          icon: Icons.mark_email_read_outlined,
                          title: 'Nothing waiting',
                          message: 'You have read everything the clinic has '
                              'sent you.',
                          actionLabel: 'Show all conversations',
                          onAction: () => _load(unreadOnly: false),
                        )
                      : MedicoEmptyState(
                          compact: true,
                          icon: Icons.forum_outlined,
                          title: 'No messages yet',
                          message: 'Ask the clinic about an appointment, a '
                              'result or a prescription. Replies come back '
                              'here.',
                          actionLabel: 'Start a conversation',
                          onAction: _startNew,
                        ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: _threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final thread = _threads[index];
                return _Padded(
                  child: ThreadRow(
                    thread: thread,
                    onTap: () => _open(thread),
                  ),
                );
              },
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Insets.gutter,
                Insets.xl,
                Insets.gutter,
                widget.bottomInset,
              ),
              child: const UrgentCareNote(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line that has to be on this screen.
///
/// Messaging a clinic invites exactly the message it must not be used for, and
/// the answer cannot be buried in a help page. It is quiet, it is always
/// visible, and it carries the number.
class UrgentCareNote extends StatelessWidget {
  const UrgentCareNote({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: IconSize.sm,
            color: c.inkMuted,
          ),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              compact
                  ? 'Not for urgent help. Call 999 in an emergency.'
                  : 'Messages are answered within two working days. This is '
                      'not the way to get urgent help — call the clinic on '
                      '0800 555 100, or 999 in an emergency.',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: child,
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.md,
        Insets.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Messages', style: context.text.headlineSmall),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your conversations with the clinic.',
                  style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          CircleAction(
            icon: Icons.edit_outlined,
            label: 'Start a conversation',
            onPressed: onCompose,
          ),
        ],
      ),
    );
  }
}

/// One conversation in the list.
class ThreadRow extends StatelessWidget {
  const ThreadRow({super.key, required this.thread, required this.onTap});

  final MessageThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = thread.hasUnread;

    return MedicoCard(
      onTap: onTap,
      semanticLabel: [
        thread.subject,
        if (thread.aboutDoctor != null) 'about ${thread.aboutDoctor!.name}',
        if (unread)
          '${thread.unreadCount} unread'
        else if (thread.lastMessageFrom == MessageAuthor.patient)
          'you replied',
        thread.lastMessagePreview,
        thread.whenLabel,
      ].join('. '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: thread.aboutDoctor == null
                ? const _ClinicMark()
                : MedicoAvatar(
                    name: thread.aboutDoctor!.name,
                    initials: thread.aboutDoctor!.initials,
                    size: 46,
                  ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        thread.subject,
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          thread.whenLabel,
                          style: context.text.bodySmall?.copyWith(
                            color: unread ? c.brand.ink : c.inkMuted,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(height: Insets.xxs),
                          _UnreadBadge(count: thread.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
                if (thread.aboutDoctor != null)
                  Text(
                    'About ${thread.aboutDoctor!.name}',
                    style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: Insets.xxs),
                Text(
                  // "You: …" so a patient can tell at a glance whether the
                  // ball is in their court.
                  thread.lastMessageFrom == MessageAuthor.patient
                      ? 'You: ${thread.lastMessagePreview}'
                      : thread.lastMessagePreview,
                  style: context.text.bodyMedium?.copyWith(
                    color: unread ? c.ink : c.inkMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The practice, as a shape. A thread that is not about one doctor is not
/// about a person at all, and a silhouette would be a lie about that.
class _ClinicMark extends StatelessWidget {
  const _ClinicMark();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: c.brand.container,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.local_hospital_outlined,
        size: IconSize.md,
        color: c.brand.ink,
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xxs + 1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.brand.solid,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(color: c.brand.onSolid),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return MedicoLoadingRegion(
      label: 'Loading your messages',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              MedicoSkeleton(
                width: double.infinity,
                height: 104,
                radius: Radii.xlAll,
              ),
              const SizedBox(height: Insets.sm),
            ],
          ],
        ),
      ),
    );
  }
}
