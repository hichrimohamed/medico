import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/theme/app_colors.dart';
import 'package:medico/theme/app_theme.dart';
import 'package:medico/theme/app_typography.dart';

/// PRODUCT.md commits the app to WCAG 2.2 AA. This turns that commitment into
/// something that fails a build rather than something that survives in a
/// design doc: every colour pairing the system promises is measured here, in
/// both themes.
///
/// If you are here because this test went red, the fix is the palette, not the
/// threshold.
void main() {
  group('light', () => _auditTheme(MedicoColors.light, 'light'));
  group('dark', () => _auditTheme(MedicoColors.dark, 'dark'));

  test('both themes register MedicoColors so context.colors never falls back', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.extension<MedicoColors>(), isNotNull);
      expect(theme.extension<MedicoColors>()!.brightness, theme.brightness);
    }
  });

  test('headings are Inter Tight, body and labels are the platform font', () {
    final text = AppTheme.light.textTheme;

    for (final style in [
      text.displaySmall,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
    ]) {
      expect(style!.fontFamily, AppTypography.headingFamily);
      expect(
        style.fontWeight!.value,
        greaterThanOrEqualTo(FontWeight.w600.value),
        reason: 'only weights 600 and 700 are bundled',
      );
    }

    for (final style in [
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(
        style!.fontFamily,
        isNot(AppTypography.headingFamily),
        reason: 'form controls read in the platform font',
      );
    }
  });
}

void _auditTheme(MedicoColors c, String label) {
  // ------------------------------------------------------------------- text
  group('text on its grounds', () {
    for (final ground in [
      ('canvas', c.canvas),
      ('surface', c.surface),
      ('surfaceRaised', c.surfaceRaised),
      ('panel', c.panel),
    ]) {
      _expectContrast('ink', c.ink, ground.$1, ground.$2, 4.5);
      _expectContrast('inkBody', c.inkBody, ground.$1, ground.$2, 4.5);
      _expectContrast('inkMuted', c.inkMuted, ground.$1, ground.$2, 4.5);
    }

    // Placeholders are held to the body-text bar, not the muted-grey default.
    _expectContrast('inkPlaceholder', c.inkPlaceholder, 'surface', c.surface, 4.5);
  });

  // ------------------------------------------------------------- boundaries
  group('interactive boundaries (WCAG 2.2 non-text, 3:1)', () {
    for (final ground in [('surface', c.surface), ('canvas', c.canvas)]) {
      _expectContrast('control', c.control, ground.$1, ground.$2, 3.0);
      _expectContrast('focus', c.focus, ground.$1, ground.$2, 3.0);
    }
  });

  // ------------------------------------------------------------------ roles
  for (final role in <(String, MedicoTone)>[
    ('brand', c.brand),
    ('accent', c.accent),
    ('danger', c.danger),
    ('success', c.success),
    ('warning', c.warning),
    ('info', c.info),
    ('neutral', c.neutral),
  ]) {
    final name = role.$1;
    final tone = role.$2;

    group('$name tone', () {
      _expectContrast('$name.onSolid', tone.onSolid, '$name.solid', tone.solid, 4.5);
      _expectContrast('$name.ink', tone.ink, 'surface', c.surface, 4.5);
      _expectContrast('$name.ink', tone.ink, 'canvas', c.canvas, 4.5);
      _expectContrast('$name.ink', tone.ink, '$name.container', tone.container, 4.5);

      // The border is not load-bearing for accessibility — the container tint
      // and a mandatory icon carry the meaning — but it does have to be
      // visible, or it is dead code in the palette.
      _expectContrast('$name.border', tone.border, '$name.container', tone.container, 1.15);
    });
  }

  test('$label: supporting text on a brand fill stays readable', () {
    _expectRatio(c.onBrandMuted, c.brand.solid, 4.5, 'onBrandMuted on brand.solid');
  });

  test('$label: surfaces are distinguishable from the canvas', () {
    for (final surface in [
      ('surface', c.surface),
      ('surfaceRaised', c.surfaceRaised),
      ('surfaceSunken', c.surfaceSunken),
    ]) {
      // Not a WCAG rule — a sanity check that the ground stack has not
      // collapsed into one flat colour after an edit.
      expect(
        _ratio(surface.$2, c.canvas),
        isNot(1.0),
        reason: '${surface.$1} is identical to the canvas',
      );
    }
  });
}

void _expectContrast(
  String fgName,
  Color fg,
  String bgName,
  Color bg,
  double min,
) {
  test('$fgName on $bgName ≥ $min:1', () {
    _expectRatio(fg, bg, min, '$fgName on $bgName');
  });
}

void _expectRatio(Color fg, Color bg, double min, String what) {
  final ratio = _ratio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$what is ${ratio.toStringAsFixed(2)}:1, needs $min:1 '
        '(${_hex(fg)} on ${_hex(bg)})',
  );
}

/// WCAG 2.x relative luminance and contrast ratio.
double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

String _hex(Color c) {
  int v(double d) => (d * 255).round();
  return '#${v(c.r).toRadixString(16).padLeft(2, '0')}'
          '${v(c.g).toRadixString(16).padLeft(2, '0')}'
          '${v(c.b).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}
