import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/content.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'content typography uses readable semantic colors in each theme',
    (tester) async {
      for (final brightness in Brightness.values) {
        await pumpTetri(
          tester,
          const TetriText('Clear copy', secondary: true),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text('Clear copy'));
        expect(
          text.style!.color,
          brightness == Brightness.dark
              ? TetriColors.dark.textSecondary
              : TetriColors.light.textSecondary,
        );
      }
    },
  );

  testWidgets('auth header exposes its back action and subtitle', (
    tester,
  ) async {
    var wentBack = false;
    await pumpTetri(
      tester,
      AuthHeader(
        title: 'Your name',
        subtitle: 'A short introduction',
        onBack: () => wentBack = true,
      ),
    );
    await tester.tap(find.byTooltip('Back'));
    expect(wentBack, isTrue);
    expect(find.text('A short introduction'), findsOneWidget);
  });

  testWidgets('progress announces current step and draws the completed count', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpTetri(tester, const StepProgress(current: 2, total: 4));
    expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);
    final blocks = tester
        .widgetList<Container>(find.byType(Container))
        .where((box) => box.decoration is BoxDecoration);
    expect(
      blocks
          .where(
            (box) =>
                (box.decoration! as BoxDecoration).color ==
                TetriColors.light.accent,
          )
          .length,
      2,
    );
    semantics.dispose();
  });
}
