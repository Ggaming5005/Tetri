import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/transaction_row.dart';
import 'package:tetri/design/tokens.dart';
import 'package:tetri/design/typography.dart';

import '../helpers/golden_fonts.dart';
import '../helpers/pump_tetri.dart';

void main() {
  testWidgets('ordinary amount retains its side-by-side layout when it fits', (
    tester,
  ) async {
    await pumpTetri(
      tester,
      const TransactionRow(
        title: 'To Nino',
        subtitle: '14:05',
        amount: Money(-2500, 'GEL'),
      ),
    );
    await settleTetriGolden(tester);
    final title = tester.getRect(find.text('To Nino'));
    final amount = tester.getRect(find.byType(AmountText));
    expect(amount.left, greaterThan(title.right));
    expect(amount.top, lessThan(title.bottom));
    expect(
      find.descendant(
        of: find.byType(TransactionRow),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'a long amount gets the full row width instead of the half-width slot',
    (tester) async {
      const money = Money(-9223372036854775807, 'GEL');
      await pumpTetri(
        tester,
        const TransactionRow(
          title: 'To Nino',
          subtitle: '14:05',
          amount: money,
        ),
        size: const Size(320, 640),
      );
      await settleTetriGolden(tester);
      final row = tester.getRect(find.byType(TransactionRow));
      final amount = tester.getRect(find.byType(AmountText));
      final oldSlotWidth =
          (row.width - TetriSizes.tap48 - TetriSpace.x12 * 2) / 2;
      expect(amount.width, greaterThan(oldSlotWidth));
      expect(
        amount.top,
        greaterThan(tester.getRect(find.text('14:05')).bottom),
      );
      expect(
        find.text(MoneyFormat.format(money), findRichText: true),
        findsOneWidget,
      );
      expect(amount.right, lessThanOrEqualTo(row.right));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320 dp with 2x text preserves extreme amount scale and scrolls every digit',
    (tester) async {
      const money = Money(-9223372036854775807, 'USD');
      final semantics = tester.ensureSemantics();
      await pumpTetri(
        tester,
        const TransactionRow(
          title: 'To Nino',
          subtitle: '14:05',
          amount: money,
        ),
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
      );
      await settleTetriGolden(tester);
      final amount = find.byType(AmountText);
      final richText = find.descendant(
        of: amount,
        matching: find.byType(RichText),
      );
      final fitted = find.descendant(
        of: amount,
        matching: find.byType(FittedBox),
      );
      final scroll = find.descendant(
        of: find.byType(TransactionRow),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      expect(
        tester.getSize(richText).width,
        greaterThan(tester.getSize(scroll).width),
      );
      expect(tester.getSize(fitted), tester.getSize(richText));
      expect(
        tester.getSize(richText).height,
        greaterThanOrEqualTo(
          TetriTypography.body.fontSize! * TetriTypography.body.height! * 2,
        ),
      );
      expect(
        find.text(MoneyFormat.format(money), findRichText: true),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(MoneyFormat.semantics(money, showSign: true)),
        findsOneWidget,
      );
      await tester.drag(scroll, const Offset(-1000, 0));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
