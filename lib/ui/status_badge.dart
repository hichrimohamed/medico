import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// The states a patient's appointment or record can be in.
///
/// This enum is the reason the accent colour is barred from status work: a
/// patient reading a badge is reading the state of their own care, and that
/// vocabulary has to be closed and unambiguous. If something new needs a
/// badge, it gets a case here — it does not get a one-off colour at the call
/// site.
enum MedicoStatus {
  /// Booked, not yet confirmed by the practice.
  scheduled,

  /// Confirmed by the practice. The patient does not need to do anything.
  confirmed,

  /// Happening now — a consultation in progress, a video call live.
  inProgress,

  /// Done. Past tense, no charge either way.
  completed,

  cancelled,

  /// Waiting on the practice: a referral under review, a result not back.
  pending,

  /// Waiting on the *patient*: a form to sign, a payment, a question to answer.
  /// The only status that implies homework, so it is the only warm one.
  actionNeeded,

  /// Clinically urgent. Rare on purpose — if everything is urgent, nothing is.
  urgent,
}

extension MedicoStatusPresentation on MedicoStatus {
  String get label => switch (this) {
        MedicoStatus.scheduled => 'Scheduled',
        MedicoStatus.confirmed => 'Confirmed',
        MedicoStatus.inProgress => 'In progress',
        MedicoStatus.completed => 'Completed',
        MedicoStatus.cancelled => 'Cancelled',
        MedicoStatus.pending => 'Pending',
        MedicoStatus.actionNeeded => 'Action needed',
        MedicoStatus.urgent => 'Urgent',
      };

  IconData get icon => switch (this) {
        MedicoStatus.scheduled => Icons.event_outlined,
        MedicoStatus.confirmed => Icons.check_circle_outline_rounded,
        MedicoStatus.inProgress => Icons.play_circle_outline_rounded,
        MedicoStatus.completed => Icons.done_all_rounded,
        MedicoStatus.cancelled => Icons.cancel_outlined,
        MedicoStatus.pending => Icons.schedule_rounded,
        MedicoStatus.actionNeeded => Icons.error_outline_rounded,
        MedicoStatus.urgent => Icons.priority_high_rounded,
      };

  MedicoTone tone(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      MedicoStatus.scheduled => c.info,
      MedicoStatus.confirmed => c.success,
      MedicoStatus.inProgress => c.info,
      MedicoStatus.completed => c.neutral,
      MedicoStatus.cancelled => c.neutral,
      MedicoStatus.pending => c.neutral,
      MedicoStatus.actionNeeded => c.warning,
      MedicoStatus.urgent => c.danger,
    };
  }
}

enum StatusEmphasis {
  /// The default: a tinted pill. Quiet enough to sit in a list of twenty.
  subtle,

  /// A solid fill. For one badge on a screen, never for a list.
  solid,
}

/// A small pill naming a state.
///
/// Always icon + text. Colour is a third signal here, never the only one —
/// "cancelled" and "confirmed" must be distinguishable in greyscale, because
/// for a patient the difference is whether they turn up tomorrow.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.emphasis = StatusEmphasis.subtle,
  });

  final MedicoStatus status;

  /// Overrides the default wording — "Cancelled by the practice" rather than
  /// "Cancelled". The tone and icon stay with the status.
  final String? label;

  final StatusEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final tone = status.tone(context);
    final solid = emphasis == StatusEmphasis.solid;
    final foreground = solid ? tone.onSolid : tone.ink;
    final text = label ?? status.label;

    return Semantics(
      label: 'Status: $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xs + 2,
          vertical: Insets.xxs + 1,
        ),
        decoration: BoxDecoration(
          color: solid ? tone.solid : tone.container,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: solid ? null : Border.all(color: tone.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: IconSize.sm, color: foreground),
            const SizedBox(width: Insets.xxs + 1),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
