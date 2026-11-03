import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/core/strings.dart';
import 'package:tetri/design/component_gallery.dart';
import 'package:tetri/design/components/review_sheet.dart';
import 'package:tetri/design/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('gallery and review fit a small phone in $brightness', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? TetriTheme.light
              : TetriTheme.dark,
          home: ComponentGallery(
            themeMode: ThemeMode.system,
            onThemeChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 11; index++) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -500),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
      // The gallery eagerly builds its column, so scroll to an actual hit target.
      for (
        var index = 0;
        index < 20 &&
            find
                .text(TetriStrings.sendMoney)
                .first
                .hitTestable()
                .evaluate()
                .isEmpty;
        index++
      ) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, 400),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text(TetriStrings.sendMoney).first.hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text(TetriStrings.sendMoney).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReviewSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
