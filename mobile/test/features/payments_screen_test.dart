import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/design/components/navigation_action.dart';
import 'package:tetri/features/payments/payments_screen.dart';

import '../helpers/banking_fakes.dart';

void main() {
  testWidgets('Payments shows static actions without loading bank data', (
    tester,
  ) async {
    final api = FakeBankApi();
    var reads = 0;
    api.accountsHandler = () async {
      reads++;
      return sampleAccounts;
    };
    api.profileHandler = () async {
      reads++;
      return sampleUser;
    };
    api.ratesHandler = () async {
      reads++;
      return sampleRates;
    };
    await pumpBanking(tester, const PaymentsScreen(), api);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DashboardHeading>(find.byType(DashboardHeading)).title,
      BankingStrings.payments,
    );
    expect(find.byType(NavigationAction), findsNWidgets(2));
    expect(find.text(BankingStrings.sendMoneyDescription), findsOneWidget);
    expect(
      find.text(BankingStrings.convertCurrenciesDescription),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TetriNavigation>(find.byType(TetriNavigation))
          .selectedIndex,
      1,
    );
    expect(reads, 0);
    expect(api.historyCalls, isEmpty);
    final profile = find.byTooltip(BankingStrings.profile);
    expect(profile.hitTestable(), findsOneWidget);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(find.text('/settings'), findsOneWidget);
    expect(reads, 0);
  });

  for (final action in {
    BankingStrings.sendMoney: '/send',
    BankingStrings.convertCurrencies: '/convert',
  }.entries) {
    testWidgets('${action.key} opens its payment flow', (tester) async {
      await pumpBanking(tester, const PaymentsScreen(), FakeBankApi());
      await tester.pumpAndSettle();
      await tester.tap(find.text(action.key));
      await tester.pumpAndSettle();
      expect(find.text(action.value), findsOneWidget);
    });
  }

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(360, 800),
      const Size(430, 932),
      const Size(768, 1024),
    ]) {
      testWidgets(
        'Payments fits ${size.width} dp in ${brightness.name} with large text',
        (tester) async {
          await pumpBanking(
            tester,
            const PaymentsScreen(),
            FakeBankApi(),
            brightness: brightness,
            size: size,
            textScaler: const TextScaler.linear(2),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(BankingStrings.convertCurrencies),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(BankingStrings.convertCurrencies), findsOneWidget);
          for (final action in find.byType(NavigationAction).evaluate()) {
            expect(
              tester.getSize(find.byWidget(action.widget)).height,
              greaterThanOrEqualTo(48),
            );
          }
        },
      );
    }
  }
}
