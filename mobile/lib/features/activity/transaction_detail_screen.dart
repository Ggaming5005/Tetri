import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings_banking.dart';
import '../../design/components/amount_text.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';
import '../home/banking_providers.dart';
import 'transaction_presentation.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});
  final String transactionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(transactionProvider(transactionId));
    return TetriScaffold(
      bottomNavigationBar: const TetriNavigation(selectedIndex: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrowseBackButton(),
          detail.when(
            loading: () => const LoadingList(),
            error: (error, stack) => PageMessage(
              message: BankingStrings.cannotLoad,
              actionLabel: BankingStrings.retry,
              onAction: () =>
                  ref.invalidate(transactionProvider(transactionId)),
            ),
            data: (transaction) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeading(title: transactionTitle(transaction)),
                const SizedBox(height: TetriSpace.x24),
                AmountText(
                  transactionAmount(transaction),
                  size: AmountSize.title,
                  showSign: true,
                ),
                const SizedBox(height: TetriSpace.x24),
                DetailLine(
                  label: BankingStrings.status,
                  value: transaction.status == 'posted'
                      ? BankingStrings.posted
                      : transaction.status,
                ),
                if (transaction.counterparty != null)
                  DetailLine(
                    label: transactionAmount(transaction).minor < 0
                        ? BankingStrings.to
                        : BankingStrings.from,
                    value:
                        '${transaction.counterparty!.displayName}\n${transaction.counterparty!.handle}',
                  ),
                DetailLine(
                  label: BankingStrings.date,
                  value: transactionDate(transaction.createdAt),
                ),
                if (transaction.kind == 'conversion') ...[
                  for (final entry in transaction.entries)
                    DetailLine(
                      label: entry.amount.currency,
                      trailing: AmountText(
                        entry.amount,
                        showSign: true,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  if (transaction.rate != null)
                    DetailLine(
                      label: BankingStrings.rate,
                      value: transaction.rate,
                    ),
                  if (transaction.fee != null)
                    DetailLine(
                      label: BankingStrings.fee,
                      trailing: AmountText(
                        transaction.fee!,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
                const SizedBox(height: TetriSpace.x16),
                ReferenceCopy(reference: transaction.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
