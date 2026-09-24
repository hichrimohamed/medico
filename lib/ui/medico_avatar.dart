import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// A person, as a circle.
///
/// When there is no photograph the fallback is initials on a tinted ground,
/// not a grey silhouette: a silhouette reads as a broken image, and a patient
/// who thinks the app is broken does not book an appointment.
class MedicoAvatar extends StatelessWidget {
  const MedicoAvatar({
    super.key,
    required this.name,
    this.image,
    this.initials,
    this.size = AvatarSize.md,
    this.onBrand = false,
  });

  final String name;
  /// A bundled asset path, or an `https://` URL. Either draws; neither is
  /// required, and a failure of either lands on the initials below.
  final String? image;

  /// Override the derived initials — useful for a name where the first and
  /// last word are not the right two letters.
  final String? initials;

  final double size;

  /// Sits on a brand-filled surface rather than on a normal one.
  final bool onBrand;

  /// First letter of the first and last words. "Dr Ada Okoro" → "AO".
  String get _initials {
    if (initials != null) return initials!;
    final words = name
        .replaceAll(RegExp(r'^(Dr|Dr\.|Prof|Prof\.)\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words.first.characters.first + words.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final background =
        onBrand ? c.brand.onSolid.withValues(alpha: 0.16) : c.brand.container;
    final foreground = onBrand ? c.brand.onSolid : c.brand.ink;

    final fallback = ColoredBox(
      color: background,
      child: Center(
        child: Text(
          _initials,
          // A monogram is a graphic, not body copy. Scaling it with the
          // patient's text setting would burst its own circle.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: foreground,
          ),
        ),
      ),
    );

    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: switch (image) {
            null => fallback,
            final String url when url.startsWith('http') => Image.network(
                url,
                fit: BoxFit.cover,
                // A face that has not arrived yet shows the initials, not a
                // spinner in a circle.
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (context, _, _) => fallback,
              ),
            final String asset => Image.asset(
                asset,
                fit: BoxFit.cover,
                // A missing asset must not leave a hole where a face goes.
                errorBuilder: (context, _, _) => fallback,
              ),
          },
        ),
      ),
    );
  }
}
