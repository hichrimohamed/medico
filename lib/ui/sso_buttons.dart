import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/auth/data/auth_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Provider sign-in, stacked full width rather than side by side: "Continue
/// with Google" must survive a long translation and 200% text scale without
/// truncating.
class SsoButton extends StatelessWidget {
  const SsoButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.busy = false,
  });

  final SsoProvider provider;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(Layout.primaryButtonHeight),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: busy
                ? CircularProgressIndicator(strokeWidth: 2.2, color: c.inkMuted)
                : switch (provider) {
                    SsoProvider.google => const GoogleGlyph(size: IconSize.md),
                    SsoProvider.apple => Icon(Icons.apple, size: 22, color: c.ink),
                  },
          ),
          const SizedBox(width: Insets.sm),
          Flexible(
            child: Text(
              'Continue with ${provider.label}',
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(color: c.inkBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Google mark, drawn rather than shipped as a bitmap so it stays crisp at
/// every density.
///
/// NOTE(brand): Google's identity guidelines require the official asset for
/// production sign-in buttons. Swap this for `google_g_logo.svg` from the
/// Google Identity brand kit before release — the geometry here is a faithful
/// stand-in, not the licensed mark.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = s * 0.205;
    final radius = (s - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    void arc(Color color, double startDeg, double sweepDeg) {
      canvas.drawArc(
        rect,
        _rad(startDeg),
        _rad(sweepDeg),
        false,
        paint..color = color,
      );
    }

    // Overlap each arc by a degree so antialiased seams do not show the
    // background through the joins.
    arc(AppPalette.googleRed, -166, 111); // top
    arc(AppPalette.googleBlue, -56, 109); // upper right, down into the bar
    arc(AppPalette.googleGreen, 52, 77); // bottom
    arc(AppPalette.googleYellow, 128, 67); // left

    // The crossbar: top edge on the centre line, running out flush with the
    // ring's outer edge.
    final bar = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        center.dx - s * 0.015,
        center.dy - stroke * 0.06,
        center.dx + radius + stroke / 2,
        center.dy - stroke * 0.06 + stroke * 0.95,
      ),
      topLeft: Radius.circular(s * 0.015),
      bottomLeft: Radius.circular(s * 0.015),
    );
    canvas.drawRRect(
      bar,
      Paint()
        ..color = AppPalette.googleBlue
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _GooglePainter oldDelegate) => false;
}

/// "or continue with", set as a rule so it separates without shouting.
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = context.colors.line;

    return Row(
      children: [
        Expanded(child: Divider(color: line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Text(label, style: context.text.bodySmall),
        ),
        Expanded(child: Divider(color: line)),
      ],
    );
  }
}
