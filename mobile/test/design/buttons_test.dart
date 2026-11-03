import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/buttons.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  final builders = <String, Widget Function(VoidCallback?, bool)>{
    'primary': (callback, loading) => PrimaryButton(
      label: 'Send money',
      onPressed: callback,
      isLoading: loading,
    ),
    'secondary': (callback, loading) => SecondaryButton(
      label: 'Send money',
      onPressed: callback,
      isLoading: loading,
    ),
    'text': (callback, loading) => TetriTextButton(
      label: 'Send money',
      onPressed: callback,
      isLoading: loading,
    ),
  };

  for (final entry in builders.entries) {
    testWidgets('${entry.key} uses a static loading mark with reduced motion', (
      tester,
    ) async {
      await pumpTetri(
        tester,
        entry.value(() {}, true),
        disableAnimations: true,
      );
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.value, TetriProgress.indeterminateFallback);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      '${entry.key} keeps its width while loading and blocks duplicate taps',
      (tester) async {
        var taps = 0;
        await pumpTetri(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: entry.value(() => taps++, false),
          ),
        );
        final button = find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        );
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(TetriSizes.tap48));
        expect(size.height, greaterThanOrEqualTo(TetriSizes.tap48));
        await tester.tap(button);
        expect(taps, 1);

        await pumpTetri(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: entry.value(() => taps++, true),
          ),
        );
        expect(tester.getSize(button), size);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(button);
        expect(taps, 1);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Send money'), findsWidgets);
        semantics.dispose();
      },
    );

    testWidgets(
      '${entry.key} disabled control cannot fire and remains legible in dark mode',
      (tester) async {
        await pumpTetri(
          tester,
          entry.value(null, false),
          brightness: Brightness.dark,
        );
        final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        );
        expect(button.onPressed, isNull);
        expect(
          button.style!.foregroundColor!.resolve({WidgetState.disabled}),
          TetriColors.dark.textDisabled,
        );
        expect(find.text('Send money'), findsOneWidget);
      },
    );
  }
}
