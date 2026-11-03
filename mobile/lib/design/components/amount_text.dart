import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../tokens.dart';
import '../typography.dart';

enum AmountSize { display, title, body, label }

class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.size = AmountSize.body,
    this.showSign = false,
    this.color,
    this.textAlign = TextAlign.start,
  });

  final Money amount;
  final AmountSize size;
  final bool showSign;
  final Color? color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final parts = MoneyFormat.parts(amount, showSign: showSign);
    final amountColor =
        color ??
        (showSign && amount.minor > 0 ? colors.positive : colors.textPrimary);
    final large = size == AmountSize.display || size == AmountSize.title;
    final style = switch (size) {
      AmountSize.display => TetriTypography.displayAmount,
      AmountSize.title => TetriTypography.titleAmount,
      AmountSize.body => TetriTypography.body,
      AmountSize.label => TetriTypography.label,
    };
    return Semantics(
      label: MoneyFormat.semantics(amount, showSign: showSign),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: switch (textAlign) {
          TextAlign.center => Alignment.center,
          TextAlign.right || TextAlign.end => AlignmentDirectional.centerEnd,
          _ => AlignmentDirectional.centerStart,
        },
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${parts.prefix}${parts.whole}'),
              TextSpan(
                text: parts.fraction,
                style: TextStyle(
                  color: large ? colors.textSecondary : amountColor,
                ),
              ),
            ],
          ),
          style: style.copyWith(
            color: amountColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: textAlign,
          maxLines: 1,
        ),
      ),
    );
  }
}
