import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../shared/announce.dart';
import '../../../shared/validators.dart';
import '../../../ui/ui.dart';
import '../data/auth_service.dart';
import 'widgets/auth_layout.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.authService});

  /// Injected by tests; [AppScope] supplies the real one.
  final AuthService? authService;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  AuthService get _auth => widget.authService ?? AppScope.of(context).auth;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _submitting = false;
  AuthException? _failure;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
      await _auth.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = error;
      });
      context.announce(error.message, urgent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = const AuthException(
          AuthFailure.unknown,
          'Something went wrong at our end. Try again in a moment.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: AuthLayout(
        heroHeadline: 'One account for every part of your care.',
        heroSupport: 'Appointments, prescriptions, test results and the notes '
            'from your last visit.',
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MedicoBackButton(),
                const SizedBox(height: Insets.md),
                const BrandMark(),
                const SizedBox(height: Insets.xxl),
                Text('Create your account', style: context.text.headlineMedium),
                const SizedBox(height: Insets.xs),
                Text(
                  'It takes a minute. You will need the email your clinic has '
                  'on file.',
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
                          action: 'Sign in instead',
                          onAction: () => Navigator.of(context).pop(),
                        ),
                ),

                MedicoTextField(
                  label: 'Full name',
                  hint: 'As it appears on your medical file',
                  controller: _name,
                  enabled: !_submitting,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: Insets.md + 2),

                MedicoTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  focusNode: _emailFocus,
                  enabled: !_submitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: Insets.md + 2),

                MedicoTextField(
                  label: 'Password',
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !_submitting,
                  obscurable: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                  helper: 'At least 8 characters. A short phrase works well.',
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Insets.lg),

                MedicoButton(
                  label: 'Create account',
                  busyLabel: 'Creating account',
                  busy: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: Insets.sm + 2),

                Text(
                  'By creating an account you agree to Medico handling your '
                  'health data under our privacy notice.',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Insets.xl),

                const LabelledDivider(label: 'or continue with'),
                const SizedBox(height: Insets.md),

                SsoButton(
                  provider: SsoProvider.google,
                  onPressed: _submitting ? null : () => _continueWith(SsoProvider.google),
                ),
                const SizedBox(height: Insets.sm),
                SsoButton(
                  provider: SsoProvider.apple,
                  onPressed: _submitting ? null : () => _continueWith(SsoProvider.apple),
                ),
                const SizedBox(height: Insets.xl),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: context.text.bodyMedium?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                      const SizedBox(width: Insets.xxs),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueWith(SsoProvider provider) async {
    await _auth.signInWithProvider(provider);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }
}

