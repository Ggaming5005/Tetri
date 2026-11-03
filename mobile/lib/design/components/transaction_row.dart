import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/money.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.leading,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Money amount;
  final Widget? leading;
  final VoidCallback? onTap;

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
                leading ??
                    Container(
                      width: TetriSizes.tap48,
                      height: TetriSizes.tap48,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        amount.minor > 0
                            ? PhosphorIconsRegular.arrowDownLeft
                            : PhosphorIconsRegular.arrowUpRight,
                        color: colors.textSecondary,
                        size: TetriSizes.icon24,
                      ),
                    ),
                const SizedBox(width: TetriSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TetriTypography.title.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TetriTypography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TetriSpace.x12),
                Expanded(
                  child: AmountText(
                    amount,
                    showSign: true,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
