import 'package:flutter/material.dart';

/// Reduced motion is not a toggle we support grudgingly — every animated value
/// in the app reads its duration through here, so "reduce motion" degrades to
/// an instant, correct state change rather than a broken one.
extension ReducedMotion on BuildContext {
  Duration motion(Duration duration) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : duration;

  bool get prefersReducedMotion => MediaQuery.disableAnimationsOf(this);
}
