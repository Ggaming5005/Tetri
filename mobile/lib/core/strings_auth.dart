abstract final class AuthStrings {
  static const createAccount = 'Create account';
  static const signIn = 'Sign in';
  static const back = 'Back';
  static const welcomeBack = 'Welcome back';
  static const signInHint = 'Your money, right where you left it.';
  static const name = 'Your name';
  static const nameHint = 'Giorgi Maisuradze';
  static const handle = 'Choose a handle';
  static const handleHelp = 'People use this to send you money.';
  static const emailTitle = 'First, your email';
  static const nameTitle = 'What should we call you?';
  static const handleTitle = 'Make it yours';
  static const passwordTitle = 'Keep it safe';
  static const passwordHelp = 'Use at least 10 characters.';
  static const nameRequired = 'Enter your name to continue.';
  static const handleInvalid =
      'Use 3–24 letters, numbers or underscores after @.';
  static const handleTaken = 'That handle is taken. Choose another one.';
  static const handleAvailable = 'That handle is available.';
  static const checkingHandle = 'Checking your handle';
  static const emailTaken =
      'That email already has an account. Sign in instead.';
  static const invalidCredentials =
      'Check your email and password, then try again.';
  static const tooManyRequests =
      'A few too many attempts. Wait a minute, then retry.';
  static const sessionEnded = 'Your session ended. Sign in to continue.';
  static const unlockTitle = 'Welcome back';
  static const unlockHint = 'Unlock Tetri to see your accounts.';
  static const unlock = 'Unlock';
  static const unlockCancelled =
      'Unlock was cancelled. Tap Unlock to try again.';
  static const biometricTitle = 'A quicker way in';
  static const biometricHint =
      'Use your fingerprint or face to unlock Tetri on this phone.';
  static const enableBiometrics = 'Enable biometric unlock';
  static const notNow = 'Not now';
  static const restoring = 'Opening Tetri';
  static String step(int current, int total) => 'Step $current of $total';
}
