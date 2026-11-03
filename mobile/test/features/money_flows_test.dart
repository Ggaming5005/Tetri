import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/money_amount_input.dart';
import 'package:tetri/design/components/amount_keypad.dart';
import 'package:tetri/design/components/status_view.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';
import 'package:tetri/features/convert/convert_screen.dart';
import 'package:tetri/features/transfer/transfer_screen.dart';

import '../helpers/fake_money_api.dart';

Future<void> pumpMoneyFlow(
  WidgetTester tester,
  FakeMoneyApi api,
  Widget child, {
  Size size = const Size(360, 800),
  double keyboardInset = 0,
  double textScale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            textScaler: TextScaler.linear(textScale),
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
  final field = find.descendant(
    of: find.byType(MoneyAmountInput),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, amount);
  await tester.pump();
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
  for (final send in [true, false]) {
    testWidgets(
      '${send ? 'Send' : 'Convert'} unresolved timeouts show a neutral pending result and retry the same key',
      (tester) async {
        final api = FakeMoneyApi();
        final failures = List.filled(
          4,
          const ApiError(
            code: 'timeout',
            message: 'Retry',
            isTimeout: true,
            retryable: true,
          ),
        );
        if (send) {
          api.transferErrors.addAll(failures);
        } else {
          api.conversionErrors.addAll(failures);
        }
        await pumpMoneyFlow(
          tester,
          api,
          send ? const TransferScreen() : const ConvertScreen(),
        );
        await tester.pumpAndSettle();
        if (send) {
          await tester.enterText(find.byType(TextField), '@nino');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(RecipientRow));
          await tester.pumpAndSettle();
        }
        await enterAmount(tester, '25');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await continueToReview(tester);
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            send ? MoneyStrings.sendConfirm : MoneyStrings.convertConfirm,
          ),
        );
        await tester.pump();
        for (final seconds in [1, 2, 4]) {
          await tester.pump(Duration(seconds: seconds));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<StatusView>(find.byType(StatusView)).isPending,
          isTrue,
        );
        expect(find.text(MoneyStrings.checking), findsOneWidget);
        expect(find.byIcon(PhosphorIconsRegular.warningCircle), findsNothing);
        expect(
          tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.clock)).color,
          TetriColors.light.textSecondary,
        );
        final firstKeys = send
            ? api.transfers.map((request) => request.key).toList()
            : api.conversions.map((request) => request.key).toList();
        expect(firstKeys, hasLength(4));
        expect(firstKeys.toSet(), hasLength(1));
        await tester.tap(find.widgetWithText(FilledButton, MoneyStrings.retry));
        await tester.pumpAndSettle();
        final retriedKeys = send
            ? api.transfers.map((request) => request.key).toList()
            : api.conversions.map((request) => request.key).toList();
        expect(retriedKeys, hasLength(5));
        expect(retriedKeys.toSet(), {firstKeys.first});
        expect(
          tester.widget<StatusView>(find.byType(StatusView)).isPending,
          isFalse,
        );
        expect(find.byIcon(PhosphorIconsRegular.checkCircle), findsOneWidget);
        expect(find.byIcon(PhosphorIconsRegular.clock), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final geometry in [
    (size: const Size(320, 640), inset: 280.0, scale: 1.0),
    (size: const Size(640, 360), inset: 160.0, scale: 1.0),
    (size: const Size(360, 800), inset: 260.0, scale: 2.0),
    (size: const Size(1024, 768), inset: 300.0, scale: 1.0),
  ]) {
    for (final send in [false, true]) {
      testWidgets(
        '${send ? 'Send' : 'Convert'} native input fits ${geometry.size} with keyboard and text scale ${geometry.scale}',
        (tester) async {
          final api = FakeMoneyApi();
          await pumpMoneyFlow(
            tester,
            api,
            send ? const TransferScreen() : const ConvertScreen(),
            size: geometry.size,
            keyboardInset: geometry.inset,
            textScale: geometry.scale,
          );
          await tester.pumpAndSettle();
          if (send) {
            await tester.enterText(find.byType(TextField), '@nino');
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
            final recipient = find.byType(RecipientRow);
            await tester.ensureVisible(recipient);
            await tester.pumpAndSettle();
            await tester.tap(recipient);
            await tester.pumpAndSettle();
          }
          await enterAmount(tester, '10.25');
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(find.byType(AmountKeypad), findsNothing);
          final button = find.widgetWithText(
            FilledButton,
            MoneyStrings.continueLabel,
          );
          if (geometry.size.height - geometry.inset >= 320) {
            expect(button.hitTestable(), findsOneWidget);
          }
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(button).bottom,
            lessThanOrEqualTo(geometry.size.height - geometry.inset),
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
      expect(
        find.descendant(
          of: find.byType(MoneyReviewSheet),
          matching: find.text('@nino'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MoneyReviewSheet),
          matching: find.text('₾25.00', findRichText: true),
        ),
        findsNWidgets(2),
      );
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
      expect(
        tester.getRect(find.byKey(const ValueKey('status-action'))).bottom,
        closeTo(tester.view.physicalSize.height - TetriSpace.x24, 0.01),
      );
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
      expect(
        tester.getRect(find.byKey(const ValueKey('status-action'))).bottom,
        closeTo(tester.view.physicalSize.height - TetriSpace.x24, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
