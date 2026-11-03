import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:tetri/design/components/navigation_action.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets('navigation action is one labelled accessible tap target', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    try {
      await pumpTetri(
        tester,
        NavigationAction(
          icon: PhosphorIconsRegular.paperPlaneTilt,
          title: 'Send money',
          description: 'To another Tetri account.',
          onTap: () => taps++,
        ),
      );
      final target = find.bySemanticsLabel('Send money');
      expect(target, findsOneWidget);
      expect(
        tester.getSemantics(target),
        matchesSemantics(
          label: 'Send money',
          hint: 'To another Tetri account.',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSize(find.byType(NavigationAction)).height,
        greaterThanOrEqualTo(TetriSizes.tap),
      );
      await tester.tap(find.text('Send money'));
      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });
}
