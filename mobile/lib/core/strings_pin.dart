abstract final class PinStrings {
  static const invalidFormat = 'Enter your four-digit PIN.';
  static const incorrect = 'That PIN is not right. Try again.';
  static const cooldown = 'Too many attempts. Wait before trying again.';
  static const attemptLimit =
      'PIN unlock is paused. Use your fingerprint or sign in again.';
  static const unavailable =
      'PIN unlock is unavailable. Try again or sign in again.';
  static const storageUnavailable =
      'Cannot access your saved PIN. Try again or sign in again.';
  static const corruptRecord =
      'Your saved PIN cannot be read. Sign in again to set a new PIN.';
  static const notConfigured = 'No PIN is saved. Sign in again to continue.';
  static const clockChanged =
      'Your phone time has changed. Restore the correct time or sign in again.';
}
