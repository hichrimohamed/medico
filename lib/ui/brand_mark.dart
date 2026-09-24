import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Medico's wordmark: the artwork's medical cross, set solid so it holds up at
/// icon size, beside the name.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    // A logo is an image of a name, not body copy: it follows the patient's
    // text-size setting part of the way, then stops, so the lockup keeps its
    // proportions instead of dwarfing its own badge.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);
    final glyphSize = size * (scaler.scale(16) / 16);

    return Semantics(
      label: 'Medico',
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CrossGlyph(size: glyphSize),
            if (showWordmark) ...[
              SizedBox(width: glyphSize * 0.3),
              Text(
                'Medico',
                textScaler: TextScaler.noScaling,
                style: context.text.titleLarge?.copyWith(
                  fontSize: glyphSize * 0.62,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                  color: context.colors.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CrossGlyph extends StatelessWidget {
  const _CrossGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.16;
    final arm = size * 0.5;

    // The one place in the system that reaches past the colour roles for a
    // raw pigment, and it is deliberate: a logo is fixed artwork, not themed
    // UI. Drawn from `colors.brand`, the mark would invert in dark mode —
    // navy cross on pale blue — and a medical cross that changes colour with
    // the OS setting is not a mark, it is a decoration. The cross stays white
    // in both themes; only the badge lifts a step in dark mode so it does not
    // sink into the page.
    final badge = context.isDarkTheme
        ? AppPalette.blue500
        : AppPalette.blue600;
    const cross = AppPalette.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badge,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: SizedBox(
          width: arm,
          height: arm,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Bar(width: arm, height: bar, radius: bar * 0.34, color: cross),
              _Bar(width: bar, height: arm, radius: bar * 0.34, color: cross),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A quieter lockup for secondary screens: the glyph, a back affordance's
/// worth of weight, no wordmark.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, this.size = Insets.xxl});

  final double size;

  @override
  Widget build(BuildContext context) => _CrossGlyph(size: size);
}
