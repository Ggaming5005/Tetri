abstract final class TetriStrings {
  static const appName = 'Tetri';
  static const tagline = 'Simple money, done right.';
  static const sandbox = 'Sandbox, no real money';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const loading = 'Loading';
  static const chooseAccount = 'Choose an account';
  static const confirm = 'Confirm';
  static const review = 'Review';
  static const availableBalance = 'Available balance';
  static const amountKeypad = 'Amount keypad';
  static const decimalPoint = 'Decimal point';
  static const deleteDigit = 'Delete last digit';
  static const gelName = 'Georgian lari';
  static const usdName = 'US dollar';
  static const eurName = 'Euro';
  static const currencyNames = {'GEL': gelName, 'USD': usdName, 'EUR': eurName};
  static String currencyName(String currency) =>
      currencyNames[currency] ?? currency;

  static const gallery = 'Components';
  static const galleryIntroduction =
      'The details that make Tetri feel like Tetri.';
  static const system = 'System';
  static const light = 'Light';
  static const dark = 'Dark';
  static const typography = 'Type and money';
  static const accounts = 'Accounts';
  static const transactions = 'Activity';
  static const controls = 'Actions and inputs';
  static const feedback = 'Feedback';
  static const preferences = 'Preferences';
  static const sendMoney = 'Send money';
  static const continueLabel = 'Continue';
  static const cancel = 'Cancel';
  static const retry = 'Retry';
  static const done = 'Done';
  static const email = 'Email';
  static const emailHint = 'you@example.com';
  static const password = 'Password';
  static const passwordHint = 'At least 10 characters';
  static const search = 'Search by handle';
  static const handleHint = '@nino';
  static const invalidEmail = 'Enter a valid email address.';
  static const biometricUnlock = 'Biometric unlock';
  static const all = 'All';
  static const sent = 'Sent';
  static const received = 'Received';
  static const conversions = 'Conversions';
  static const noActivity = 'Your activity will appear here.';
  static const offline =
      "Can't reach Tetri. Check your connection and try again.";
  static const quoteRefreshed =
      'The rate was refreshed. Review it before confirming.';
  static const reviewTransfer = 'Review transfer';
  static const loadingReview = 'Review while confirming';
  static const disabledReview = 'Review with confirmation disabled';
  static const to = 'To';
  static const amount = 'Amount';
  static const fee = 'Fee';
  static const rate = 'Rate';
  static const total = 'Total';
  static const transferFailed = 'Money was not sent';
  static const tryAgain = 'Check your connection and try again.';
  static const demoNino = 'Nino K.';
  static const demoNinoHandle = '@nino';
  static const demoGiorgi = 'Giorgi M.';
  static const demoDate = 'Today, 14:05';
}
