/// The Medico design system.
///
/// Screens import this one file. Everything a screen is allowed to draw with
/// comes through here: the components below, the tokens in `app_tokens.dart`,
/// and the colour roles reached through `context.colors`.
///
/// **The rule that keeps this a system rather than a folder:** a screen never
/// imports `app_palette.dart`. Raw pigments are chosen in exactly one place —
/// the light and dark sets in `app_colors.dart` — and a widget that reaches
/// past that will be wrong in one of the two themes.
///
/// If a screen needs something that is not here, the answer is to add it here,
/// not to build it locally. A one-off card on one screen is how a design
/// system dies.
library;

export '../theme/app_colors.dart' show MedicoColors, MedicoTone;
export '../theme/app_tokens.dart';
export '../theme/theme_context.dart';

export 'brand_mark.dart';
export 'medico_app_bar.dart';
export 'medico_avatar.dart';
export 'medico_banner.dart';
export 'medico_bottom_nav.dart';
export 'medico_button.dart';
export 'medico_card.dart';
export 'medico_chip.dart';
export 'medico_overlays.dart';
export 'medico_states.dart';
export 'medico_text_field.dart';
export 'sso_buttons.dart';
export 'status_badge.dart';
