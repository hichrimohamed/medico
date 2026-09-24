import 'package:flutter/material.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

enum MedicoBannerTone { error, success, warning, info }

/// Inline feedback, placed where the patient is already looking — in the flow
/// of the thing it is about.
///
/// Never a snackbar for anything that must be acted on: a snackbar can be
/// missed, and it takes the text away while the patient is still reading it.
/// Never a dialog for a form error: a dialog has to be dismissed before the
/// problem it describes can be fixed.
///
/// Tone always carries an icon as well as a colour, so the signal survives
/// colour blindness, greyscale and a bad screen in bad light.
class MedicoBanner extends StatelessWidget {
  const MedicoBanner({
    super.key,
    required this.message,
    this.tone = MedicoBannerTone.error,
    this.title,
    this.action,
    this.onAction,
  });

  final String message;
  final MedicoBannerTone tone;

  /// Optional — most banners are one sentence and do not need one.
  final String? title;

  /// PRODUCT.md: never a dead end. If the patient can do something about this,
  /// name it here.
  final String? action;
  final VoidCallback? onAction;

  MedicoTone _tone(BuildContext context) => switch (tone) {
        MedicoBannerTone.error => context.colors.danger,
        MedicoBannerTone.success => context.colors.success,
        MedicoBannerTone.warning => context.colors.warning,
        MedicoBannerTone.info => context.colors.info,
      };

  IconData get _icon => switch (tone) {
        MedicoBannerTone.error => Icons.error_outline_rounded,
        MedicoBannerTone.success => Icons.check_circle_outline_rounded,
        MedicoBannerTone.warning => Icons.warning_amber_rounded,
        MedicoBannerTone.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = _tone(context);
    final text = context.text;

    return Semantics(
      // Announced the moment it appears. Without this a patient using
      // TalkBack taps "Sign in", hears nothing, and taps again.
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Insets.sm + 2,
          Insets.sm,
          Insets.sm + 2,
          Insets.sm,
        ),
        decoration: BoxDecoration(
          color: t.container,
          borderRadius: Radii.mdAll,
          border: Border.all(color: t.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(_icon, size: IconSize.md, color: t.ink),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: text.titleSmall?.copyWith(color: t.ink),
                    ),
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(color: t.ink, height: 1.42),
                  ),
                  if (action != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.xxs),
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: t.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.xs,
                            vertical: Insets.xxs,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(action!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reserves no space until there is something to say, then opens into it.
///
/// The form below does not jump on first paint, and the patient's cursor does
/// not move out from under them when an error arrives.
class MedicoBannerSlot extends StatelessWidget {
  const MedicoBannerSlot({super.key, this.child, this.gap = Insets.lg});

  final Widget? child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: context.motion(Motion.base),
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: context.motion(Motion.base),
        switchInCurve: Motion.easeOut,
        child: child == null
            ? const SizedBox(width: double.infinity)
            : Padding(padding: EdgeInsets.only(bottom: gap), child: child),
      ),
    );
  }
}
