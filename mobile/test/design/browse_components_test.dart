import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/account_card.dart';
import 'package:tetri/design/components/avatar.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/design/components/skeleton.dart';
import 'package:tetri/design/components/tetri_scaffold.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/banking_fakes.dart';
import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'account pager and reference remain readable at large text on a small phone',
    (tester) async {
      await pumpTetri(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              AccountPager(accounts: sampleAccounts, onSelected: (_) {}),
              const ReferenceCopy(
                reference: '019ad36f-0942-7aa2-b613-85b917a3f719',
              ),
            ],
          ),
        ),
        textScaler: const TextScaler.linear(3),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(BankingStrings.copyReference));
      expect(
        find.text(BankingStrings.copyReference).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'headings, date section, detail row and profile use reusable text',
    (tester) async {
      await pumpTetri(
        tester,
        const Column(
          children: [
            PageHeading(title: 'Your account', subtitle: 'GEL'),
            SectionHeading(title: 'Details'),
            DateSection(
              title: 'Today',
              children: [DetailLine(label: 'Status', value: 'Posted')],
            ),
            ProfileSummary(
              userId: 'u',
              name: 'Nino K.',
              handle: '@nino',
              email: 'nino@example.test',
            ),
          ],
        ),
      );
      for (final text in [
        'Your account',
        'GEL',
        'Details',
        'Today',
        'Status',
        'Posted',
        '@nino',
        'nino@example.test',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(tester.widget<Avatar>(find.byType(Avatar)).userId, 'u');
    },
  );

  testWidgets('section actions and page retry invoke their callbacks', (
    tester,
  ) async {
    var actions = 0;
    await pumpTetri(
      tester,
      Column(
        children: [
          SectionHeading(
            title: 'Activity',
            actionLabel: 'See all',
            onAction: () => actions++,
          ),
          PageMessage(
            message: 'Try again',
            actionLabel: 'Retry',
            onAction: () => actions++,
          ),
        ],
      ),
    );
    await tester.tap(find.text('See all'));
    await tester.tap(find.text('Retry'));
    expect(actions, 2);
  });

  testWidgets('loading list is three skeletons and respects reduced motion', (
    tester,
  ) async {
    await pumpTetri(tester, const LoadingList(), disableAnimations: true);
    expect(find.byType(Skeleton), findsNWidgets(3));
    await tester.pumpAndSettle();
  });

  testWidgets('round action includes label in its tap and semantic target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpTetri(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: RoundAction(
          icon: PhosphorIconsRegular.arrowUpRight,
          label: 'Send',
          onTap: () => taps++,
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(RoundAction)).width,
      greaterThanOrEqualTo(TetriSizes.tap48),
    );
    await tester.tap(find.text('Send'));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.byType(RoundAction)),
      matchesSemantics(
        label: 'Send',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('account pager can swipe and choose a different currency', (
    tester,
  ) async {
    String? chosen;
    await pumpTetri(
      tester,
      AccountPager(
        accounts: sampleAccounts,
        onSelected: (account) => chosen = account.currency,
      ),
    );
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    final usd = find.byWidgetPredicate(
      (widget) => widget is AccountCard && widget.account.currency == 'USD',
    );
    await tester.tap(usd);
    expect(chosen, 'USD');
  });

  testWidgets(
    'bottom navigation routes to activity with an accessible target',
    (tester) async {
      await pumpBanking(
        tester,
        const TetriScaffold(
          bottomNavigationBar: TetriNavigation(selectedIndex: 0),
          child: Text('Body'),
        ),
        FakeBankApi(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(BankingStrings.activity));
      await tester.pumpAndSettle();
      expect(find.text('/activity'), findsOneWidget);
    },
  );

  testWidgets('back button returns to home when no page can pop', (
    tester,
  ) async {
    await pumpBanking(
      tester,
      const TetriScaffold(child: BrowseBackButton()),
      FakeBankApi(),
    );
    await tester.tap(find.text(BankingStrings.back));
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);
  });
}
