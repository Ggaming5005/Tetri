import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/status_view.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/features/convert/convert_screen.dart';
import 'package:tetri/features/transfer/transfer_screen.dart';

import '../helpers/fake_money_api.dart';

Future<void> pumpMoneyFlow(
  WidgetTester tester,
  FakeMoneyApi api,
  Widget child,
) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bankApiProvider.overrideWithValue(api),
        accountsProvider.overrideWith((ref) async => FakeMoneyApi.balances),
      ],
      child: MaterialApp(
        theme: TetriTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            disableAnimations: true,
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> enterAmount(WidgetTester tester, String amount) async {
  for (final key in amount.split('')) {
    final finder = find.byKey(ValueKey('amount-key-$key'));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }
}

Future<void> continueToReview(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, MoneyStrings.continueLabel);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'send review confirms the chosen integer amount and retries with one key',
    (tester) async {
      final api = FakeMoneyApi()
        ..transferErrors.add(
          const ApiError(
            code: 'timeout',
            message: 'Retry',
            retryable: true,
            isTimeout: true,
          ),
        );
      await pumpMoneyFlow(tester, api, const TransferScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@nino');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RecipientRow));
      await tester.pumpAndSettle();
      await enterAmount(tester, '25');
      await continueToReview(tester);
      expect(find.byType(MoneyReviewSheet), findsOneWidget);
      expect(find.text('@nino'), findsOneWidget);
      expect(api.transfers, isEmpty);
      await tester.tap(
        find.widgetWithText(FilledButton, MoneyStrings.sendConfirm),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(api.transfers, hasLength(2));
      expect(api.transfers.map((request) => request.key).toSet(), hasLength(1));
      expect(api.transfers.first.amount, const Money(2500, 'GEL'));
      expect(find.byType(StatusView), findsOneWidget);
      expect(find.text(MoneyStrings.sent), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired conversion shows fresh review without submitting it automatically',
    (tester) async {
      FxQuote quote(String id, int net) => FxQuote(
        quoteId: id,
        amountIn: const Money(1000, 'USD'),
        netOut: Money(net, 'GEL'),
        fee: const Money(13, 'GEL'),
        rate: '2.5',
        rateDate: DateTime.utc(2026, 11, 3),
        expiresAt: DateTime.utc(2026, 11, 3, 12, 1),
      );
      final api = FakeMoneyApi()
        ..quoteResults.addAll([
          quote('preview', 2487),
          quote('review', 2487),
          quote('replacement', 2470),
        ])
        ..conversionErrors.add(
          const ApiError(
            code: 'quote_expired',
            message: 'Expired',
            status: 409,
          ),
        );
      await pumpMoneyFlow(tester, api, const ConvertScreen());
      await tester.pumpAndSettle();
      await enterAmount(tester, '10');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.quoteCalls, 1);
      await continueToReview(tester);
      expect(api.quoteCalls, 2);
      expect(find.byType(MoneyReviewSheet), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, MoneyStrings.convertConfirm),
      );
      await tester.pumpAndSettle();
      expect(api.conversions, hasLength(1));
      expect(api.conversions.single.quoteId, 'review');
      expect(find.byType(MoneyReviewSheet), findsOneWidget);
      expect(find.text(MoneyStrings.quoteRefreshed), findsOneWidget);
      expect(find.text('₾24.70', findRichText: true), findsWidgets);
      expect(find.byType(StatusView), findsNothing);
      await tester.tap(
        find.widgetWithText(FilledButton, MoneyStrings.convertConfirm),
      );
      await tester.pumpAndSettle();
      expect(api.conversions, hasLength(2));
      expect(api.conversions.last.quoteId, 'replacement');
      expect(api.conversions.last.key, isNot(api.conversions.first.key));
      expect(find.text(MoneyStrings.converted), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
