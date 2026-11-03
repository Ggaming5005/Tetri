import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/strings_banking.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/buttons.dart';
import '../../design/components/inline_banner.dart';
import '../../design/components/skeleton.dart';
import '../../design/tokens.dart';
import 'history_controller.dart';
import 'transaction_presentation.dart';

class HistoryContent extends StatelessWidget {
  const HistoryContent({super.key, required this.controller});
  final HistoryController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.loading) return const LoadingList();
    if (controller.error != null && controller.items.isEmpty) {
      return PageMessage(
        message: BankingStrings.cannotLoad,
        actionLabel: BankingStrings.retry,
        onAction: controller.refresh,
      );
    }
    if (controller.items.isEmpty) {
      return const PageMessage(
        icon: PhosphorIconsRegular.receipt,
        message: BankingStrings.noActivity,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransactionGroups(
          transactions: controller.items,
          onTap: (transaction) =>
              context.push('/transactions/${transaction.id}'),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: TetriSpace.x16),
          const InlineBanner(message: BankingStrings.cannotLoad),
          TetriTextButton(
            label: BankingStrings.retry,
            onPressed: controller.loadMore,
          ),
        ] else if (controller.loadingMore)
          const Skeleton(height: TetriSizes.listRow64)
        else if (controller.nextCursor != null)
          TetriTextButton(
            label: BankingStrings.loadMore,
            onPressed: controller.loadMore,
          ),
      ],
    );
  }
}
