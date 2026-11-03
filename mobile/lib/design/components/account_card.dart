import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, this.onTap});

  final MoneyAccount account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(TetriRadii.r16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TetriRadii.r16),
        child: Padding(
          padding: const EdgeInsets.all(TetriSpace.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CurrencyBadge(currency: account.currency),
                  const SizedBox(width: TetriSpace.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.currency,
                          style: TetriTypography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          TetriStrings.currencyName(account.currency),
                          style: TetriTypography.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TetriSpace.x24),
              AmountText(account.balance, size: AmountSize.title),
            ],
          ),
        ),
      ),
    );
  }
}

class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({super.key, required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: TetriSizes.currencyFlag40,
      child: ClipOval(
        child: ColoredBox(
          color: TetriColors.of(context).surfaceRaised,
          child: Center(
            child: Text(
              MoneyFormat.flag(currency),
              style: TetriTypography.headline,
            ),
          ),
        ),
      ),
    ),
  );
}
