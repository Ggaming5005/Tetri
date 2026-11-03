import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';
import 'currency_flag.dart';

class TetriWordmark extends StatelessWidget {
  const TetriWordmark({super.key});

  @override
  Widget build(BuildContext context) => Text(
    TetriStrings.appName,
    style: TetriTypography.displayAmount.copyWith(
      color: TetriColors.of(context).textPrimary,
    ),
  );
}

class TetriCurrencies extends StatelessWidget {
  const TetriCurrencies({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: TetriSizes.artworkHeight,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final currency in const ['GEL', 'USD', 'EUR'])
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(child: CurrencyFlag(currency: currency)),
              const SizedBox(height: TetriSpace.x16),
              Text(
                currency,
                style: TetriTypography.label.copyWith(
                  color: TetriColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
