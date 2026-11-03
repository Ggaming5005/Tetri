import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/features/activity/transaction_detail_screen.dart';

import '../helpers/banking_fakes.dart';

void main() {
  testWidgets(
    'detail waits for its API and renders only the returned own amount',
    (tester) async {
      final pending = Completer<TransactionView>();
      final api = FakeBankApi()..transactionHandler = (_) => pending.future;
      await pumpBanking(
        tester,
        const TransactionDetailScreen(transactionId: 'owned'),
        api,
      );
      expect(find.byType(LoadingList), findsOneWidget);
      pending.complete(sampleTransaction('owned'));
      await tester.pumpAndSettle();
      expect(find.text(BankingStrings.posted), findsOneWidget);
      expect(find.text('Giorgi M.\n@giorgi'), findsOneWidget);
      expect(
        tester.widget<AmountText>(find.byType(AmountText)).amount,
        const Money(-2500, 'GEL'),
      );
    },
  );

  testWidgets('detail exposes retry on a failed read', (tester) async {
    var fail = true;
    final api = FakeBankApi()
      ..transactionHandler = (id) async {
        if (fail) throw StateError('not found');
        return sampleTransaction(id);
      };
    await pumpBanking(
      tester,
      const TransactionDetailScreen(transactionId: 'owned'),
      api,
    );
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.cannotLoad), findsOneWidget);
    fail = false;
    await tester.tap(find.text(BankingStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(ReferenceCopy), findsOneWidget);
  });

  testWidgets(
    'conversion detail displays both currencies, exact rate and target fee',
    (tester) async {
      final api = FakeBankApi()
        ..transactionHandler = (id) async => TransactionView(
          id: id,
          kind: 'conversion',
          status: 'posted',
          description: '',
          createdAt: DateTime(2024),
          entries: const [
            EntryView(accountId: 'usd', amount: Money(-10000, 'USD')),
            EntryView(accountId: 'gel', amount: Money(26865, 'GEL')),
          ],
          rate: '2.7',
          fee: const Money(135, 'GEL'),
        );
      await pumpBanking(
        tester,
        const TransactionDetailScreen(transactionId: 'fx'),
        api,
      );
      await tester.pumpAndSettle();
      expect(find.text('2.7'), findsOneWidget);
      expect(
        tester
            .widgetList<AmountText>(find.byType(AmountText))
            .map((widget) => widget.amount),
        containsAll([
          const Money(-10000, 'USD'),
          const Money(26865, 'GEL'),
          const Money(135, 'GEL'),
        ]),
      );
    },
  );

  testWidgets('reference copy sends exact transaction id to the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpBanking(
      tester,
      const TransactionDetailScreen(transactionId: 'copy-this-reference'),
      FakeBankApi(),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(BankingStrings.copyReference));
    await tester.tap(find.text(BankingStrings.copyReference));
    await tester.pumpAndSettle();
    expect(copied, 'copy-this-reference');
    expect(find.text(BankingStrings.referenceCopied), findsOneWidget);
  });
}
