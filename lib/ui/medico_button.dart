import 'package:flutter/material.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// What a button *means*, not what it looks like.
enum MedicoButtonVariant {
  /// The one thing this screen is for. At most one per screen.
  primary,

  /// A real alternative to the primary action: "Reschedule" next to "Cancel
  /// appointment", "Continue with Google" next to "Sign in".
  secondary,

  /// A link that happens to be a button. No fill, no border.
  quiet,

  /// Destroys something the patient cannot get back. Never the default focus,
  /// never the only way out of a flow.
  danger,
}

enum MedicoButtonSize {
  /// Full-width, 52pt. The action the patient came to press.
  large,

  /// The everyday size. Still clears the 48pt target.
  medium,

  /// For a toolbar or a card corner. Padded to 48pt even though it draws at
  /// 40 — a small button is not a small target.
  small,
}

/// The app's button.
///
/// Three behaviours are built in rather than left to each call site, because
/// each one was a bug the first time it was left out:
///
/// * **Busy keeps its size and its colour.** The label is swapped for progress
///   in place, so nothing under the patient's thumb moves and the tap is
///   visibly acknowledged.
/// * **Busy is announced.** A screen-reader user hears "Sign in, in progress",
///   not silence.
/// * **The label never truncates silently** at large text sizes — it wraps to
///   a second line and the button grows.
class MedicoButton extends StatelessWidget {
  const MedicoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MedicoButtonVariant.primary,
    this.size = MedicoButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
  });

  const MedicoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = MedicoButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
  }) : variant = MedicoButtonVariant.secondary;

  const MedicoButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = MedicoButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.busyLabel,
    this.expand = false,
  }) : variant = MedicoButtonVariant.quiet;

  const MedicoButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = MedicoButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
  }) : variant = MedicoButtonVariant.danger;

  final String label;

  /// Null disables the button. A disabled primary action should always be
  /// accompanied by something on screen saying what is missing.
  final VoidCallback? onPressed;

  final MedicoButtonVariant variant;
  final MedicoButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Work is in flight. The button is inert but keeps its appearance.
  final bool busy;

  /// What to say while busy — "Signing in…" rather than "Sign in".
  final String? busyLabel;

  final bool expand;

  double get _height => switch (size) {
        MedicoButtonSize.large => Layout.primaryButtonHeight,
        MedicoButtonSize.medium => Layout.minTapTarget,
        MedicoButtonSize.small => 40,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = !busy && onPressed != null;

    final tone = switch (variant) {
      MedicoButtonVariant.danger => c.danger,
      _ => c.brand,
    };

    final style = switch (variant) {
      MedicoButtonVariant.primary || MedicoButtonVariant.danger =>
        _filledStyle(c, tone),
      MedicoButtonVariant.secondary => _outlinedStyle(c),
      MedicoButtonVariant.quiet => _quietStyle(c, tone),
    };

    final child = _Label(
      label: label,
      icon: icon,
      trailingIcon: trailingIcon,
      busy: busy,
      busyLabel: busyLabel,
      spinnerColor: switch (variant) {
        MedicoButtonVariant.primary ||
        MedicoButtonVariant.danger =>
          tone.onSolid,
        MedicoButtonVariant.secondary => c.inkBody,
        MedicoButtonVariant.quiet => tone.ink,
      },
    );

    final button = switch (variant) {
      MedicoButtonVariant.primary || MedicoButtonVariant.danger => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: child,
        ),
      MedicoButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: child,
        ),
      MedicoButtonVariant.quiet => TextButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? '${busyLabel ?? label}, in progress' : label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }

  ButtonStyle _filledStyle(MedicoColors c, MedicoTone tone) {
    return FilledButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, _height),
      backgroundColor: tone.solid,
      foregroundColor: tone.onSolid,
      // While busy the button is disabled to block a second tap, but it must
      // not *look* disabled — the patient needs to see that their tap landed.
      disabledBackgroundColor: busy
          ? tone.solid
          : (c.isDark ? tone.container : tone.border),
      disabledForegroundColor:
          busy ? tone.onSolid : (c.isDark ? c.inkDisabled : tone.ink),
      padding: _padding,
      shape: kButtonShape,
      elevation: 0,
    );
  }

  ButtonStyle _outlinedStyle(MedicoColors c) {
    return OutlinedButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, _height),
      foregroundColor: c.inkBody,
      backgroundColor: c.surface,
      disabledForegroundColor: c.inkDisabled,
      side: BorderSide(color: c.control),
      padding: _padding,
      shape: kButtonShape,
    );
  }

  ButtonStyle _quietStyle(MedicoColors c, MedicoTone tone) {
    return TextButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, _height),
      foregroundColor: tone.ink,
      disabledForegroundColor: c.inkDisabled,
      padding: _padding,
      shape: kButtonShape,
    );
  }

  EdgeInsets get _padding => EdgeInsets.symmetric(
        horizontal: switch (size) {
          MedicoButtonSize.large => Insets.xl,
          MedicoButtonSize.medium => Insets.lg,
          MedicoButtonSize.small => Insets.sm,
        },
      );
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.icon,
    required this.trailingIcon,
    required this.busy,
    required this.busyLabel,
    required this.spinnerColor,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool busy;
  final String? busyLabel;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(Motion.base),
      switchInCurve: Motion.easeOut,
      child: busy
          ? Row(
              key: const ValueKey<bool>(true),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: spinnerColor,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Flexible(child: Text(busyLabel ?? label)),
              ],
            )
          : Row(
              key: const ValueKey<bool>(false),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: IconSize.md),
                  const SizedBox(width: Insets.xs),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                if (trailingIcon != null) ...[
                  const SizedBox(width: Insets.xs),
                  Icon(trailingIcon, size: IconSize.md),
                ],
              ],
            ),
    );
  }
}

/// A round icon-only control: a favourite toggle, a close, an overflow.
///
/// Icon-only means the label lives entirely in [tooltip], which doubles as the
/// screen-reader name — so it is required, not optional.
class MedicoIconButton extends StatelessWidget {
  const MedicoIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foreground,
    this.background,
    this.size = IconSize.lg,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? foreground;
  final Color? background;
  final double size;

  /// Reported to assistive technology as a toggle state.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      toggled: selected,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: size,
        style: IconButton.styleFrom(
          foregroundColor: foreground ?? c.inkMuted,
          backgroundColor: background,
          minimumSize: const Size.square(Layout.minTapTarget),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
