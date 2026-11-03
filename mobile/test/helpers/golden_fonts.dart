import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void>? _phosphorFont;

Future<void> settleTetriGolden(WidgetTester tester) async {
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts();
    _phosphorFont ??=
        (FontLoader('packages/phosphor_glyphs/Phosphor-Regular')..addFont(
              rootBundle.load(
                'packages/phosphor_glyphs/fonts/Phosphor-Regular.ttf',
              ),
            ))
            .load();
    await _phosphorFont;
  });
  await tester.pumpAndSettle();
}
