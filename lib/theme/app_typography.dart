import 'package:flutter/material.dart';

/// Two families, one job each.
///
/// **Inter Tight** carries headings. It is bundled, so a heading is identical
/// on every device and the brand holds its shape across iOS and Android.
///
/// **The platform font** — SF Pro on iOS, Roboto on Android — carries body
/// copy, labels and every form control. This is not a compromise: a patient
/// filling in a password field should feel the phone they already know, and
/// autofill, password managers and the system keyboard all render in it.
/// PRODUCT.md calls this "earned familiarity", and the auth surface is exactly
/// where invention is a bug.
///
/// The split is enforced by role, not by taste at the call site: anything in
/// [TextTheme] named `display`, `headline` or `title` is Inter Tight;
/// everything named `body` or `label` is the platform font.
abstract final class AppTypography {
  const AppTypography._();

  /// The bundled family. Declared in `pubspec.yaml` at weights 600 and 700
  /// only — headings do not need a regular weight, and shipping one would add
  /// 150KB to carry text that is set in the platform font anyway.
  static const String headingFamily = 'InterTight';

  /// If the subset does not cover the script in play, headings fall back here
  /// rather than to a blank box.
  static const List<String> headingFallback = <String>[
    'SF Pro Display',
    'Roboto',
  ];

  /// Fixed scale, ~1.2 ratio. Product UI is viewed at a consistent distance;
  /// fluid type would only make labels inconsistent screen to screen. Patients
  /// scale text with the OS setting instead, which every size here survives to
  /// 200%.
  static TextTheme build(Color ink, Color body, Color muted) {
    TextStyle heading({
      required double size,
      required double height,
      required FontWeight weight,
      required double tracking,
    }) {
      return TextStyle(
        fontFamily: headingFamily,
        fontFamilyFallback: headingFallback,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: tracking,
        color: ink,
      );
    }

    return TextTheme(
      // ------------------------------------------------------------ headings
      /// A screen's one true title. One per screen, or none.
      displaySmall: heading(
        size: 32,
        height: 1.18,
        weight: FontWeight.w700,
        tracking: -0.6,
      ),
      headlineMedium: heading(
        size: 27,
        height: 1.22,
        weight: FontWeight.w700,
        tracking: -0.5,
      ),
      headlineSmall: heading(
        size: 23,
        height: 1.24,
        weight: FontWeight.w700,
        tracking: -0.4,
      ),

      /// Section headings, card subjects, a doctor's name.
      titleLarge: heading(
        size: 21,
        height: 1.3,
        weight: FontWeight.w600,
        tracking: -0.2,
      ),
      titleMedium: heading(
        size: 17,
        height: 1.35,
        weight: FontWeight.w600,
        tracking: -0.1,
      ),
      titleSmall: heading(
        size: 15,
        height: 1.35,
        weight: FontWeight.w600,
        tracking: 0,
      ),

      // ---------------------------------------------------- body (platform)
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: body,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.47,
        fontWeight: FontWeight.w400,
        color: body,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),

      // -------------------------------------------------- labels (platform)
      // Labels carry the default ink so a bare Text() is readable in both
      // themes. Inside a button, `ButtonStyle.foregroundColor` wins over this,
      // which is what puts a white label on a filled brand button.
      labelLarge: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: muted,
      ),
    );
  }
}
