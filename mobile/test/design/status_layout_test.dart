import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/status_view.dart';
import 'package:tetri/design/components/tetri_scaffold.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';

void main() {
  for (final geometry in [
    (size: const Size(360, 800), scale: 1.0),
    (size: const Size(320, 640), scale: 2.0),
    (size: const Size(640, 320), scale: 2.0),
  ]) {
    for (final success in [true, false]) {
      testWidgets(
        '${success ? 'success' : 'pending'} result centers or scrolls at ${geometry.size} and ${geometry.scale}x text',
        (tester) async {
          GoogleFonts.config.allowRuntimeFetching = false;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = geometry.size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var actions = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: TetriTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: geometry.size,
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  textScaler: TextScaler.linear(geometry.scale),
                ),
                child: TetriScaffold(
                  fillViewport: true,
                  child: StatusView(
                    title: success ? 'Sent' : 'Check the result',
                    amount: const Money(2500, 'GEL'),
                    message: success ? 'To Nino' : 'We could not confirm the result yet. Retry to check this same payment.',
                    actionLabel: success ? 'Done' : 'Retry',
                    isSuccess: success,
                    isPending: !success,
                    onAction: () => actions++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final summary = find.byKey(const ValueKey('status-summary'));
          final action = find.byKey(const ValueKey('status-action'));
          if (geometry.scale == 1) {
            final viewport = tester.getRect(find.byType(StatusView));
            final actionRect = tester.getRect(action);
            final summaryRect = tester.getRect(summary);
            expect(
              actionRect.bottom,
              closeTo(geometry.size.height - 16 - TetriSpace.x24, 0.01),
            );
            expect(
              summaryRect.center.dy,
              closeTo(
                (viewport.top + actionRect.top - TetriSpace.x24) / 2,
                0.01,
              ),
            );
            expect(
              summaryRect.center.dx,
              closeTo(geometry.size.width / 2, 0.01),
            );
            expect(action.hitTestable(), findsOneWidget);
          }
          expect(find.byType(AmountText), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          expect(actions, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
