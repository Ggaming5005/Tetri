import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/brand.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'wordmark and supported currencies render without network assets',
    (tester) async {
      await pumpTetri(tester, const TetriWordmark());
      expect(find.text('Tetri'), findsOneWidget);
      await pumpTetri(tester, const TetriCurrencies());
      await tester.pumpAndSettle();
      for (final currency in ['GEL', 'USD', 'EUR']) {
        expect(find.text(currency), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
