import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/brand.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets('wordmark and original artwork render from local assets', (
    tester,
  ) async {
    await pumpTetri(tester, const TetriWordmark());
    expect(find.text('Tetri'), findsOneWidget);
    await pumpTetri(tester, const TetriArtwork());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
