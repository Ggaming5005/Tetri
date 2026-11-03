import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:tetri/design/components/text_input.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'plain input has label, accessible placeholder and focus outline',
    (tester) async {
      String? value;
      await pumpTetri(
        tester,
        TextInput(
          label: 'Email',
          hint: 'you@example.com',
          onChanged: (text) => value = text,
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.decoration!.hintStyle!.color, TetriColors.light.placeholder);
      expect(
        (input.decoration!.enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
      expect(
        input.decoration!.focusedBorder!.borderSide.color,
        TetriColors.light.accent,
      );
      expect(
        input.decoration!.focusedBorder!.borderSide.width,
        TetriSizes.focusBorderWidth,
      );
      await tester.enterText(find.byType(TextField), 'nino@example.com');
      expect(value, 'nino@example.com');
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
    },
  );

  testWidgets(
    'password is hidden initially and show/hide stays a 48 point target',
    (tester) async {
      await pumpTetri(
        tester,
        const TextInput(label: 'Password', variant: TextInputVariant.password),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      final toggle = find.byType(IconButton);
      expect(
        tester.getSize(toggle).width,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      expect(
        tester.getSize(toggle).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
    },
  );

  testWidgets(
    'search and error variants use the shared icon and error styling',
    (tester) async {
      await pumpTetri(
        tester,
        const TextInput(
          label: 'Find a recipient',
          variant: TextInputVariant.search,
          errorText: 'Enter a handle.',
        ),
        brightness: Brightness.dark,
      );
      expect(find.byIcon(PhosphorIconsRegular.magnifyingGlass), findsOneWidget);
      expect(find.text('Enter a handle.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .decoration!
            .errorStyle!
            .color,
        TetriColors.dark.negative,
      );
    },
  );

  testWidgets('disabled password input cannot edit or reveal its value', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'a secret');
    addTearDown(controller.dispose);
    await pumpTetri(
      tester,
      TextInput(
        label: 'Password',
        controller: controller,
        variant: TextInputVariant.password,
        enabled: false,
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(controller.text, 'a secret');
  });

  testWidgets(
    'input forwards formatters, keyboard actions and submit callback',
    (tester) async {
      String? submitted;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpTetri(
        tester,
        TextInput(
          label: 'Code',
          controller: controller,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (text) => submitted = text,
        ),
      );
      await tester.enterText(find.byType(TextField), 'a123');
      expect(controller.text, '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, '123');
    },
  );
}
