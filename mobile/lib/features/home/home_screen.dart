import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/providers.dart';
import '../../core/strings_banking.dart';
import '../../design/components/amount_text.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/content.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';
import '../activity/transaction_presentation.dart';
import 'banking_providers.dart';
import 'gel_total.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _currency = 'GEL';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final accounts = ref.watch(accountsProvider);
    final rates = ref.watch(ratesProvider);
    final recent = ref.watch(recentTransactionsProvider);
    Widget content;
    if (profile.isLoading || accounts.isLoading) {
      content = const LoadingList();
    } else if (profile.hasError || accounts.hasError) {
      content = PageMessage(
        message: BankingStrings.cannotLoad,
        actionLabel: BankingStrings.retry,
        onAction: () => refreshBankViews(ref),
      );
    } else if (accounts.requireValue.isEmpty) {
      content = PageMessage(
        icon: PhosphorIconsRegular.wallet,
        message: BankingStrings.noAccounts,
        actionLabel: BankingStrings.retry,
        onAction: () => refreshBankViews(ref),
      );
    } else {
      final list = accounts.requireValue;
      final total = rates.hasValue
          ? totalInGel(list, rates.requireValue)
          : null;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TetriText(
            BankingStrings.totalBalance,
            style: TetriTextStyle.label,
            secondary: true,
          ),
          const SizedBox(height: TetriSpace.x8),
          if (rates.isLoading)
            const Skeleton(height: TetriSizes.button56)
          else if (total != null)
            AmountText(total, size: AmountSize.display)
          else ...[
            SectionHeading(
              title: BankingStrings.totalUnavailable,
              actionLabel: BankingStrings.retry,
              onAction: () => ref.invalidate(ratesProvider),
            ),
          ],
          const SizedBox(height: TetriSpace.x32),
          AccountPager(
            accounts: list,
            onPageChanged: (account) =>
                setState(() => _currency = account.currency),
            onSelected: (account) => context.push('/accounts/${account.id}'),
          ),
          const SizedBox(height: TetriSpace.x24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundAction(
                icon: PhosphorIconsRegular.arrowUpRight,
                label: BankingStrings.send,
                onTap: () => context.push('/send?currency=$_currency'),
              ),
              const SizedBox(width: TetriSpace.x48),
              RoundAction(
                icon: PhosphorIconsRegular.arrowsLeftRight,
                label: BankingStrings.convert,
                onTap: () => context.push('/convert?currency=$_currency'),
              ),
            ],
          ),
          const SizedBox(height: TetriSpace.x32),
          SectionHeading(
            title: BankingStrings.recentActivity,
            actionLabel: BankingStrings.seeAll,
            onAction: () => context.go('/activity'),
          ),
          recent.when(
            loading: () => const LoadingList(),
            error: (error, stack) => PageMessage(
              message: BankingStrings.cannotLoad,
              actionLabel: BankingStrings.retry,
              onAction: () => ref.invalidate(recentTransactionsProvider),
            ),
            data: (page) => page.items.isEmpty
                ? const PageMessage(
                    icon: PhosphorIconsRegular.receipt,
                    message: BankingStrings.noActivity,
                  )
                : TransactionGroups(
                    transactions: page.items.take(5).toList(),
                    onTap: (transaction) =>
                        context.push('/transactions/${transaction.id}'),
                  ),
          ),
        ],
      );
    }
    return TetriScaffold(
      bottomNavigationBar: const TetriNavigation(selectedIndex: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeading(
            title: profile.hasValue
                ? BankingStrings.greeting(
                    profile.requireValue.displayName
                        .trim()
                        .split(RegExp(r'\s+'))
                        .first,
                  )
                : BankingStrings.home,
            userId: profile.value?.id,
            name: profile.value?.displayName,
            onProfile: () => context.push('/settings'),
          ),
          const SizedBox(height: TetriSpace.x24),
          content,
        ],
      ),
    );
  }
}
