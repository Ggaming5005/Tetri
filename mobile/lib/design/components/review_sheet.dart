import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'buttons.dart';
import 'browse_components.dart';

final class ReviewLine {
  const ReviewLine.text(this.label, String text) : value = text, amount = null;
  const ReviewLine.money(this.label, Money money)
    : value = null,
      amount = money;

  final String label;
  final String? value;
  final Money? amount;
}

class ReviewSheet extends StatelessWidget {
  const ReviewSheet({
    super.key,
    this.title = TetriStrings.review,
    required this.rows,
    required this.onConfirm,
    this.confirmLabel = TetriStrings.confirm,
    this.isLoading = false,
    this.includeKeyboardInset = true,
  });

  final String title;
  final List<ReviewLine> rows;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final bool isLoading;
  final bool includeKeyboardInset;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Align(
      alignment: Alignment.topCenter,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TetriSizes.sheetMaxWidth),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: TetriSpace.x24,
              right: TetriSpace.x24,
              top: TetriSpace.x24,
              bottom:
                  TetriSpace.x24 +
                  (includeKeyboardInset
                      ? MediaQuery.viewInsetsOf(context).bottom
                      : 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TetriTypography.headline.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: TetriSpace.x24),
                for (final row in rows)
                  DetailLine(
                    label: row.label,
                    value: row.value,
                    trailing: row.amount == null
                        ? null
                        : AmountText(row.amount!, textAlign: TextAlign.end),
                  ),
                const SizedBox(height: TetriSpace.x24),
                PrimaryButton(
                  label: confirmLabel,
                  onPressed: onConfirm,
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
