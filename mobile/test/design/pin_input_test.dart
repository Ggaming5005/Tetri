import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/design/components/pin_input.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'PIN input accepts four ASCII digits and preserves leading zero',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpTetri(
        tester,
        PinInput(label: AuthStrings.appPin, controller: controller),
      );
      await tester.enterText(find.byType(TextField), '0a5.7-29');
      expect(controller.text, '0572');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.enableInteractiveSelection, isFalse);
    },
  );

  testWidgets('PIN semantics exposes its label and masks the secret', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '0572');
    addTearDown(controller.dispose);
    try {
      await pumpTetri(
        tester,
        PinInput(label: AuthStrings.appPin, controller: controller),
      );
      final node = tester.getSemantics(find.byType(TextField));
      expect(node.getSemanticsData().value, isNot(contains('0572')));
      expect(find.bySemanticsLabel(AuthStrings.appPin), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('PIN label and error fit 320 dp at 2x in ${brightness.name}', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpTetri(
        tester,
        PinInput(
          label: AuthStrings.appPin,
          controller: controller,
          errorText: AuthStrings.pinMismatch,
          enabled: false,
        ),
        brightness: brightness,
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AuthStrings.pinMismatch), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
    });
  }
}
