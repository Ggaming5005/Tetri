import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/api_models.dart';
import '../../core/money.dart';
import '../../core/strings_money.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'avatar.dart';
import 'buttons.dart';
import 'inline_banner.dart';
import 'review_sheet.dart';

class FlowNavigation extends StatelessWidget {
  const FlowNavigation({super.key, required this.onBack});
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TetriTextButton(label: MoneyStrings.back, onPressed: onBack),
  );
}

class RecipientRow extends StatelessWidget {
  const RecipientRow({super.key, required this.recipient, required this.onTap});
  final RecipientView recipient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TetriRadii.r12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TetriSizes.listRow64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TetriSpace.x8),
            child: Row(
              children: [
                Avatar(userId: recipient.handle, name: recipient.displayName),
                const SizedBox(width: TetriSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient.displayName,
                        style: TetriTypography.title.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        recipient.handle,
                        style: TetriTypography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: TetriSizes.icon24,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MoneyEntrySummary extends StatelessWidget {
  const MoneyEntrySummary({
    super.key,
    required this.amount,
    required this.available,
    this.label,
  });
  final Money amount;
  final Money available;
  final String? label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null) ...[
        Text(
          label!,
          style: TetriTypography.body.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: TetriSpace.x12),
      ],
      AmountText(amount, size: AmountSize.title),
      const SizedBox(height: TetriSpace.x12),
      Wrap(
        spacing: TetriSpace.x8,
        runSpacing: TetriSpace.x4,
        children: [
          Text(
            MoneyStrings.available,
            style: TetriTypography.label.copyWith(
              color: TetriColors.of(context).textSecondary,
            ),
          ),
          AmountText(available, size: AmountSize.label),
        ],
      ),
    ],
  );
}

class QuoteSummary extends StatelessWidget {
  const QuoteSummary({super.key, required this.quote});
  final FxQuote quote;
  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TetriRadii.r16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TetriSpace.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MoneyStrings.youGet,
              style: TetriTypography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: TetriSpace.x8),
            AmountText(quote.netOut, size: AmountSize.title),
            const SizedBox(height: TetriSpace.x16),
            _QuoteLine(
              label: MoneyStrings.fee,
              child: AmountText(quote.fee, size: AmountSize.label),
            ),
            const SizedBox(height: TetriSpace.x8),
            Text(
              MoneyStrings.rateText(
                quote.amountIn.currency,
                quote.rate,
                quote.netOut.currency,
              ),
              style: TetriTypography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: TetriSpace.x4),
            Text(
              '${MoneyStrings.rateDate}: ${MoneyStrings.dateText(quote.rateDate)}',
              style: TetriTypography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TetriTypography.label.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
      ),
      Flexible(child: child),
    ],
  );
}

/// One reusable modal shell for both money actions, including slow-request states.
class MoneyReviewSheet extends StatelessWidget {
  const MoneyReviewSheet({
    super.key,
    required this.title,
    required this.rows,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onEdit,
    this.isLoading = false,
    this.notice,
  });
  final String title, confirmLabel;
  final List<ReviewLine> rows;
  final VoidCallback? onConfirm, onEdit;
  final bool isLoading;
  final String? notice;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TetriSpace.x24,
              TetriSpace.x24,
              TetriSpace.x24,
              TetriSizes.zero,
            ),
            child: InlineBanner(message: notice!, kind: BannerKind.warning),
          ),
        ReviewSheet(
          title: title,
          rows: rows,
          confirmLabel: confirmLabel,
          onConfirm: onConfirm,
          isLoading: isLoading,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: TetriSpace.x16),
          child: TetriTextButton(
            label: MoneyStrings.editAmount,
            onPressed: onEdit,
          ),
        ),
      ],
    ),
  );
}

AnimationStyle moneySheetAnimation(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: TetriMotion.screen,
        reverseDuration: TetriMotion.screen,
        curve: TetriMotion.curve,
        reverseCurve: TetriMotion.curve,
      );
