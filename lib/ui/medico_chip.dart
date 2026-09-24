import 'package:flutter/material.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// A filter, as a pill.
///
/// The selected chip is the only saturated thing in its row, so the active
/// filter is never in doubt — and tapping it again clears it, which is how a
/// patient gets back to the full list without hunting for a reset.
class MedicoChip extends StatelessWidget {
  const MedicoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// A trailing count: "Cancelled 2".
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = selected ? c.brand.onSolid : c.inkBody;

    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: context.motion(Motion.fast),
        curve: Motion.easeOut,
        constraints: const BoxConstraints(minHeight: Layout.minTapTarget - 8),
        decoration: BoxDecoration(
          color: selected ? c.brand.solid : c.surface,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: selected ? c.brand.solid : c.control),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: IconSize.sm, color: foreground),
                    const SizedBox(width: Insets.xxs + 2),
                  ],
                  Text(
                    label,
                    style: context.text.labelMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: Insets.xxs + 2),
                    Text(
                      '$count',
                      style: context.text.labelSmall?.copyWith(
                        color: selected
                            ? c.brand.onSolid.withValues(alpha: 0.8)
                            : c.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of chips with the page gutter already applied, so a chip
/// at either end lines up with the headings above it.
class MedicoChipBar extends StatelessWidget {
  const MedicoChipBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: Insets.gutter),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Insets.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The circular affordance used for search, alerts and favouriting.
/// One shape, one size, reused everywhere.
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 46,
    this.iconColor,
    this.background,
    this.badge = false,
    this.selected = false,
  });

  final IconData icon;

  /// Icon-only, so this is both the tooltip and the screen-reader name.
  final String label;

  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;
  final Color? background;

  /// An unread dot. Never the only indication of something unread.
  final bool badge;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        toggled: selected,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: Layout.minTapTarget,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: background ?? c.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    child: SizedBox.square(
                      dimension: size,
                      child: Icon(
                        icon,
                        size: 21,
                        color: iconColor ?? c.ink,
                      ),
                    ),
                  ),
                ),
                if (badge)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.brand.solid,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.canvas, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rating, as a pill that keeps its own surface so it reads the same on the
/// brand-filled card and on a white one.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Insets.xs, 6, Insets.sm, 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The one place the accent appears as a graphic rather than a
            // surface: a star that is not gold does not read as a rating.
            Icon(Icons.star_rounded, size: 18, color: c.accent.solid),
            const SizedBox(width: Insets.xxs + 2),
            Text(
              rating.toStringAsFixed(1),
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
