import 'package:flutter/material.dart';

/// Dimensions, shape and motion.
///
/// These are static rather than a `ThemeExtension` on purpose: unlike colour,
/// none of them change between light and dark, so requiring a `BuildContext`
/// to read a gap would buy nothing and cost every `const` in the app.
/// Colour is the only axis that varies — see `context.colors`.

/// Spacing scale, 4pt-based. Screens use a deliberately uneven rhythm built
/// from these steps: related controls sit close, sections breathe.
abstract final class Insets {
  const Insets._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;

  /// The page gutter. Every screen's content starts here, so a heading on one
  /// screen lines up with a heading on the next.
  static const double gutter = xl;
}

abstract final class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;

  /// Cards that hold a whole subject — a doctor, an appointment.
  static const double xxl = 26;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));

  /// Sheets are rounded at the top only — the bottom is the screen edge.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// One button silhouette across the whole app.
///
/// Buttons are pills everywhere — sign-in, sign-up, "Continue with Google",
/// "Book". A screen that rounds its buttons differently to its neighbour reads
/// as a different app, so this lives in the theme and is never overridden
/// locally.
const StadiumBorder kButtonShape = StadiumBorder();

/// Motion reports state: focus, loading, validation, disclosure, navigation.
/// Nothing here exists to be watched.
///
/// Every duration is read through `context.motion(...)`, which collapses it to
/// zero when the patient has asked for reduced motion.
abstract final class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 260);

  /// Long enough to read as one continuous surface moving, short enough that
  /// nobody waits for it. Sheets and page transitions only.
  static const Duration page = Duration(milliseconds: 320);

  /// ease-out-quart. Fast departure, soft landing, no overshoot.
  static const Curve easeOut = Cubic(0.165, 0.84, 0.44, 1);

  /// For something entering under its own weight: a sheet rising.
  static const Curve enter = Cubic(0.2, 0.9, 0.25, 1);

  /// Leaving is quicker than arriving — nobody watches a thing depart.
  static const Curve exit = Cubic(0.4, 0, 1, 1);
}

abstract final class Layout {
  const Layout._();

  /// Above this width the artwork earns a full-bleed panel beside the form.
  /// Below it, the form takes the screen and the artwork becomes a header.
  static const double splitBreakpoint = 840;

  /// Where a phone layout becomes a tablet layout: two columns, wider gutters.
  static const double tabletBreakpoint = 600;

  /// Measure for a form column. Wider than this and labels drift away from
  /// their fields.
  static const double formMaxWidth = 452;

  /// Measure for reading: a consent screen, a doctor's bio, a result note.
  static const double proseMaxWidth = 620;

  /// Minimum comfortable touch target. Enforced, not aspired to.
  static const double minTapTarget = 48;

  /// The primary action is taller than the minimum: it is the thing on the
  /// screen the patient came to press.
  static const double primaryButtonHeight = 52;

  static const double focusRingWidth = 2;
}

/// Icons are sized from this scale, never from a literal.
abstract final class IconSize {
  const IconSize._();

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

/// Avatars and portraits.
abstract final class AvatarSize {
  const AvatarSize._();

  static const double sm = 32;
  static const double md = 44;
  static const double lg = 64;
  static const double xl = 104;
}
