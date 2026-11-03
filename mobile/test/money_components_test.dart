import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/strings.dart';
import 'package:tetri/design/components/account_card.dart';
import 'package:tetri/design/components/currency_flag.dart';
import 'package:tetri/design/components/amount_keypad.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/currency_picker.dart';
import 'package:tetri/design/components/review_sheet.dart';
import 'package:tetri/design/components/transaction_row.dart';
import 'package:tetri/design/tokens.dart';

import 'helpers/pump_tetri.dart';

void main() {
  const accounts = [
    MoneyAccount(id: 'gel', balance: Money(123456, 'GEL')),
    MoneyAccount(id: 'usd', balance: Money(30000, 'USD')),
    MoneyAccount(id: 'eur', balance: Money(30000, 'EUR')),
  ];

  group('AmountText', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'large amounts dim cents and use tabular figures $brightness',
        (tester) async {
          await pumpTetri(
            tester,
            const AmountText(Money(123456, 'GEL'), size: AmountSize.display),
            brightness: brightness,
          );
          final colors = brightness == Brightness.light
              ? TetriColors.light
              : TetriColors.dark;
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byType(AmountText),
              matching: find.byType(Text),
            ),
          );
          expect(text.textSpan!.toPlainText(), '₾1,234.56');
          expect(
            text.style!.fontFeatures,
            contains(const FontFeature.tabularFigures()),
          );
          final fraction =
              (text.textSpan! as TextSpan).children!.last as TextSpan;
          expect(fraction.text, '.56');
          expect(fraction.style!.color, colors.textSecondary);
          expect(text.style!.color, colors.textPrimary);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('incoming is positive and outgoing stays neutral', (
      tester,
    ) async {
      await pumpTetri(
        tester,
        const Column(
          children: [
            AmountText(Money(1050, 'USD'), showSign: true),
            AmountText(Money(-1050, 'EUR'), showSign: true),
          ],
        ),
      );
      final amounts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AmountText),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(amounts[0].textSpan!.toPlainText(), r'+$10.50');
      expect(amounts[0].style!.color, TetriColors.light.positive);
      expect(amounts[1].textSpan!.toPlainText(), '-€10.50');
      expect(amounts[1].style!.color, TetriColors.light.textPrimary);
    });

    testWidgets('large integers fit a small phone without losing digits', (
      tester,
    ) async {
      await pumpTetri(
        tester,
        const AmountText(
          Money(9223372036854775807, 'GEL'),
          size: AmountSize.display,
        ),
      );
      expect(
        find.text('₾92,233,720,368,547,758.07', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AmountKeypad', () {
    testWidgets(
      'edits only canonical two-decimal amounts and has large targets',
      (tester) async {
        var value = '0';
        await pumpTetri(
          tester,
          StatefulBuilder(
            builder: (context, setState) => AmountKeypad(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        );
        for (final key in ['0', '0', '1', '.', '.', '2', '3', '4']) {
          final finder = find.byKey(ValueKey('amount-key-$key'));
          final size = tester.getSize(finder);
          expect(size.width, greaterThanOrEqualTo(TetriSizes.tap48));
          expect(size.height, greaterThanOrEqualTo(TetriSizes.tap48));
          await tester.tap(finder);
          await tester.pump();
        }
        expect(value, '1.23');
        await tester.tap(find.byKey(const ValueKey('amount-key-backspace')));
        await tester.pump();
        expect(value, '1.2');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disabled keypad cannot change an amount', (tester) async {
      var called = false;
      await pumpTetri(
        tester,
        AmountKeypad(
          value: '10.50',
          enabled: false,
          onChanged: (_) => called = true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('amount-key-9')));
      expect(called, isFalse);
    });
  });

  group('AccountCard', () {
    for (final account in accounts) {
      testWidgets('shows the ${account.currency} name, flag and balance', (
        tester,
      ) async {
        var tapped = false;
        await pumpTetri(
          tester,
          AccountCard(account: account, onTap: () => tapped = true),
        );
        expect(
          find.text(TetriStrings.currencyName(account.currency)),
          findsOneWidget,
        );
        expect(
          tester.widget<CurrencyFlag>(find.byType(CurrencyFlag)).currency,
          account.currency,
        );
        expect(
          find.text(MoneyFormat.format(account.balance), findRichText: true),
          findsOneWidget,
        );
        await tester.tap(find.byType(AccountCard));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('TransactionRow', () {
    testWidgets('shows details and signed amount, and opens when tapped', (
      tester,
    ) async {
      var tapped = false;
      await pumpTetri(
        tester,
        TransactionRow(
          title: TetriStrings.demoNino,
          subtitle: TetriStrings.demoDate,
          amount: const Money(-2500, 'GEL'),
          onTap: () => tapped = true,
        ),
      );
      expect(find.text(TetriStrings.demoNino), findsOneWidget);
      expect(find.text(TetriStrings.demoDate), findsOneWidget);
      expect(find.text('-₾25.00', findRichText: true), findsOneWidget);
      expect(
        tester.getSize(find.byType(TransactionRow)).height,
        greaterThanOrEqualTo(TetriSizes.listRow64),
      );
      await tester.tap(find.byType(TransactionRow));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewSheet', () {
    const rows = [
      ReviewLine.text(TetriStrings.to, TetriStrings.demoNinoHandle),
      ReviewLine.money(TetriStrings.amount, Money(2500, 'GEL')),
      ReviewLine.money(TetriStrings.fee, Money(0, 'GEL')),
      ReviewLine.text(TetriStrings.rate, '1 USD = 2.5970 GEL'),
      ReviewLine.money(TetriStrings.total, Money(2500, 'GEL')),
    ];

    testWidgets('shows exact review terms before confirming', (tester) async {
      var confirmed = false;
      await pumpTetri(
        tester,
        ReviewSheet(rows: rows, onConfirm: () => confirmed = true),
      );
      expect(find.text(TetriStrings.demoNinoHandle), findsOneWidget);
      expect(find.text(TetriStrings.fee), findsOneWidget);
      expect(find.text('1 USD = 2.5970 GEL'), findsOneWidget);
      expect(find.text('₾25.00', findRichText: true), findsNWidgets(2));
      expect(confirmed, isFalse);
      await tester.tap(find.text(TetriStrings.confirm));
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'loading keeps terms visible and prevents double confirmation',
      (tester) async {
        var confirmed = false;
        await pumpTetri(
          tester,
          ReviewSheet(
            rows: rows,
            onConfirm: () => confirmed = true,
            isLoading: true,
          ),
        );
        expect(find.text(TetriStrings.demoNinoHandle), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        expect(confirmed, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CurrencyPicker', () {
    testWidgets('opens accounts and returns the selected account', (
      tester,
    ) async {
      MoneyAccount? chosen;
      await pumpTetri(
        tester,
        CurrencyPicker(
          accounts: accounts,
          selected: accounts.first,
          onChanged: (account) => chosen = account,
        ),
      );
      expect(find.text('GEL'), findsOneWidget);
      expect(find.text('₾1,234.56', findRichText: true), findsOneWidget);
      await tester.tap(find.byType(CurrencyPicker));
      await tester.pumpAndSettle();
      expect(find.text(TetriStrings.chooseAccount), findsOneWidget);
      expect(find.text(TetriStrings.usdName), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('currency-account-usd')));
      await tester.pumpAndSettle();
      expect(chosen?.id, 'usd');
      expect(find.text(TetriStrings.chooseAccount), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not open when disabled', (tester) async {
      await pumpTetri(
        tester,
        CurrencyPicker(
          accounts: accounts,
          selected: accounts.first,
          enabled: false,
          onChanged: (_) => fail('Disabled account picker changed selection'),
        ),
      );
      await tester.tap(find.byType(CurrencyPicker));
      await tester.pumpAndSettle();
      expect(find.text(TetriStrings.chooseAccount), findsNothing);
    });
  });
}
