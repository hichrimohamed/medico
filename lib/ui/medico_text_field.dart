import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// A labelled field.
///
/// The label sits above the input rather than floating inside it. A floating
/// label is a nice trick and three separate problems: it collides with a long
/// hint, it collapses into illegibility at 200% text scale, and it leaves the
/// screen reader without a stable name for the control.
class MedicoTextField extends StatefulWidget {
  const MedicoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.focusNode,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.obscurable = false,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.helper,
    this.trailing,
    this.prefixIcon,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;

  /// Always pass these. Platform autofill and password managers are the
  /// fastest path off this screen, and the screen exists to be left.
  final Iterable<String>? autofillHints;

  final FormFieldValidator<String>? validator;

  /// Renders a password field with a show/hide control.
  final bool obscurable;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// Guidance shown under the field *before* anything has gone wrong — the
  /// password rules, the format of an insurance number.
  final String? helper;

  /// Sits opposite the label, where a "Forgot password?" link belongs: next to
  /// the thing it is about.
  final Widget? trailing;

  final IconData? prefixIcon;
  final int maxLines;

  @override
  State<MedicoTextField> createState() => _MedicoTextFieldState();
}

class _MedicoTextFieldState extends State<MedicoTextField> {
  late bool _obscured = widget.obscurable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: at 200% text scale a Row squeezes the label until it
        // breaks mid-word ("Pass / word"). This drops the trailing link to its
        // own line instead.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Insets.xs,
          children: [
            ExcludeSemantics(
              child: Text(
                widget.label,
                style: text.labelMedium?.copyWith(
                  color: widget.enabled ? c.inkBody : c.inkDisabled,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        SizedBox(height: widget.trailing == null ? Insets.xs : Insets.xxs),
        Semantics(
          label: widget.label,
          textField: true,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.enabled ? widget.autofillHints : null,
            autocorrect: !widget.obscurable,
            enableSuggestions: !widget.obscurable,
            validator: widget.validator,
            onFieldSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            maxLines: widget.obscurable ? 1 : widget.maxLines,
            style: text.bodyLarge?.copyWith(
              color: widget.enabled ? c.ink : c.inkDisabled,
            ),
            cursorColor: c.focus,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              helperMaxLines: 2,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, size: IconSize.md),
              prefixIconColor: c.inkMuted,
              suffixIcon: widget.obscurable ? _visibilityToggle(context) : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _visibilityToggle(BuildContext context) {
    final showing = !_obscured;
    return IconButton(
      onPressed: widget.enabled
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _obscured = !_obscured);
            }
          : null,
      tooltip: showing ? 'Hide password' : 'Show password',
      icon: AnimatedSwitcher(
        duration: context.motion(Motion.fast),
        child: Icon(
          showing ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key: ValueKey<bool>(showing),
          size: 22,
        ),
      ),
    );
  }
}

/// A checkbox with a label that is itself part of the target.
///
/// A 20pt checkbox is not a 48pt target, and a label you cannot tap is a label
/// that will be missed. The whole row toggles.
class MedicoCheckboxField extends StatelessWidget {
  const MedicoCheckboxField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.description,
    this.error,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final String? description;

  /// Shown under the row, in the danger tone, with an icon. A checkbox is a
  /// common place to fail validation silently — this stops that.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          enabled: enabled,
          label: description == null ? label : '$label. $description',
          excludeSemantics: true,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            borderRadius: Radii.smAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Layout.minTapTarget - Insets.md,
                    height: Layout.minTapTarget - Insets.md,
                    child: Checkbox(
                      value: value,
                      onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                      isError: error != null,
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.xxs),
                          child: Text(
                            label,
                            style: context.text.bodyMedium?.copyWith(
                              color: enabled ? c.inkBody : c.inkDisabled,
                            ),
                          ),
                        ),
                        if (description != null)
                          Text(description!, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: IconSize.sm,
                  color: c.danger.ink,
                ),
                const SizedBox(width: Insets.xxs),
                Expanded(
                  child: Text(
                    error!,
                    style: context.text.bodySmall?.copyWith(color: c.danger.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
