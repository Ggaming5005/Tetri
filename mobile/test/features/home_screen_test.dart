import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/account_card.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/features/home/home_screen.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/banking_fakes.dart';
import '../helpers/golden_fonts.dart';

void main() {
  testWidgets(
    'profile opens settings from the Home heading with an accessible target',
    (tester) async {
      await pumpBanking(
        tester,
        const HomeScreen(),
        FakeBankApi(),
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      final profile = find.byTooltip(BankingStrings.profile);
      expect(profile.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(profile).width,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      expect(
        tester.getSize(profile).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      expect(
        find.descendant(
          of: find.byType(TetriNavigation),
          matching: find.text(BankingStrings.settings),
        ),
        findsNothing,
      );
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(find.text('/settings'), findsOneWidget);
    },
  );

  testWidgets(
    'home fits a small phone with enlarged text and accessible navigation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBanking(
        tester,
        const HomeScreen(),
        FakeBankApi(),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final activity = find.bySemanticsLabel(BankingStrings.activity);
      expect(
        tester.getSemantics(activity),
        matchesSemantics(
          label: BankingStrings.activity,
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets('home shows skeletons while initial data is pending', (
    tester,
  ) async {
    final pending = Completer<AuthUser>();
    final api = FakeBankApi()..profileHandler = () => pending.future;
    await pumpBanking(tester, const HomeScreen(), api);
    expect(find.byType(LoadingList), findsWidgets);
    expect(
      find.byTooltip(BankingStrings.profile).hitTestable(),
      findsOneWidget,
    );
    pending.complete(sampleUser);
    await tester.pumpAndSettle();
    expect(find.text('Hello, Nino'), findsOneWidget);
  });

  testWidgets('home retries failed reads and handles empty accounts', (
    tester,
  ) async {
    var failed = true;
    final api = FakeBankApi()
      ..accountsHandler = () async {
        if (failed) throw StateError('offline');
        return [];
      };
    await pumpBanking(tester, const HomeScreen(), api);
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.cannotLoad), findsOneWidget);
    expect(
      find.byTooltip(BankingStrings.profile).hitTestable(),
      findsOneWidget,
    );
    failed = false;
    await tester.tap(find.text(BankingStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.noAccounts), findsOneWidget);
  });

  testWidgets(
    'rates failure preserves account actions and explains unavailable total',
    (tester) async {
      final api = FakeBankApi()
        ..ratesHandler = () async => throw StateError('no rates');
      await pumpBanking(tester, const HomeScreen(), api);
      await tester.pumpAndSettle();
      expect(find.text(BankingStrings.totalUnavailable), findsOneWidget);
      expect(find.byType(AccountCard), findsWidgets);
      expect(find.byType(RoundAction), findsNWidgets(2));
      await tester.ensureVisible(find.text(BankingStrings.send));
      await tester.tap(find.text(BankingStrings.send));
      await tester.pumpAndSettle();
      expect(find.text('/send?currency=GEL'), findsOneWidget);
    },
  );

  for (final action in {
    BankingStrings.send: '/send?currency=USD',
    BankingStrings.convert: '/convert?currency=USD',
  }.entries) {
    testWidgets('${action.key} uses the account selected by swiping', (
      tester,
    ) async {
      await pumpBanking(tester, const HomeScreen(), FakeBankApi());
      await tester.pumpAndSettle();
      final pager = find.descendant(
        of: find.byType(AccountPager),
        matching: find.byType(PageView),
      );
      await tester.ensureVisible(pager);
      await tester.pumpAndSettle();
      await tester.drag(pager, Offset(-tester.getSize(pager).width * 0.9, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('account-page-position')),
            )
            .properties
            .label,
        '${BankingStrings.account} 2/3, USD',
      );
      await tester.ensureVisible(find.text(action.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action.key));
      await tester.pumpAndSettle();
      expect(find.text(action.value), findsOneWidget);
    });
  }

  testWidgets('home displays exact total and requests only five recent items', (
    tester,
  ) async {
    final api = FakeBankApi();
    await pumpBanking(tester, const HomeScreen(), api);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<AmountText>(find.byType(AmountText))
          .any((amount) => amount.amount.minor == 271000),
      isTrue,
    );
    expect(api.historyCalls.single.pageSize, 5);
    expect(find.text(BankingStrings.noActivity), findsOneWidget);
    await tester.tap(find.byType(AccountCard).first);
    await tester.pumpAndSettle();
    expect(find.text('/accounts/gel'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Home golden ${brightness.name}', (tester) async {
      final api = FakeBankApi()
        ..historyHandler = ({
          accountId,
          required filter,
          cursor,
          required pageSize,
        }) async => TransactionPage(items: [sampleTransaction('sample')]);
      await pumpBanking(
        tester,
        const HomeScreen(),
        api,
        brightness: brightness,
      );
      await settleTetriGolden(tester);
      await expectLater(
        find.byKey(const ValueKey('banking-screen')),
        matchesGoldenFile('goldens/home_${brightness.name}.png'),
      );
    });
  }
}
