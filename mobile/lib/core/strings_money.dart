import 'package:intl/intl.dart';

abstract final class MoneyStrings {
  static const send = 'Send money';
  static const convert = 'Convert';
  static const back = 'Back';
  static const done = 'Done';
  static const retry = 'Retry';
  static const continueLabel = 'Continue';
  static const recipientTitle = 'Who are you sending to?';
  static const recipientHint = 'Enter their Tetri handle.';
  static const searchLabel = 'Find a recipient';
  static const searchHint = '@nino';
  static const recent = 'Recent recipients';
  static const searchEmpty = 'Enter a handle to find someone on Tetri.';
  static const recipientNotFound =
      'No one with that handle. Check it and try again.';
  static const recipientsUnavailable =
      'Recent recipients are unavailable. Search by handle or try again.';
  static const amountTitle = 'How much?';
  static const available = 'Available balance';
  static const noAccounts = 'Your accounts are not ready yet. Try again.';
  static const accountsUnavailable =
      "Can't load your accounts. Check your connection and try again.";
  static const reviewSend = 'Review transfer';
  static const reviewConversion = 'Review conversion';
  static const sendConfirm = 'Send money';
  static const convertConfirm = 'Convert money';
  static const editAmount = 'Edit amount';
  static const sent = 'Sent';
  static const converted = 'Converted';
  static const notSent = 'Money was not sent';
  static const notConverted = 'Money was not converted';
  static const checking = 'Check the result';
  static const checkActivity = 'Check activity';
  static const confirmationExpired =
      'This confirmation is too old to retry safely. Check your activity before starting another payment.';
  static const uncertain =
      "We couldn't confirm the result yet. Retry to check this same payment.";
  static const genericFailure = 'Check the details and try again.';
  static const from = 'From';
  static const to = 'To';
  static const amount = 'Amount';
  static const amountPlaceholder = '0.00';
  static const youSend = 'You send';
  static const fee = 'Fee';
  static const total = 'Total';
  static const rate = 'Exchange rate';
  static const rateDate = 'Official rate date';
  static const youGet = 'You get';
  static const convertTitle = 'A clear rate. No surprises.';
  static const convertHint = 'Choose your accounts and enter an amount.';
  static const quoteEmpty = 'Enter an amount to see the rate and fee.';
  static const quoteUnavailable =
      "Can't get a quote. Check your connection and try again.";
  static const quoteRefreshed =
      'The quote expired. Review these refreshed terms before confirming.';
  static const requestNewQuote = 'Get a new quote';
  static const chooseDifferent = 'Choose different currencies to convert.';
  static String notEnough(String currency) =>
      'Not enough money in your $currency account. Enter a smaller amount.';
  static String recipient(String displayName) => 'To $displayName';
  static String rateText(String from, String rate, String to) =>
      '1 $from = $rate $to';
  static String dateText(DateTime date) =>
      DateFormat('d MMM yyyy', 'en_US').format(date);
}
