import 'package:flutter/material.dart';

import 'app_colors.dart';

/// How every widget reaches the design system.
///
/// ```dart
/// Container(
///   color: context.colors.surface,
///   child: Text('Next appointment', style: context.text.titleMedium),
/// )
/// ```
///
/// There is no fallback and no null case: [MedicoColors] is registered on both
/// themes in `app_theme.dart`, so a missing extension means the widget is being
/// built outside the app's `MaterialApp` — which is a bug worth an assertion,
/// not a silent grey default.
extension MedicoThemeContext on BuildContext {
  /// Semantic colour roles for the active theme.
  MedicoColors get colors {
    final colors = Theme.of(this).extension<MedicoColors>();
    assert(
      colors != null,
      'MedicoColors is missing from the ambient Theme. Wrap this widget in '
      'AppTheme.light or AppTheme.dark — see lib/theme/app_theme.dart.',
    );
    return colors ?? MedicoColors.light;
  }

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}
