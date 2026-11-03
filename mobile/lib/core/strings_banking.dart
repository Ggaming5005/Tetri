abstract final class BankingStrings {
  static const home = 'Home';
  static const payments = 'Payments';
  static const sendMoney = 'Send money';
  static const sendMoneyDescription = 'To another Tetri account.';
  static const convertCurrencies = 'Convert currencies';
  static const convertCurrenciesDescription =
      'Between your GEL, USD and EUR accounts.';
  static const activity = 'Activity';
  static const settings = 'Settings';
  static const back = 'Back';
  static const retry = 'Retry';
  static const seeAll = 'See all';
  static const send = 'Send';
  static const convert = 'Convert';
  static const totalBalance = 'Total balance in GEL';
  static const totalUnavailable = 'Rates unavailable';
  static const rateDate = 'Official rate date';
  static const accounts = 'Accounts';
  static const noAccounts =
      'Your accounts are not ready yet. Refresh to try again.';
  static const recentActivity = 'Recent activity';
  static const noActivity = 'Your activity will appear here.';
  static const cannotLoad =
      "Can't reach Tetri. Check your connection and try again.";
  static const loadMore = 'Load more';
  static const all = 'All';
  static const sent = 'Sent';
  static const received = 'Received';
  static const conversions = 'Conversions';
  static const account = 'Account';
  static const transaction = 'Transaction';
  static const starterGrant = 'Starter balance';
  static const transfer = 'Transfer';
  static const conversion = 'Conversion';
  static const posted = 'Posted';
  static const status = 'Status';
  static const date = 'Date and time';
  static const reference = 'Reference';
  static const copyReference = 'Copy reference';
  static const referenceCopied = 'Reference copied';
  static const from = 'From';
  static const to = 'To';
  static const amount = 'Amount';
  static const rate = 'Rate';
  static const fee = 'Fee';
  static const today = 'Today';
  static const yesterday = 'Yesterday';
  static const profile = 'Profile';
  static const biometricUnlock = 'Biometric unlock';
  static const biometricDescription =
      'Unlock Tetri with your fingerprint or face.';
  static const biometricUnavailable =
      'Biometric unlock is unavailable. Check your device settings and try again.';
  static const theme = 'Appearance';
  static const system = 'System';
  static const light = 'Light';
  static const dark = 'Dark';
  static const about = 'About';
  static const version = 'Version 1.0.0';
  static const sandbox = 'Sandbox, no real money';
  static const repository = 'View on GitHub';
  static const repositoryUnavailable = 'The link could not open. Try again.';
  static const signOut = 'Sign out';
  static const signOutFailed =
      'Sign out could not finish. Check your connection and try again.';
  static String greeting(String firstName) => 'Hello, $firstName';
  static String toRecipient(String name) => 'To $name';
  static String fromRecipient(String name) => 'From $name';
}
