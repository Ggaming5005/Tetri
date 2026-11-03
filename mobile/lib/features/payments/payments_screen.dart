import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/strings_banking.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/navigation_action.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => TetriScaffold(
    bottomNavigationBar: const TetriNavigation(selectedIndex: 1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardHeading(
          title: BankingStrings.payments,
          onProfile: () => context.push('/settings'),
        ),
        const SizedBox(height: TetriSpace.x24),
        NavigationAction(
          icon: PhosphorIconsRegular.paperPlaneTilt,
          title: BankingStrings.sendMoney,
          description: BankingStrings.sendMoneyDescription,
          onTap: () => context.push('/send'),
        ),
        const SizedBox(height: TetriSpace.x12),
        NavigationAction(
          icon: PhosphorIconsRegular.arrowsLeftRight,
          title: BankingStrings.convertCurrencies,
          description: BankingStrings.convertCurrenciesDescription,
          onTap: () => context.push('/convert'),
        ),
      ],
    ),
  );
}
