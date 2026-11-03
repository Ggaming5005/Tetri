import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'buttons.dart';

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
  });

  final String title;
  final List<ReviewLine> rows;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: TetriSpace.x24,
          right: TetriSpace.x24,
          top: TetriSpace.x32,
          bottom: TetriSpace.x24 + MediaQuery.viewInsetsOf(context).bottom,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TetriSpace.x8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TetriTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: TetriSpace.x16),
                    Expanded(
                      child: row.amount != null
                          ? AmountText(row.amount!, textAlign: TextAlign.end)
                          : Text(
                              row.value!,
                              textAlign: TextAlign.end,
                              style: TetriTypography.body.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                    ),
                  ],
                ),
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
    );
  }
}
