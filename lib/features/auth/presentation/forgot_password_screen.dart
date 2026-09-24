import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../shared/announce.dart';
import '../../../shared/validators.dart';
import '../../../ui/ui.dart';
import '../data/auth_service.dart';
import 'widgets/auth_layout.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.authService,
  });

  /// Carried over from the sign-in form so the patient never retypes it.
  final String? initialEmail;
  /// Injected by tests; [AppScope] supplies the real one.
  final AuthService? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  AuthService get _auth => widget.authService ?? AppScope.of(context).auth;

  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _submitting = false;
  bool _sent = false;
  AuthException? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    try {
      await _auth.sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = true;
      });
      context.announce('Reset link sent. Check your inbox.');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = error;
      });
      context.announce(error.message, urgent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: AuthLayout(
        heroHeadline: 'Locked out is temporary.',
        heroSupport: 'We will send a link that lets you set a new password. '
            'It expires in 30 minutes.',
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MedicoBackButton(label: 'Back to sign in'),
              const SizedBox(height: Insets.md),
              const BrandMark(),
              const SizedBox(height: Insets.xxl),
              Text(
                _sent ? 'Check your email' : 'Reset your password',
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                _sent
                    ? 'Follow the link in the email to set a new password. It '
                        'expires in 30 minutes.'
                    : 'Enter the email address on your Medico account and we '
                        'will send you a link to set a new password.',
                style: context.text.bodyLarge?.copyWith(
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(height: Insets.xl + Insets.xxs),

              MedicoBannerSlot(
                child: _failure == null
                    ? null
                    : MedicoBanner(
                        key: ValueKey<String>(_failure!.message),
                        message: _failure!.message,
                      ),
              ),

              if (_sent) ...[
                // Deliberately does not confirm whether an account exists —
                // that would let anyone test which patients are registered.
                MedicoBanner(
                  tone: MedicoBannerTone.success,
                  message: 'If there is a Medico account for '
                      '${_email.text.trim()}, the reset link is on its way. '
                      'Check your spam folder if it has not arrived in a few '
                      'minutes.',
                ),
                const SizedBox(height: Insets.lg),
                MedicoButton(
                  label: 'Back to sign in',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: Insets.sm),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _sent = false),
                    child: const Text('Use a different email'),
                  ),
                ),
              ] else ...[
                MedicoTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  enabled: !_submitting,
                  autofocus: widget.initialEmail?.isEmpty ?? true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Insets.lg),
                MedicoButton(
                  label: 'Send reset link',
                  busyLabel: 'Sending',
                  busy: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Still stuck? Call the clinic on 0800 555 100, '
                  'Monday to Friday, 8am to 6pm.',
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
