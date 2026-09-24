import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The single source of visual truth.
///
/// Light and dark are built by one function from one [MedicoColors] set, so a
/// component theme can never drift between them: if a control is themed here,
/// it is themed in both.
///
/// Two layers reach screens from this file:
///
/// 1. **Material theming** — plain `FilledButton`, `TextField`, `Card` and
///    friends already look correct, so a screen that reaches for a stock
///    widget does not look foreign.
/// 2. **[MedicoColors]**, registered as a `ThemeExtension` and read through
///    `context.colors`, for everything Material has no role for: status tones,
///    panel grounds, skeleton fills.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(MedicoColors.light);

  static ThemeData get dark => _build(MedicoColors.dark);

  static ThemeData _build(MedicoColors c) {
    final scheme = _scheme(c);

    // Merge through Typography so body and label styles inherit the platform
    // font family. Passing a raw TextTheme into the button themes leaves their
    // labels with no family at all.
    final typography = Typography.material2021(colorScheme: scheme);
    final base = c.isDark ? typography.white : typography.black;
    final text = base.merge(AppTypography.build(c.ink, c.inkBody, c.inkMuted));

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      textTheme: text,
      typography: typography,
      splashFactory: InkSparkle.splashFactory,
      shadowColor: c.shadow,

      // The focus ring is the same everywhere and never subtle. Keyboard and
      // switch-control users should be able to find it without hunting.
      focusColor: c.focus.withValues(alpha: 0.12),
      highlightColor: c.brand.solid.withValues(alpha: 0.06),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md + 2,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: c.inkPlaceholder),
        helperStyle: text.bodySmall?.copyWith(color: c.inkMuted),
        errorStyle: text.bodySmall?.copyWith(color: c.danger.ink, height: 1.35),
        errorMaxLines: 3,
        border: _border(c.control),
        enabledBorder: _border(c.control),
        focusedBorder: _border(c.focus, width: Layout.focusRingWidth),
        errorBorder: _border(c.danger.solid, width: 1.5),
        focusedErrorBorder: _border(c.danger.solid, width: Layout.focusRingWidth),
        disabledBorder: _border(c.line),
        suffixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? c.focus
              : c.inkMuted,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Layout.primaryButtonHeight),
          backgroundColor: c.brand.solid,
          foregroundColor: c.brand.onSolid,
          disabledBackgroundColor: c.isDark ? c.brand.container : c.brand.border,
          disabledForegroundColor: c.isDark ? c.inkDisabled : c.brand.ink,
          textStyle: text.labelLarge,
          shape: kButtonShape,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Layout.minTapTarget),
          foregroundColor: c.inkBody,
          backgroundColor: c.surface,
          disabledForegroundColor: c.inkDisabled,
          textStyle: text.labelLarge,
          side: BorderSide(color: c.control),
          shape: kButtonShape,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand.ink,
          disabledForegroundColor: c.inkDisabled,
          textStyle: text.labelMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xs,
            vertical: Insets.xs,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.inkMuted,
          minimumSize: const Size.square(Layout.minTapTarget),
        ),
      ),

      iconTheme: IconThemeData(color: c.inkBody, size: IconSize.lg),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.line;
          if (states.contains(WidgetState.selected)) return c.brand.solid;
          return c.surface;
        }),
        checkColor: WidgetStatePropertyAll(c.brand.onSolid),
        side: BorderSide(color: c.control, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        visualDensity: VisualDensity.standard,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand.onSolid;
          return c.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.line;
          if (states.contains(WidgetState.selected)) return c.brand.solid;
          return c.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return c.control;
        }),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand.solid;
          return c.control;
        }),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      ),

      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        textColor: c.inkBody,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.brand.solid,
        disabledColor: c.surfaceSunken,
        labelStyle: text.labelSmall?.copyWith(color: c.inkBody),
        secondaryLabelStyle: text.labelSmall?.copyWith(color: c.brand.onSolid),
        side: BorderSide(color: c.control),
        shape: kButtonShape,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? c.surfaceRaised : c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: c.isDark ? c.ink : c.surface,
        ),
        actionTextColor: c.isDark ? c.brand.ink : c.brand.border,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        insetPadding: const EdgeInsets.all(Insets.md),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
        dragHandleColor: c.line,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        barrierColor: c.scrim,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceRaised : c.ink,
          borderRadius: Radii.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(
          color: c.isDark ? c.ink : c.surface,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: systemOverlay(c.brightness),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand.solid,
        linearTrackColor: c.brand.container,
        circularTrackColor: Colors.transparent,
      ),

      // Each platform keeps its own page transition. A patient should not
      // have to learn how this app moves — it moves like their phone does.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Status-bar and navigation-bar treatment for a given theme. The app runs
  /// edge to edge, so the OS bars have to be told which way the page reads.
  static SystemUiOverlayStyle systemOverlay(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = dark ? MedicoColors.dark : MedicoColors.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.canvas,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  /// Material's own roles, filled from ours. Every stock widget reads these,
  /// so keeping them honest is what stops a plain `Card` or `FilledButton`
  /// from looking like it came from a different app.
  static ColorScheme _scheme(MedicoColors c) {
    return ColorScheme(
      brightness: c.brightness,
      primary: c.brand.solid,
      onPrimary: c.brand.onSolid,
      primaryContainer: c.brand.container,
      onPrimaryContainer: c.brand.ink,
      secondary: c.accent.solid,
      onSecondary: c.accent.onSolid,
      secondaryContainer: c.accent.container,
      onSecondaryContainer: c.accent.ink,
      tertiary: c.success.solid,
      onTertiary: c.success.onSolid,
      tertiaryContainer: c.success.container,
      onTertiaryContainer: c.success.ink,
      error: c.danger.solid,
      onError: c.danger.onSolid,
      errorContainer: c.danger.container,
      onErrorContainer: c.danger.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.isDark ? c.surfaceSunken : c.surface,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.panel,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.control,
      outlineVariant: c.line,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.isDark ? c.ink : c.surfaceSunken,
      onInverseSurface: c.isDark ? c.canvas : c.ink,
      inversePrimary: c.isDark ? c.brand.container : c.brand.border,
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: Radii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
