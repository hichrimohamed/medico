import 'package:flutter/painting.dart';

/// Raw colour primitives. **Screens never import this file.**
///
/// These are pigments, not roles: `blue600` says nothing about what it is for.
/// Roles live in [MedicoColors] (`app_colors.dart`) and are read through
/// `context.colors`, so the same widget renders correctly in both themes.
///
/// The blue ramp is sampled from, or interpolated between, pixels in
/// `assets/images/auth_hero.jpg` — the artwork is the brand, so the UI shares
/// its hue rather than approximating it.
///
/// The ochre ramp is *not* from the artwork. The illustration contains no warm
/// colour beyond skin tone, so the accent was built to sit against the blue:
/// hue ~40°, held back from orange so it never reads as a warning when it is
/// only meant to read as warmth.
///
/// Every contrast figure noted here is verified in `test/theme/contrast_test.dart`.
/// Do not substitute a lighter value for a text or boundary role without
/// re-running that test.
abstract final class AppPalette {
  const AppPalette._();

  // ------------------------------------------------------------------- blue
  /// Deepest ink in the artwork (the clinician's hair, the stethoscope line).
  static const Color blue950 = Color(0xFF061C40);
  static const Color blue900 = Color(0xFF0A2A5E);
  static const Color blue800 = Color(0xFF113C6B);
  static const Color blue700 = Color(0xFF17518F);

  /// Primary action fill in the light theme. White on this: 6.45:1.
  static const Color blue600 = Color(0xFF1D5FA8);

  /// The artwork's icon blue (heart, cross, calendar glyphs).
  /// Graphic use only — 4.10:1 with white, below the bar for body text.
  static const Color blue500 = Color(0xFF3B80C9);

  /// Primary action fill in the dark theme. Navy label on this: 7.10:1.
  static const Color blue400 = Color(0xFF6FA7E0);
  static const Color blue300 = Color(0xFFA3C7EE);
  static const Color blue200 = Color(0xFFC9DEF5);
  static const Color blue100 = Color(0xFFE3EEFA);
  static const Color blue50 = Color(0xFFF2F7FD);

  // ------------------------------------------------------------------ ochre
  /// The secondary accent. Carries warmth and second-rank emphasis: a saved
  /// doctor, a highlighted date, a "3 slots left" nudge. It is deliberately
  /// **not** a status colour — see [MedicoColors.warning] for that role, which
  /// shares the pigment but is used only when something needs attention.
  static const Color ochre900 = Color(0xFF3E2B08);
  static const Color ochre800 = Color(0xFF5A3F0C);

  /// 6.93:1 on white. Text on a subtle ochre container.
  static const Color ochre700 = Color(0xFF77530F);

  /// 5.04:1 on white, 4.77:1 on canvas. The lightest ochre that carries text.
  static const Color ochre600 = Color(0xFF946614);

  /// 3.33:1 on white. Boundaries and graphics only, never body text.
  static const Color ochre500 = Color(0xFFB8831A);

  /// Dark-theme accent: 7.04:1 on the dark surface.
  static const Color ochre400 = Color(0xFFD6A02C);
  static const Color ochre300 = Color(0xFFE7BC60);
  static const Color ochre200 = Color(0xFFF2D699);
  static const Color ochre100 = Color(0xFFF9EACB);
  static const Color ochre50 = Color(0xFFFDF6E9);

  // ------------------------------------------------- slate (cool neutrals)
  /// Neutrals carry a blue cast on purpose. A truly grey UI beside this blue
  /// reads as two unrelated systems; these sit under the brand instead.
  static const Color slate900 = Color(0xFF0A2A5E);
  static const Color slate800 = Color(0xFF1B3557);
  static const Color slate700 = Color(0xFF36486A);
  static const Color slate600 = Color(0xFF4E6486);
  static const Color slate500 = Color(0xFF56698A);
  static const Color slate400 = Color(0xFF6B93C2);
  static const Color slate300 = Color(0xFF8FA2BE);

  /// The boundary of a neutral container. slate200 is a divider colour and is
  /// too close to slate100 to read as an edge against it.
  static const Color slate250 = Color(0xFFC2D0E2);
  static const Color slate200 = Color(0xFFDCE7F5);
  static const Color slate100 = Color(0xFFEDF4FD);
  static const Color slate50 = Color(0xFFF6F9FD);
  static const Color white = Color(0xFFFFFFFF);

  // ------------------------------------------------------ dark-theme ground
  /// Navy rather than black. Pure black beside this blue looks like a hole in
  /// the screen, and it makes light text halate on OLED.
  static const Color night950 = Color(0xFF08172A);
  static const Color night900 = Color(0xFF0A1626);
  static const Color night800 = Color(0xFF111F33);
  static const Color night700 = Color(0xFF16263C);
  static const Color night600 = Color(0xFF1A2B42);
  static const Color night500 = Color(0xFF243855);
  static const Color night400 = Color(0xFF617FAB);
  static const Color night300 = Color(0xFF5D738F);
  static const Color night200 = Color(0xFF93A8C4);
  static const Color night100 = Color(0xFF9FB3CC);
  static const Color night50 = Color(0xFFD3E0EF);
  static const Color night0 = Color(0xFFEAF1FA);

  // --------------------------------------------------------------- feedback
  static const Color red900 = Color(0xFF3B1512);
  static const Color red800 = Color(0xFF8C1D18);
  static const Color red600 = Color(0xFFB3261E);
  static const Color red300 = Color(0xFFF2938C);
  static const Color red200 = Color(0xFFFFB4AB);
  static const Color red50 = Color(0xFFFDECEA);

  static const Color green900 = Color(0xFF0A2C1E);
  static const Color green800 = Color(0xFF0B5637);
  static const Color green600 = Color(0xFF0F6B45);
  static const Color green300 = Color(0xFF5FC894);
  static const Color green200 = Color(0xFF7CD9AA);
  static const Color green50 = Color(0xFFE8F5EE);

  // ------------------------------------------------------------ brand marks
  /// Third-party marks. Fixed by their owners' guidelines — these do not
  /// change between themes and are never re-tinted.
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleBlue = Color(0xFF4285F4);
}
