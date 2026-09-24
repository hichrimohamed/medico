/// Validation messages are written the way a receptionist would say them:
/// what is wrong, and what to do about it. Never "Invalid input".
abstract final class Validators {
  const Validators._();

  // Deliberately permissive. Address syntax is not the place to be clever —
  // the only authority on whether an address works is the mail that reaches it.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Enter the email address you use for Medico.';
    if (!_email.hasMatch(input)) {
      return 'That does not look like an email address. Check for a typo.';
    }
    return null;
  }

  /// Sign-in only checks presence. An existing password that predates a rule
  /// change is still the patient's password; refusing to send it locks them
  /// out of their own account.
  static String? currentPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  static String? newPassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Choose a password.';
    if (input.length < 8) {
      return 'Use at least 8 characters. Longer is safer than complicated.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Enter your full name as it appears on your file.';
    if (input.length < 2) return 'That name looks too short. Check for a typo.';
    return null;
  }
}
