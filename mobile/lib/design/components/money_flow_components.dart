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
  const FlowNavigation({super.key, required this.onBack, this.title});
  final VoidCallback? onBack;
  final String? title;
  @override
  Widget build(BuildContext context) => title == null
      ? Align(
          alignment: AlignmentDirectional.centerStart,
          child: TetriTextButton(label: MoneyStrings.back, onPressed: onBack),
        )
      : Row(
          children: [
            IconButton(
              tooltip: MoneyStrings.back,
              onPressed: onBack,
              constraints: const BoxConstraints(
                minWidth: TetriSizes.tap48,
                minHeight: TetriSizes.tap48,
              ),
              icon: Icon(
                PhosphorIconsRegular.arrowLeft,
                size: TetriSizes.icon24,
                color: TetriColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(width: TetriSpace.x8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: TetriTypography.title.copyWith(
                    color: TetriColors.of(context).textPrimary,
                  ),
                ),
              ),
            ),
          ],
        );
}

/// Keeps account selection, amount and balance together at every screen width.
class MoneyAccountPanel extends StatelessWidget {
  const MoneyAccountPanel({
    super.key,
    required this.label,
    required this.selector,
    required this.child,
    this.available,
  });
  final String label;
  final Widget selector, child;
  final Money? available;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: TetriColors.of(context).surface,
      borderRadius: BorderRadius.circular(TetriRadii.r16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(TetriSpace.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            spacing: TetriSpace.x16,
            overflowSpacing: TetriSpace.x4,
            overflowAlignment: OverflowBarAlignment.start,
            children: [
              Text(
                label,
                style: TetriTypography.label.copyWith(
                  color: TetriColors.of(context).textSecondary,
                ),
              ),
              IntrinsicWidth(child: selector),
            ],
          ),
          const SizedBox(height: TetriSpace.x8),
          child,
          if (available != null) ...[
            const SizedBox(height: TetriSpace.x8),
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
                AmountText(available!, size: AmountSize.label),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class QuoteDetails extends StatelessWidget {
  const QuoteDetails({super.key, required this.quote});
  final FxQuote? quote;

  @override
  Widget build(BuildContext context) {
    final style = TetriTypography.label.copyWith(
      color: TetriColors.of(context).textSecondary,
    );
    final current = quote;
    if (current == null) return Text(MoneyStrings.quoteEmpty, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          MoneyStrings.rateText(
            current.amountIn.currency,
            current.rate,
            current.netOut.currency,
          ),
          style: style,
        ),
        const SizedBox(height: TetriSpace.x8),
        _QuoteLine(
          label: MoneyStrings.fee,
          child: AmountText(current.fee, size: AmountSize.label),
        ),
        const SizedBox(height: TetriSpace.x8),
        Text(
          '${MoneyStrings.rateDate}: ${MoneyStrings.dateText(current.rateDate)}',
          style: style,
        ),
      ],
    );
  }
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
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
          includeKeyboardInset: false,
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
