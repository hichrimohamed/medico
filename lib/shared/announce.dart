import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Screen-reader announcements for things that change without focus moving —
/// a failed sign-in, a reset link on its way. Without these, a patient using
/// TalkBack or VoiceOver taps "Sign in" and hears nothing at all.
extension Announce on BuildContext {
  void announce(String message, {bool urgent = false}) {
    SemanticsService.sendAnnouncement(
      View.of(this),
      message,
      Directionality.of(this),
      assertiveness: urgent ? Assertiveness.assertive : Assertiveness.polite,
    );
  }
}
