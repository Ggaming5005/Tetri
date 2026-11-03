import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/currency_picker.dart';
import 'package:tetri/design/components/review_sheet.dart';

import '../helpers/pump_tetri.dart';

void main() {
  for (final largeText in [false, true]) {
    testWidgets(
      'account panel header ${largeText ? 'stacks enlarged text' : 'shares one compact row'}',
      (tester) async {
        const account = MoneyAccount(id: 'usd', balance: Money(30000, 'USD'));
        await pumpTetri(
          tester,
          MoneyAccountPanel(
            label: MoneyStrings.youGet,
            selector: CurrencyPicker(
              compact: true,
              accounts: const [account],
              selected: account,
              onChanged: (_) {},
            ),
            child: const AmountText(Money(1025, 'USD')),
          ),
          size: Size(largeText ? 320 : 360, 800),
          textScaler: TextScaler.linear(largeText ? 2 : 1),
        );
        final label = tester.getRect(find.text(MoneyStrings.youGet));
        final selector = tester.getRect(find.byType(CurrencyPicker));
        if (largeText) {
          expect(label.bottom, lessThan(selector.top));
        } else {
          expect(label.center.dy, closeTo(selector.center.dy, 0.01));
          expect(label.right, lessThan(selector.left));
        }
        expect(selector.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact header exposes one heading and an accessible back action',
    (tester) async {
      var back = false;
      await pumpTetri(
        tester,
        FlowNavigation(title: MoneyStrings.convert, onBack: () => back = true),
      );
      expect(find.text(MoneyStrings.convert), findsOneWidget);
      await tester.tap(find.byTooltip(MoneyStrings.back));
      expect(back, isTrue);
    },
  );

  testWidgets(
    'account panel and quiet quote details show exact balance, fee and official date',
    (tester) async {
      await pumpTetri(
        tester,
        Column(
          children: [
            const MoneyAccountPanel(
              label: MoneyStrings.from,
              selector: Text('USD'),
              available: Money(30000, 'USD'),
              child: AmountText(Money(2500, 'USD')),
            ),
            QuoteDetails(
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
      expect(find.text(r'$300.00', findRichText: true), findsOneWidget);
      expect(find.text(r'$25.00', findRichText: true), findsOneWidget);
      expect(find.text('₾0.34', findRichText: true), findsOneWidget);
      expect(find.text('1 USD = 2.7 GEL'), findsOneWidget);
      expect(find.text('Official rate date: 3 Nov 2026'), findsOneWidget);
    },
  );

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
