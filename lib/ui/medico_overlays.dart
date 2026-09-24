import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'medico_button.dart';

/// A bottom sheet.
///
/// Sheets are for a choice or a short form that belongs to the screen
/// underneath — picking a time, filtering a list. Anything the patient has to
/// read carefully gets its own screen, because a sheet can be dismissed by an
/// accidental swipe and a screen cannot.
Future<T?> showMedicoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,

  /// Set false when leaving without choosing would lose the patient's work.
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    builder: (context) {
      final child = Padding(
        // The keyboard is part of the layout, not something to be covered by.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            0,
            Insets.gutter,
            Insets.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleLarge),
                ),
                const SizedBox(height: Insets.md),
              ],
              Flexible(child: builder(context)),
            ],
          ),
        ),
      );

      return SafeArea(top: false, child: child);
    },
  );
}

/// A confirmation.
///
/// Reserved for something the patient cannot undo — cancelling an appointment,
/// deleting a record. Everything else either just happens, or happens with an
/// undo in a snackbar.
///
/// The destructive action is never the one under the thumb by default, and it
/// is named for what it does ("Cancel appointment"), never "OK" — a dialog
/// about cancelling an appointment with "Cancel" and "OK" buttons is a trap.
Future<bool> showMedicoConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        Insets.md,
        0,
        Insets.md,
        Insets.md,
      ),
      actions: [
        MedicoButton.quiet(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
          size: MedicoButtonSize.medium,
        ),
        MedicoButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
          variant: destructive
              ? MedicoButtonVariant.danger
              : MedicoButtonVariant.primary,
          size: MedicoButtonSize.medium,
          expand: false,
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A snackbar.
///
/// Only ever for something that has already succeeded and needs no action —
/// or for an undo. If the patient has to do something about it, it belongs in
/// a [MedicoBanner] on the screen, where it will still be there when they look
/// up.
void showMedicoSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // Long enough to read a sentence at an unhurried pace.
        duration: const Duration(seconds: 5),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}
