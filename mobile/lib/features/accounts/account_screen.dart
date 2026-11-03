import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/providers.dart';
import '../../core/strings_banking.dart';
import '../../design/browse_tokens.dart';
import '../../design/components/amount_text.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';
import '../activity/history_content.dart';
import '../activity/history_controller.dart';
import '../home/banking_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.accountId});
  final String accountId;
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late HistoryController _history;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _startHistory();
    _scroll.addListener(_loadNearEnd);
  }

  void _startHistory() {
    _history = HistoryController(
      ref.read(bankApiProvider),
      accountId: widget.accountId,
    );
    unawaited(_history.refresh());
  }

  @override
  void didUpdateWidget(AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _history.dispose();
      _startHistory();
    }
  }

  void _loadNearEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < TetriBrowseSizes.paginationThreshold &&
        _history.error == null) {
      unawaited(_history.loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    ref.listen(
      bankViewRevisionProvider,
      (previous, next) => unawaited(_history.refresh()),
    );
    return TetriScaffold(
      scrollController: _scroll,
      bottomNavigationBar: const TetriNavigation(selectedIndex: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrowseBackButton(),
          accounts.when(
            loading: () => const LoadingList(),
            error: (error, stack) => PageMessage(
              message: BankingStrings.cannotLoad,
              actionLabel: BankingStrings.retry,
              onAction: () => ref.invalidate(accountsProvider),
            ),
            data: (list) {
              final matches = list.where(
                (account) => account.id == widget.accountId,
              );
              if (matches.isEmpty) {
                return const PageMessage(
                  icon: PhosphorIconsRegular.wallet,
                  message: BankingStrings.noAccounts,
                );
              }
              final account = matches.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeading(
                    title:
                        '${account.currency} ${BankingStrings.account.toLowerCase()}',
                  ),
                  const SizedBox(height: TetriSpace.x16),
                  AmountText(account.balance, size: AmountSize.title),
                  const SizedBox(height: TetriSpace.x24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RoundAction(
                        icon: PhosphorIconsRegular.arrowUpRight,
                        label: BankingStrings.send,
                        onTap: () =>
                            context.push('/send?currency=${account.currency}'),
                      ),
                      const SizedBox(width: TetriSpace.x48),
                      RoundAction(
                        icon: PhosphorIconsRegular.arrowsLeftRight,
                        label: BankingStrings.convert,
                        onTap: () => context.push(
                          '/convert?currency=${account.currency}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TetriSpace.x32),
                  const SectionHeading(title: BankingStrings.activity),
                  ListenableBuilder(
                    listenable: _history,
                    builder: (context, child) =>
                        HistoryContent(controller: _history),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
