import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_models.dart';
import '../../core/money.dart';
import '../../core/strings_banking.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/transaction_row.dart';

String transactionTitle(TransactionView transaction) {
  if (transaction.kind == 'starter_grant') return BankingStrings.starterGrant;
  if (transaction.kind == 'conversion') return BankingStrings.conversion;
  final counterparty = transaction.counterparty;
  if (counterparty == null) return BankingStrings.transfer;
  return transactionAmount(transaction).minor < 0
      ? BankingStrings.toRecipient(counterparty.displayName)
      : BankingStrings.fromRecipient(counterparty.displayName);
}

Money transactionAmount(TransactionView transaction) => transaction.entries
    .firstWhere(
      (entry) => entry.amount.minor < 0,
      orElse: () => transaction.entries.first,
    )
    .amount;

String dayLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final date = DateTime(local.year, local.month, local.day);
  final current = DateTime(today.year, today.month, today.day);
  if (date == current) return BankingStrings.today;
  if (date == DateTime(today.year, today.month, today.day - 1)) {
    return BankingStrings.yesterday;
  }
  return DateFormat(
    local.year == today.year ? 'd MMM' : 'd MMM yyyy',
    'en_US',
  ).format(local);
}

String transactionDate(DateTime value) =>
    DateFormat('d MMM yyyy, HH:mm', 'en_US').format(value.toLocal());

class TransactionGroups extends StatelessWidget {
  const TransactionGroups({
    super.key,
    required this.transactions,
    required this.onTap,
    this.now,
  });
  final List<TransactionView> transactions;
  final ValueChanged<TransactionView> onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TransactionView>>{};
    for (final transaction in transactions) {
      groups
          .putIfAbsent(dayLabel(transaction.createdAt, now: now), () => [])
          .add(transaction);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries)
          DateSection(
            title: group.key,
            children: [
              for (final transaction in group.value)
                TransactionRow(
                  title: transactionTitle(transaction),
                  subtitle: DateFormat(
                    'HH:mm',
                    'en_US',
                  ).format(transaction.createdAt.toLocal()),
                  amount: transactionAmount(transaction),
                  onTap: () => onTap(transaction),
                ),
            ],
          ),
      ],
    );
  }
}
