import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/transaction_row.dart';
import 'package:tetri/features/accounts/account_screen.dart';
import 'package:tetri/features/activity/activity_screen.dart';
import 'package:tetri/features/activity/history_controller.dart';
import 'package:tetri/features/activity/transaction_presentation.dart';

import '../helpers/banking_fakes.dart';

void main() {
  test(
    'cursor pagination preserves order and ignores duplicate boundary items',
    () async {
      final api = FakeBankApi()
        ..historyHandler =
            ({accountId, required filter, cursor, required pageSize}) async =>
                cursor == null
                ? TransactionPage(
                    items: [sampleTransaction('one')],
                    nextCursor: 'next',
                  )
                : TransactionPage(
                    items: [sampleTransaction('one'), sampleTransaction('two')],
                  );
      final controller = HistoryController(api, accountId: 'gel');
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.items.map((item) => item.id), ['one', 'two']);
      expect(controller.nextCursor, isNull);
      expect(api.historyCalls.map((call) => call.accountId), ['gel', 'gel']);
      expect(api.historyCalls.last.cursor, 'next');
    },
  );

  test('a late response cannot replace a newer filter result', () async {
    final old = Completer<TransactionPage>();
    final api = FakeBankApi()
      ..historyHandler =
          ({accountId, required filter, cursor, required pageSize}) =>
              filter == 'all'
              ? old.future
              : Future.value(
                  TransactionPage(items: [sampleTransaction('sent')]),
                );
    final controller = HistoryController(api);
    addTearDown(controller.dispose);
    final first = controller.refresh();
    await controller.refresh(newFilter: 'sent');
    old.complete(TransactionPage(items: [sampleTransaction('stale')]));
    await first;
    expect(controller.items.single.id, 'sent');
    expect(controller.filter, 'sent');
  });

  test(
    'failed next page preserves items and retries the same cursor',
    () async {
      var fail = true;
      final api = FakeBankApi()
        ..historyHandler =
            ({accountId, required filter, cursor, required pageSize}) async {
              if (cursor == null) {
                return TransactionPage(
                  items: [sampleTransaction('one')],
                  nextCursor: 'next',
                );
              }
              if (fail) throw StateError('offline');
              return TransactionPage(items: [sampleTransaction('two')]);
            };
      final controller = HistoryController(api);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.items.single.id, 'one');
      expect(controller.error, isNotNull);
      fail = false;
      await controller.loadMore();
      expect(controller.items.length, 2);
      expect(api.historyCalls.skip(1).map((call) => call.cursor), [
        'next',
        'next',
      ]);
    },
  );

  test(
    'date grouping uses local calendar days and includes previous years',
    () {
      final now = DateTime(2026, 11, 3, 1);
      expect(dayLabel(DateTime(2026, 11, 3), now: now), BankingStrings.today);
      expect(
        dayLabel(DateTime(2026, 11, 2, 23), now: now),
        BankingStrings.yesterday,
      );
      expect(dayLabel(DateTime(2025, 10, 12), now: now), '12 Oct 2025');
      expect(dayLabel(DateTime(2026, 10, 12), now: now), '12 Oct');
    },
  );

  testWidgets('activity shows empty state and sends the selected filter', (
    tester,
  ) async {
    final api = FakeBankApi();
    await pumpBanking(tester, const ActivityScreen(), api);
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.noActivity), findsOneWidget);
    await tester.tap(find.text(BankingStrings.sent));
    await tester.pumpAndSettle();
    expect(api.historyCalls.last.filter, 'sent');
  });

  testWidgets('activity retries initial errors', (tester) async {
    var fail = true;
    final api = FakeBankApi()
      ..historyHandler =
          ({accountId, required filter, cursor, required pageSize}) async {
            if (fail) throw StateError('offline');
            return TransactionPage(items: [sampleTransaction('one')]);
          };
    await pumpBanking(tester, const ActivityScreen(), api);
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.cannotLoad), findsOneWidget);
    fail = false;
    await tester.tap(find.text(BankingStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionRow), findsOneWidget);
  });

  testWidgets('scrolling loads the next history page only once', (
    tester,
  ) async {
    final api = FakeBankApi()
      ..historyHandler =
          ({accountId, required filter, cursor, required pageSize}) async =>
              cursor == null
              ? TransactionPage(
                  items: List.generate(
                    20,
                    (index) => sampleTransaction('item-$index'),
                  ),
                  nextCursor: 'next',
                )
              : TransactionPage(items: [sampleTransaction('last')]);
    await pumpBanking(tester, const ActivityScreen(), api);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(
      api.historyCalls.where((call) => call.cursor == 'next'),
      hasLength(1),
    );
    expect(find.byType(TransactionRow), findsNWidgets(21));
  });

  testWidgets('account history scopes every request to its account', (
    tester,
  ) async {
    final api = FakeBankApi()
      ..historyHandler =
          ({accountId, required filter, cursor, required pageSize}) async =>
              TransactionPage(
                items: [sampleTransaction('usd-transfer', currency: 'USD')],
              );
    await pumpBanking(tester, const AccountScreen(accountId: 'usd'), api);
    await tester.pumpAndSettle();
    expect(find.text('USD account'), findsOneWidget);
    expect(api.historyCalls.single.accountId, 'usd');
    await tester.tap(find.text(BankingStrings.convert));
    await tester.pumpAndSettle();
    expect(find.text('/convert?currency=USD'), findsOneWidget);
  });
}
