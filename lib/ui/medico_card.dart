import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

enum MedicoCardVariant {
  /// A white card on the canvas. The default for anything in a list.
  plain,

  /// Outlined instead of filled. For a card on a surface that is already
  /// white, where a fill would be invisible.
  outlined,

  /// Brand-filled. At most one per screen: it is how the screen says "start
  /// here". Its contents draw in `colors.brand.onSolid` and
  /// `colors.onBrandMuted`, never in ink.
  brand,

  /// Accent-tinted. Warmth, not status — a saved doctor, a highlighted note.
  accent,
}

/// The app's container.
///
/// Elevation is depth ordering, never decoration: a card that does not float
/// over anything does not get a shadow, it gets an outline. PRODUCT.md lists
/// "drop shadows for their own sake" as an anti-reference.
class MedicoCard extends StatelessWidget {
  const MedicoCard({
    super.key,
    required this.child,
    this.variant = MedicoCardVariant.plain,
    this.onTap,
    this.padding = const EdgeInsets.all(Insets.md),
    this.radius = Radii.xlAll,
    this.raised = false,
    this.semanticLabel,
  });

  final Widget child;
  final MedicoCardVariant variant;

  /// When set, the whole card is one target — not a "View" link in the corner
  /// that a thumb has to find.
  final VoidCallback? onTap;

  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  /// Genuinely floating over content. Adds a shadow; most cards do not need it.
  final bool raised;

  /// Collapses the card's contents into one announcement. Use it when the card
  /// is a single subject — a doctor, an appointment — so a screen-reader user
  /// hears one thing they can act on instead of six fragments.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (background, border) = switch (variant) {
      MedicoCardVariant.plain => (c.surface, null),
      MedicoCardVariant.outlined => (c.surface, Border.all(color: c.line)),
      MedicoCardVariant.brand => (c.brand.solid, null),
      MedicoCardVariant.accent => (
          c.accent.container,
          Border.all(color: c.accent.border),
        ),
    };

    Widget card = Material(
      color: background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (border != null) {
      card = DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, border: border),
        child: card,
      );
    }

    if (raised) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: c.shadowMd,
        ),
        child: card,
      );
    }

    if (semanticLabel != null) {
      card = Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        excludeSemantics: true,
        child: card,
      );
    }

    return card;
  }
}

/// A heading over a group, with an optional action opposite it.
///
/// The action is a text button rather than a chevron: "See all" says what it
/// does, and a chevron on its own is a 24pt target with no name.
class MedicoSectionHeader extends StatelessWidget {
  const MedicoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleMedium),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// The hairline between two [MedicoListRow]s in the same card.
///
/// Inset past the leading icon so the rule starts where the text does, which
/// is what makes a stack of rows read as one list rather than as slices.
class MedicoDivider extends StatelessWidget {
  const MedicoDivider({super.key, this.indent = Insets.md});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: indent,
      color: context.colors.line,
    );
  }
}

/// A row in a list of things: a record, a setting, a notification, a message.
///
/// The whole row is the target and the whole row is one semantic node, so a
/// screen-reader user hears "Blood test results, 14 March, action needed" and
/// double-taps, rather than swiping through three separate fragments.
class MedicoListRow extends StatelessWidget {
  const MedicoListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.semanticLabel,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.md,
      vertical: Insets.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// A badge, a timestamp, a switch. Replaces the chevron when set.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.sm),
            trailing!,
          ] else if (showChevron && onTap != null) ...[
            const SizedBox(width: Insets.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: IconSize.lg,
              color: c.inkMuted,
            ),
          ],
        ],
      ),
    );

    final tappable = onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            borderRadius: Radii.mdAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: Layout.minTapTarget,
              ),
              child: row,
            ),
          );

    // Collapsing the row into one node is right when the row is inert
    // content, and wrong when [trailing] is itself a control — a switch the
    // patient has to be able to reach. So it only collapses when there is
    // nothing interactive to hide.
    final collapse = trailing == null;

    return Semantics(
      container: true,
      label: collapse
          ? (semanticLabel ?? (subtitle == null ? title : '$title. $subtitle'))
          : null,
      button: collapse && onTap != null,
      excludeSemantics: collapse,
      child: tappable,
    );
  }
}
