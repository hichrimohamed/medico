import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// The app's top bar.
///
/// Left-aligned title, no elevation, no tint on scroll. The bar is a place to
/// go back from, not a piece of chrome to look at.
class MedicoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MedicoAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.showBack = true,
    this.backgroundColor,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      backgroundColor: backgroundColor ?? context.colors.canvas,
      title: title == null
          ? null
          : Semantics(header: true, child: Text(title!)),
      leading: leading ??
          (showBack && canPop ? const MedicoBackButton.icon() : null),
      automaticallyImplyLeading: false,
      actions: actions,
      titleSpacing: leading == null && !(showBack && canPop)
          ? Insets.gutter
          : null,
    );
  }
}

/// Back, in two shapes.
///
/// The labelled form is for a screen with no app bar — an auth screen, a
/// full-bleed detail page — where a bare chevron would be a 24pt target with
/// no name. The icon form is for inside an app bar, where the position already
/// says what it is.
///
/// Both disappear when there is nothing to go back to, so a deep link straight
/// into the screen does not offer a dead control.
class MedicoBackButton extends StatelessWidget {
  const MedicoBackButton({super.key, this.label = 'Back'}) : _iconOnly = false;

  const MedicoBackButton.icon({super.key, this.label = 'Back'})
      : _iconOnly = true;

  final String label;
  final bool _iconOnly;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();

    final c = context.colors;

    if (_iconOnly) {
      return IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: label,
        color: c.ink,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, size: IconSize.md),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: c.inkMuted,
          padding: const EdgeInsets.fromLTRB(
            Insets.xs,
            Insets.xs,
            Insets.sm,
            Insets.xs,
          ),
          minimumSize: const Size(0, Layout.minTapTarget),
        ),
      ),
    );
  }
}
