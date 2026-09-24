import 'package:flutter/material.dart';

import 'app_palette.dart';

/// A complete colour role, in five parts.
///
/// One tone covers every way a meaning shows up on screen, so a status never
/// has to be assembled by hand at the call site:
///
/// * [solid] — a saturated fill: a badge, a dot, a filled button.
/// * [onSolid] — text and icons drawn on [solid]. Always ≥ 4.5:1 against it.
/// * [ink] — the meaning as text or an icon on a normal surface, **and** on
///   [container]. Always ≥ 4.5:1 against both.
/// * [container] — a quiet tinted background: a banner, a subtle chip.
/// * [border] — the boundary of [container]. ≥ 3:1 against the surface behind.
@immutable
class MedicoTone {
  const MedicoTone({
    required this.solid,
    required this.onSolid,
    required this.ink,
    required this.container,
    required this.border,
  });

  final Color solid;
  final Color onSolid;
  final Color ink;
  final Color container;
  final Color border;

  static MedicoTone lerp(MedicoTone a, MedicoTone b, double t) {
    return MedicoTone(
      solid: Color.lerp(a.solid, b.solid, t)!,
      onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
      ink: Color.lerp(a.ink, b.ink, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      border: Color.lerp(a.border, b.border, t)!,
    );
  }
}

/// Every colour the app is allowed to use, named by what it means rather than
/// what it looks like.
///
/// Read it through `context.colors` (see `theme_context.dart`). A widget that
/// reaches for [AppPalette] directly is a widget that will be wrong in one of
/// the two themes — the light and dark sets below are the only place a raw
/// pigment is ever chosen.
@immutable
class MedicoColors extends ThemeExtension<MedicoColors> {
  const MedicoColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.panel,
    required this.scrim,
    required this.ink,
    required this.inkBody,
    required this.inkMuted,
    required this.inkPlaceholder,
    required this.inkDisabled,
    required this.line,
    required this.control,
    required this.focus,
    required this.shadow,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.brand,
    required this.onBrandMuted,
    required this.accent,
    required this.danger,
    required this.success,
    required this.warning,
    required this.info,
    required this.neutral,
  });

  final Brightness brightness;

  // ------------------------------------------------------------------ ground
  /// The page behind everything.
  final Color canvas;

  /// Cards, sheets, inputs — anything the patient acts on.
  final Color surface;

  /// A surface that sits above its neighbours: a floating nav bar, a menu.
  final Color surfaceRaised;

  /// A well pressed into the page: a search field on canvas, a code block.
  final Color surfaceSunken;

  /// The artwork's ground, so an illustration bleeds into the page instead of
  /// sitting on it as a pasted rectangle.
  final Color panel;

  /// Behind a modal. Already carries its alpha.
  final Color scrim;

  // ----------------------------------------------------------------- content
  /// Headings.
  final Color ink;

  /// Body copy.
  final Color inkBody;

  /// Secondary copy, captions, supporting labels.
  final Color inkMuted;

  /// Placeholders are held to the body-text bar, not the muted-grey default —
  /// a patient reading a form in bad light should not have to guess.
  final Color inkPlaceholder;

  /// Exempt from the contrast floor by WCAG, because a disabled control must
  /// also *look* unavailable.
  final Color inkDisabled;

  // -------------------------------------------------------------- boundaries
  /// Decorative rules and dividers. Never a control boundary.
  final Color line;

  /// Interactive boundaries: input outlines, secondary buttons. ≥ 3:1.
  final Color control;

  /// The focus ring. Deliberately the brand colour and deliberately loud —
  /// keyboard and switch users need to find it without hunting.
  final Color focus;

  final Color shadow;

  final Color skeletonBase;
  final Color skeletonHighlight;

  // ------------------------------------------------------------------- roles
  /// The primary action and everything that behaves like one.
  final MedicoTone brand;

  /// Supporting text on a brand-filled surface — the specialty above a
  /// doctor's name on the featured card.
  final Color onBrandMuted;

  /// Warmth and second-rank emphasis: a saved doctor, a highlighted date.
  ///
  /// The accent shares its pigment with [warning], so it carries one hard
  /// rule: **the accent never appears as a status.** No badges, no pills, no
  /// "your appointment is…". If a patient could read it as a state of their
  /// care, it is a status colour and belongs to one of the roles below.
  final MedicoTone accent;

  final MedicoTone danger;
  final MedicoTone success;

  /// Something needs attention but nothing has failed.
  final MedicoTone warning;

  /// Neutral information. Shares the brand hue: on this surface, blue means
  /// "the system is telling you something", not "this is a button".
  final MedicoTone info;

  /// Past, closed, archived — a state with no emotional charge.
  final MedicoTone neutral;

  bool get isDark => brightness == Brightness.dark;

  /// Resting elevation for a card. Shadows here are for depth ordering, never
  /// decoration: one step, close to the surface, low alpha.
  List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: shadow.withValues(alpha: isDark ? 0.40 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: shadow.withValues(alpha: isDark ? 0.48 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  /// For something genuinely floating over content: the bottom nav, a sheet.
  List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: shadow.withValues(alpha: isDark ? 0.55 : 0.12),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];

  // ------------------------------------------------------------------- light
  static const MedicoColors light = MedicoColors(
    brightness: Brightness.light,
    canvas: AppPalette.slate50,
    surface: AppPalette.white,
    surfaceRaised: AppPalette.white,
    surfaceSunken: AppPalette.slate100,
    panel: AppPalette.slate100,
    scrim: Color(0x730A2A5E),
    ink: AppPalette.slate900,
    inkBody: AppPalette.slate800,
    inkMuted: AppPalette.slate600,
    inkPlaceholder: AppPalette.slate500,
    inkDisabled: AppPalette.slate300,
    line: AppPalette.slate200,
    control: AppPalette.slate400,
    focus: AppPalette.blue600,
    shadow: AppPalette.blue900,
    skeletonBase: AppPalette.slate100,
    skeletonHighlight: AppPalette.white,
    brand: MedicoTone(
      solid: AppPalette.blue600,
      onSolid: AppPalette.white,
      ink: AppPalette.blue700,
      container: AppPalette.blue100,
      border: AppPalette.blue200,
    ),
    onBrandMuted: AppPalette.blue100,
    accent: MedicoTone(
      solid: AppPalette.ochre600,
      onSolid: AppPalette.white,
      ink: AppPalette.ochre700,
      container: AppPalette.ochre50,
      border: AppPalette.ochre200,
    ),
    danger: MedicoTone(
      solid: AppPalette.red600,
      onSolid: AppPalette.white,
      ink: AppPalette.red800,
      container: AppPalette.red50,
      border: Color(0xFFF0BFBB),
    ),
    success: MedicoTone(
      solid: AppPalette.green600,
      onSolid: AppPalette.white,
      ink: AppPalette.green800,
      container: AppPalette.green50,
      border: Color(0xFFBCE0CD),
    ),
    warning: MedicoTone(
      solid: AppPalette.ochre600,
      onSolid: AppPalette.white,
      ink: AppPalette.ochre700,
      container: AppPalette.ochre100,
      border: AppPalette.ochre200,
    ),
    info: MedicoTone(
      solid: AppPalette.blue600,
      onSolid: AppPalette.white,
      ink: AppPalette.blue700,
      container: AppPalette.blue50,
      border: AppPalette.blue200,
    ),
    neutral: MedicoTone(
      solid: AppPalette.slate600,
      onSolid: AppPalette.white,
      ink: AppPalette.slate600,
      container: AppPalette.slate100,
      border: AppPalette.slate250,
    ),
  );

  // -------------------------------------------------------------------- dark
  //
  // Not an inversion. The brand fill flips from deep blue with a white label
  // to light blue with a navy label, because no blue dark enough to read as
  // "Medico blue" carries white text at 4.5:1 on a dark ground. Every solid
  // role does the same, which is why [MedicoTone.onSolid] exists at all.
  static const MedicoColors dark = MedicoColors(
    brightness: Brightness.dark,
    canvas: AppPalette.night900,
    surface: AppPalette.night800,
    surfaceRaised: AppPalette.night600,
    surfaceSunken: AppPalette.night950,
    panel: AppPalette.night700,
    scrim: Color(0xB3020A14),
    ink: AppPalette.night0,
    inkBody: AppPalette.night50,
    inkMuted: AppPalette.night100,
    inkPlaceholder: AppPalette.night200,
    inkDisabled: AppPalette.night300,
    line: AppPalette.night500,
    control: AppPalette.night400,
    focus: AppPalette.blue400,
    shadow: Color(0xFF000000),
    skeletonBase: AppPalette.night600,
    skeletonHighlight: AppPalette.night500,
    brand: MedicoTone(
      solid: AppPalette.blue400,
      onSolid: AppPalette.night950,
      ink: AppPalette.blue300,
      container: Color(0xFF12314F),
      border: Color(0xFF2F5480),
    ),
    onBrandMuted: Color(0xFF123A63),
    accent: MedicoTone(
      solid: AppPalette.ochre400,
      onSolid: Color(0xFF2A1E05),
      ink: AppPalette.ochre300,
      container: Color(0xFF33240A),
      border: AppPalette.ochre800,
    ),
    danger: MedicoTone(
      solid: AppPalette.red200,
      onSolid: Color(0xFF4A1410),
      ink: AppPalette.red200,
      container: AppPalette.red900,
      border: Color(0xFF6E2A24),
    ),
    success: MedicoTone(
      solid: AppPalette.green200,
      onSolid: Color(0xFF06251A),
      ink: AppPalette.green200,
      container: AppPalette.green900,
      border: Color(0xFF185C3F),
    ),
    warning: MedicoTone(
      solid: AppPalette.ochre300,
      onSolid: Color(0xFF2A1E05),
      ink: AppPalette.ochre300,
      container: Color(0xFF33240A),
      border: AppPalette.ochre800,
    ),
    info: MedicoTone(
      solid: AppPalette.blue300,
      onSolid: AppPalette.night950,
      ink: AppPalette.blue300,
      container: Color(0xFF0E2340),
      border: Color(0xFF2C4E77),
    ),
    neutral: MedicoTone(
      solid: AppPalette.night100,
      onSolid: AppPalette.night950,
      ink: AppPalette.night100,
      container: AppPalette.night600,
      border: AppPalette.night500,
    ),
  );

  @override
  MedicoColors copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? panel,
    Color? scrim,
    Color? ink,
    Color? inkBody,
    Color? inkMuted,
    Color? inkPlaceholder,
    Color? inkDisabled,
    Color? line,
    Color? control,
    Color? focus,
    Color? shadow,
    Color? skeletonBase,
    Color? skeletonHighlight,
    MedicoTone? brand,
    Color? onBrandMuted,
    MedicoTone? accent,
    MedicoTone? danger,
    MedicoTone? success,
    MedicoTone? warning,
    MedicoTone? info,
    MedicoTone? neutral,
  }) {
    return MedicoColors(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      panel: panel ?? this.panel,
      scrim: scrim ?? this.scrim,
      ink: ink ?? this.ink,
      inkBody: inkBody ?? this.inkBody,
      inkMuted: inkMuted ?? this.inkMuted,
      inkPlaceholder: inkPlaceholder ?? this.inkPlaceholder,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      line: line ?? this.line,
      control: control ?? this.control,
      focus: focus ?? this.focus,
      shadow: shadow ?? this.shadow,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      brand: brand ?? this.brand,
      onBrandMuted: onBrandMuted ?? this.onBrandMuted,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  MedicoColors lerp(ThemeExtension<MedicoColors>? other, double t) {
    if (other is! MedicoColors) return this;
    return MedicoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkBody: Color.lerp(inkBody, other.inkBody, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkPlaceholder: Color.lerp(inkPlaceholder, other.inkPlaceholder, t)!,
      inkDisabled: Color.lerp(inkDisabled, other.inkDisabled, t)!,
      line: Color.lerp(line, other.line, t)!,
      control: Color.lerp(control, other.control, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight:
          Color.lerp(skeletonHighlight, other.skeletonHighlight, t)!,
      brand: MedicoTone.lerp(brand, other.brand, t),
      onBrandMuted: Color.lerp(onBrandMuted, other.onBrandMuted, t)!,
      accent: MedicoTone.lerp(accent, other.accent, t),
      danger: MedicoTone.lerp(danger, other.danger, t),
      success: MedicoTone.lerp(success, other.success, t),
      warning: MedicoTone.lerp(warning, other.warning, t),
      info: MedicoTone.lerp(info, other.info, t),
      neutral: MedicoTone.lerp(neutral, other.neutral, t),
    );
  }
}
