import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../shared/announce.dart';
import '../../../shared/validators.dart';
import '../../../ui/ui.dart';
import '../data/auth_service.dart';
import 'widgets/auth_layout.dart';

/// Nobody wants to be on this screen. It is built to be finished quickly:
/// autofill wired up, the keyboard carrying the patient from field to submit,
/// and every failure answered with the thing to do next.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  /// Injected by tests. In the app it comes from [AppScope], so a screen
  /// pushed by name still reaches the real backend.
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthService get _auth => widget.authService ?? AppScope.of(context).auth;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _keepSignedIn = true;
  bool _submitting = false;
  SsoProvider? _ssoInFlight;
  AuthException? _failure;

  bool get _busy => _submitting || _ssoInFlight != null;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      // Once the patient has been told what is wrong, keep telling them as
      // they fix it rather than waiting for another failed submit.
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    try {
      await _auth.signIn(
        email: _email.text.trim(),
        password: _password.text,
        remember: _keepSignedIn,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = error;
      });
      context.announce(error.message, urgent: true);
    } catch (_) {
      if (!mounted) return;
      const fallback = AuthException(
        AuthFailure.unknown,
        'Something went wrong at our end. Try again in a moment.',
      );
      setState(() {
        _submitting = false;
        _failure = fallback;
      });
      context.announce(fallback.message, urgent: true);
    }
  }

  Future<void> _continueWith(SsoProvider provider) async {
    setState(() {
      _ssoInFlight = provider;
      _failure = null;
    });
    try {
      await _auth.signInWithProvider(provider);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _ssoInFlight = null;
        _failure = error;
      });
      context.announce(error.message, urgent: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ssoInFlight = null;
        _failure = AuthException(
          AuthFailure.unknown,
          "We couldn't finish signing in with ${provider.label}. "
          'Try again, or use your email and password.',
        );
      });
    }
  }

  void _resetPassword() {
    Navigator.of(context).pushNamed(
      AppRoutes.forgotPassword,
      arguments: _email.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: AuthLayout(
        showArtwork: false,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(),
                const SizedBox(height: Insets.xxl),
                Semantics(
                  header: true,
                  child: Text(
                    'Welcome back',
                    style: context.text.headlineMedium,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Sign in to manage your care with Medico.',
                  style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: Insets.xl + Insets.xxs),

                MedicoBannerSlot(
                  child: _failure == null
                      ? null
                      : MedicoBanner(
                          key: ValueKey<String>(_failure!.message),
                          message: _failure!.message,
                          action: _failure!.kind == AuthFailure.accountLocked
                              ? 'Reset password'
                              : null,
                          onAction: _failure!.kind == AuthFailure.accountLocked
                              ? _resetPassword
                              : null,
                        ),
                ),

                MedicoTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: Insets.md + 2),

                MedicoTextField(
                  label: 'Password',
                  trailing: TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.xs,
                        vertical: Insets.xxs,
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !_busy,
                  obscurable: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.currentPassword,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: Insets.sm),

                // Defaults to on: a patient checking a result should not be
                // retyping a password every time.
                MedicoCheckboxField(
                  value: _keepSignedIn,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _keepSignedIn = value),
                  label: 'Keep me signed in',
                ),
                const SizedBox(height: Insets.lg),

                MedicoButton(
                  label: 'Sign in',
                  busyLabel: 'Signing in',
                  busy: _submitting,
                  onPressed: _busy ? null : _signIn,
                ),
                const SizedBox(height: Insets.xl),

                const LabelledDivider(label: 'or continue with'),
                const SizedBox(height: Insets.md),

                SsoButton(
                  provider: SsoProvider.google,
                  busy: _ssoInFlight == SsoProvider.google,
                  onPressed: _busy ? null : () => _continueWith(SsoProvider.google),
                ),
                const SizedBox(height: Insets.sm),
                SsoButton(
                  provider: SsoProvider.apple,
                  busy: _ssoInFlight == SsoProvider.apple,
                  onPressed: _busy ? null : () => _continueWith(SsoProvider.apple),
                ),
                const SizedBox(height: Insets.xl + Insets.xxs),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New to Medico?',
                        style: context.text.bodyMedium?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                      const SizedBox(width: Insets.xxs),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context)
                                .pushNamed(AppRoutes.signUp),
                        child: const Text('Create an account'),
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
}
