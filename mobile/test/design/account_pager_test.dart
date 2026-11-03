import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/account_card.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/banking_fakes.dart';
import '../helpers/pump_tetri.dart';

Color indicatorColor(WidgetTester tester, int index) =>
    (tester
                .widget<DecoratedBox>(
                  find.byKey(ValueKey('account-page-indicator-$index')),
                )
                .decoration
            as BoxDecoration)
        .color!;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'account indicators follow swipes and preserve card taps in ${brightness.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? chosen;
          final pages = <MoneyAccount>[];
          await pumpTetri(
            tester,
            AccountPager(
              accounts: sampleAccounts,
              onSelected: (account) => chosen = account.currency,
              onPageChanged: pages.add,
            ),
            brightness: brightness,
          );
          final colors = brightness == Brightness.light
              ? TetriColors.light
              : TetriColors.dark;
          expect(
            find.byKey(const ValueKey('account-page-indicator-0')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('account-page-indicator-1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('account-page-indicator-2')),
            findsOneWidget,
          );
          expect(indicatorColor(tester, 0), colors.accent);
          expect(indicatorColor(tester, 1), colors.border);
          expect(indicatorColor(tester, 2), colors.border);
          expect(find.bySemanticsLabel('Account 1/3, GEL'), findsOneWidget);
          expect(pages, isEmpty);

          await tester.drag(find.byType(PageView), const Offset(-300, 0));
          await tester.pumpAndSettle();
          expect(indicatorColor(tester, 0), colors.border);
          expect(indicatorColor(tester, 1), colors.accent);
          expect(indicatorColor(tester, 2), colors.border);
          expect(find.bySemanticsLabel('Account 2/3, USD'), findsOneWidget);
          expect(pages, [sampleAccounts[1]]);
          final usd = find.byWidgetPredicate(
            (widget) =>
                widget is AccountCard && widget.account.currency == 'USD',
          );
          await tester.tap(usd);
          expect(chosen, 'USD');
          expect(pages, [sampleAccounts[1]]);

          await tester.drag(find.byType(PageView), const Offset(-300, 0));
          await tester.pumpAndSettle();
          expect(indicatorColor(tester, 1), colors.border);
          expect(indicatorColor(tester, 2), colors.accent);
          expect(find.bySemanticsLabel('Account 3/3, EUR'), findsOneWidget);
          expect(pages, [sampleAccounts[1], sampleAccounts[2]]);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(768, 1024)]) {
    testWidgets('pager indicators fit ${size.width} dp with large text', (
      tester,
    ) async {
      await pumpTetri(
        tester,
        SingleChildScrollView(
          child: AccountPager(accounts: sampleAccounts, onSelected: (_) {}),
        ),
        size: size,
        textScaler: const TextScaler.linear(3),
      );
      expect(tester.takeException(), isNull);
      final pager = tester.getRect(find.byType(PageView));
      final indicator = tester.getRect(
        find.byKey(const ValueKey('account-page-position')),
      );
      expect(indicator.top, greaterThanOrEqualTo(pager.bottom));
      expect(indicator.left, greaterThanOrEqualTo(0));
      expect(indicator.right, lessThanOrEqualTo(size.width));
      await tester.drag(find.byType(PageView), Offset(-pager.width, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(indicatorColor(tester, 1), TetriColors.light.accent);
    });
  }
}
