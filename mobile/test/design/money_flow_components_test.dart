import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/review_sheet.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets('flow navigation and recipient selection expose their actions', (
    tester,
  ) async {
    var back = false, selected = false;
    await pumpTetri(
      tester,
      Column(
        children: [
          FlowNavigation(onBack: () => back = true),
          RecipientRow(
            recipient: const RecipientView(
              displayName: 'Nino',
              handle: '@nino',
            ),
            onTap: () => selected = true,
          ),
        ],
      ),
    );
    await tester.tap(find.text(MoneyStrings.back));
    await tester.tap(find.text('@nino'));
    expect(back, isTrue);
    expect(selected, isTrue);
  });

  testWidgets(
    'entry and quote summaries use exact money and the official rate date',
    (tester) async {
      await pumpTetri(
        tester,
        Column(
          children: [
            const MoneyEntrySummary(
              amount: Money(2500, 'USD'),
              available: Money(30000, 'USD'),
            ),
            QuoteSummary(
              quote: FxQuote(
                quoteId: 'q',
                amountIn: const Money(2500, 'USD'),
                netOut: const Money(6716, 'GEL'),
                fee: const Money(34, 'GEL'),
                rate: '2.7',
                rateDate: DateTime.utc(2026, 11, 3),
                expiresAt: DateTime.utc(2026, 11, 3, 12, 1),
              ),
            ),
          ],
        ),
      );
      expect(find.text(r'$25.00', findRichText: true), findsOneWidget);
      expect(find.text(r'$300.00', findRichText: true), findsOneWidget);
      expect(find.text('₾67.16', findRichText: true), findsOneWidget);
      expect(find.text('₾0.34', findRichText: true), findsOneWidget);
      expect(find.text('Official rate date: 3 Nov 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'review notice keeps terms visible and requires explicit confirmation',
    (tester) async {
      var confirmed = false, edited = false;
      await pumpTetri(
        tester,
        MoneyReviewSheet(
          title: MoneyStrings.reviewConversion,
          rows: const [
            ReviewLine.money(MoneyStrings.youGet, Money(6716, 'GEL')),
          ],
          notice: MoneyStrings.quoteRefreshed,
          confirmLabel: MoneyStrings.convertConfirm,
          onConfirm: () => confirmed = true,
          onEdit: () => edited = true,
        ),
      );
      expect(find.text(MoneyStrings.quoteRefreshed), findsOneWidget);
      expect(confirmed, isFalse);
      await tester.tap(find.text(MoneyStrings.editAmount));
      expect(edited, isTrue);
      await tester.tap(
        find.widgetWithText(FilledButton, MoneyStrings.convertConfirm),
      );
      expect(confirmed, isTrue);
    },
  );
}
