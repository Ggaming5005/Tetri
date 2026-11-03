import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_models.dart';
import '../../core/providers.dart';

final profileProvider = FutureProvider.autoDispose<AuthUser>(
  (ref) => ref.watch(bankApiProvider).profile(),
);
final ratesProvider = FutureProvider.autoDispose<FxRates>(
  (ref) => ref.watch(bankApiProvider).rates(),
);
final recentTransactionsProvider = FutureProvider.autoDispose<TransactionPage>(
  (ref) => ref.watch(bankApiProvider).transactions(pageSize: 5),
);
final transactionProvider = FutureProvider.autoDispose
    .family<TransactionView, String>(
      (ref, id) => ref.watch(bankApiProvider).transaction(id),
    );

final bankViewRevisionProvider = NotifierProvider<BankViewRevision, int>(
  BankViewRevision.new,
);

class BankViewRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

void refreshBankViews(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(ratesProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(transactionProvider);
  ref.read(bankViewRevisionProvider.notifier).refresh();
}
