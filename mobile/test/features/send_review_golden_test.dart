import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/review_sheet.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/golden_fonts.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Send review golden ${brightness.name}', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = brightness == Brightness.light
          ? TetriColors.light
          : TetriColors.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? TetriTheme.light
              : TetriTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('send-review'),
              child: Scaffold(
                backgroundColor: colors.surface,
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: colors.surfaceRaised,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TetriRadii.r24),
                    ),
                    child: MoneyReviewSheet(
                      title: MoneyStrings.reviewSend,
                      rows: const [
                        ReviewLine.text(MoneyStrings.to, '@nino'),
                        ReviewLine.money(
                          MoneyStrings.amount,
                          Money(2500, 'GEL'),
                        ),
                        ReviewLine.money(MoneyStrings.fee, Money(0, 'GEL')),
                        ReviewLine.money(
                          MoneyStrings.total,
                          Money(2500, 'GEL'),
                        ),
                      ],
                      confirmLabel: MoneyStrings.sendConfirm,
                      onConfirm: () {},
                      onEdit: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settleTetriGolden(tester);
      await expectLater(
        find.byKey(const ValueKey('send-review')),
        matchesGoldenFile('goldens/send_review_${brightness.name}.png'),
      );
    });
  }
}
