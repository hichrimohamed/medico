import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/validators.dart';
import '../../../../ui/ui.dart';
import '../../data/profile.dart';
import '../../data/profile_repository.dart';

/// Renaming. Returns the updated profile, or null if nothing changed.
Future<Profile?> showEditNameSheet({
  required BuildContext context,
  required ProfileRepository profile,
  required String currentName,
}) {
  return showMedicoSheet<Profile>(
    context: context,
    title: 'Your name',
    dismissible: false,
    builder: (context) => _EditNameForm(
      profile: profile,
      currentName: currentName,
    ),
  );
}

class _EditNameForm extends StatefulWidget {
  const _EditNameForm({required this.profile, required this.currentName});

  final ProfileRepository profile;
  final String currentName;

  @override
  State<_EditNameForm> createState() => _EditNameFormState();
}

class _EditNameFormState extends State<_EditNameForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.currentName);

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _saving = false;
  String? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final updated = await widget.profile.rename(_name.text);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicoBannerSlot(
              child: _failure == null
                  ? null
                  : MedicoBanner(
                      key: ValueKey<String>(_failure!),
                      message: _failure!,
                    ),
            ),
            MedicoTextField(
              label: 'Full name',
              hint: 'As it appears on your medical file',
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.name],
              validator: Validators.fullName,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Insets.lg),
            MedicoButton(
              label: 'Save',
              busyLabel: 'Saving',
              busy: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: Insets.xs),
            MedicoButton.quiet(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Changing the password. Returns true when it changed.
Future<bool?> showChangePasswordSheet({
  required BuildContext context,
  required ProfileRepository profile,
}) {
  return showMedicoSheet<bool>(
    context: context,
    title: 'Change password',
    dismissible: false,
    builder: (context) => _ChangePasswordForm(profile: profile),
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.profile});

  final ProfileRepository profile;

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _saving = false;
  String? _failure;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.profile.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicoBannerSlot(
              child: _failure == null
                  ? null
                  : MedicoBanner(
                      key: ValueKey<String>(_failure!),
                      message: _failure!,
                    ),
            ),
            MedicoTextField(
              label: 'Current password',
              controller: _current,
              enabled: !_saving,
              obscurable: true,
              autofillHints: const [AutofillHints.password],
              validator: Validators.currentPassword,
            ),
            const SizedBox(height: Insets.md),
            MedicoTextField(
              label: 'New password',
              controller: _next,
              enabled: !_saving,
              obscurable: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Changing your password signs you out everywhere else. You will '
              'stay signed in on this phone.',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.inkMuted,
              ),
            ),
            const SizedBox(height: Insets.lg),
            MedicoButton(
              label: 'Change password',
              busyLabel: 'Changing',
              busy: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: Insets.xs),
            MedicoButton.quiet(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Deleting the account. Returns true once it is gone.
///
/// The one irreversible thing in the app, so it is the one place that asks for
/// the password again: a phone is unlocked and in somebody else's hand often
/// enough. It spells out what goes before it asks, because "are you sure?" is
/// not a description of consequences.
Future<bool?> showDeleteAccountSheet({
  required BuildContext context,
  required ProfileRepository profile,
  required Profile current,
}) {
  return showMedicoSheet<bool>(
    context: context,
    title: 'Delete your account',
    dismissible: false,
    builder: (context) => _DeleteAccountForm(
      profile: profile,
      current: current,
    ),
  );
}

class _DeleteAccountForm extends StatefulWidget {
  const _DeleteAccountForm({required this.profile, required this.current});

  final ProfileRepository profile;
  final Profile current;

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _deleting = false;
  String? _failure;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _deleting = true;
      _failure = null;
    });
    try {
      await widget.profile.deleteAccount(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _failure = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = widget.current;

    // Only the things they actually have. Telling a patient with no
    // appointments that their appointments will be deleted is noise, and noise
    // is what gets skimmed past on the screen where skimming costs most.
    final losses = <String>[
      if (current.upcomingAppointments > 0)
        current.upcomingAppointments == 1
            ? 'your upcoming appointment, which goes back to the clinic'
            : 'your ${current.upcomingAppointments} upcoming appointments, '
                'which go back to the clinic',
      'your messages with the clinic',
      if (current.savedDoctors > 0) 'your saved doctors',
      'your appointment history',
    ];

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicoBannerSlot(
              child: _failure == null
                  ? null
                  : MedicoBanner(
                      key: ValueKey<String>(_failure!),
                      message: _failure!,
                    ),
            ),
            Text(
              'This cannot be undone. Deleting ${current.email} removes:',
              style: context.text.bodyLarge,
            ),
            const SizedBox(height: Insets.sm),
            for (final loss in losses)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: Insets.xs),
                      child: Icon(
                        Icons.remove_rounded,
                        size: IconSize.sm,
                        color: c.danger.solid,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        loss,
                        style: context.text.bodyMedium
                            ?.copyWith(color: c.inkBody),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.md),
            Text(
              'If you only want to stop using Medico for now, sign out '
              'instead — your records stay where they are.',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Insets.lg),
            MedicoTextField(
              label: 'Confirm your password',
              controller: _password,
              enabled: !_deleting,
              obscurable: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: Validators.currentPassword,
              onSubmitted: (_) => _delete(),
            ),
            const SizedBox(height: Insets.lg),
            MedicoButton.danger(
              label: 'Delete my account',
              busyLabel: 'Deleting',
              busy: _deleting,
              onPressed: _deleting ? null : _delete,
            ),
            const SizedBox(height: Insets.xs),
            // The way out is the one under the thumb, and it is named for what
            // it does.
            MedicoButton.quiet(
              label: 'Keep my account',
              onPressed: _deleting ? null : () => Navigator.of(context).pop(),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
