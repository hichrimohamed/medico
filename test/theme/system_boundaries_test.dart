import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A design system is a folder until something stops people leaving it.
///
/// These three rules are the whole enforcement mechanism. The first two are
/// what dark mode breaks the moment they are relaxed; the third is what a
/// design system loses quietly, without ever looking broken:
///
/// 1. Feature code does not import the raw palette.
/// 2. Feature code does not write a colour literal.
/// 3. Feature code does not set a font size.
///
/// The first two were true of every bug the first dark-mode render turned up —
/// a white card that stayed white on a dark page, a gold star hard-coded as
/// `Color(0xFFF2A73B)`. Neither was visible in light mode, and neither would
/// have been caught by a type checker.
///
/// The third rule is the same failure in the other axis. Type drifted the way
/// colour did: twenty-four hand-picked sizes across the features — a 14 here,
/// a 23 there, `displaySmall` overridden to 28 and then to 34 — each one
/// reasonable alone, and together a scale nobody designed. Every one of them
/// turned out to be within a point or two of a role that already existed.
void main() {
  final featureFiles = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('there are feature files to check', () {
    expect(featureFiles, isNotEmpty);
  });

  test('screens do not import the raw palette', () {
    final offenders = <String>[];

    for (final file in featureFiles) {
      if (file.readAsStringSync().contains('theme/app_palette.dart')) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Pigments are chosen in app_colors.dart and nowhere else. '
          'Use context.colors — a screen holding a raw blue is a screen that '
          'is wrong in one of the two themes.\n'
          '${offenders.join('\n')}',
    );
  });

  test('screens do not set font sizes', () {
    // A size that scales with a widget's own dimension — an avatar's initials,
    // a brand glyph — is parametric, not a type choice, and those widgets live
    // in lib/ui where the system is allowed to do arithmetic.
    final sized = RegExp(r'fontSize:');
    final offenders = <String>[];

    for (final file in featureFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (sized.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Type comes from context.text — displaySmall, headlineMedium, '
          'titleLarge, bodyMedium, labelSmall and the rest. If none of the '
          'roles fit, the scale is wrong and belongs in app_typography.dart; '
          'a size at the call site is a private scale of one.\n'
          '${offenders.join('\n')}',
    );
  });

  test('screens do not write colour literals', () {
    // `Colors.transparent` is not a colour, it is the absence of one, and it
    // is identical in both themes.
    final literal = RegExp(
      r'Color\(0x|Colors\.(?!transparent\b)[a-z]',
    );
    final offenders = <String>[];

    for (final file in featureFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Every colour comes from context.colors. If a role is missing, '
          'add it to MedicoColors rather than reaching for a literal here.\n'
          '${offenders.join('\n')}',
    );
  });
}
