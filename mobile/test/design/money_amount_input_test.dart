import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/money_amount_input.dart';

import '../helpers/pump_tetri.dart';

void main() {
  const formatter = MoneyAmountFormatter();
  TextEditingValue edit(String text, {int? caret}) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );

  test(
    'native edits preserve exact cents through the signed 64-bit maximum',
    () {
      for (final sample in {
        '': '',
        '.': '0.',
        '.5': '0.5',
        ',': '0.',
        '1,25': '1.25',
        '000': '0',
        '00012.30': '12.30',
        '1.': '1.',
        '92233720368547758.07': '92233720368547758.07',
      }.entries) {
        final result = formatter.formatEditUpdate(edit(''), edit(sample.key));
        expect(result.text, sample.value);
        expect(result.selection.baseOffset, sample.value.length);
      }
      expect(
        MoneyInput.minorUnits('92233720368547758.07'),
        9223372036854775807,
      );
      expect(MoneyInput.minorUnits('0.01'), 1);
    },
  );

  test(
    'native edits reject signed, exponent, third decimal and overflow inputs',
    () {
      final original = edit('12.34', caret: 2);
      for (final invalid in [
        '-1',
        '+1',
        '1e3',
        '1E3',
        '1.234',
        '1..2',
        '1,234.56',
        ' 1',
        '1 ',
        'NaN',
        '92233720368547758.08',
        '999999999999999999999999999999999999',
      ]) {
        expect(
          formatter.formatEditUpdate(original, edit(invalid)),
          original,
          reason: invalid,
        );
      }
    },
  );

  test('replacement, deletion and mid-string edits preserve the cursor', () {
    final replacement = formatter.formatEditUpdate(
      edit('12.34'),
      edit('1.34', caret: 1),
    );
    expect(replacement.text, '1.34');
    expect(replacement.selection.baseOffset, 1);
    final fraction = formatter.formatEditUpdate(
      edit('1.34'),
      edit('1.94', caret: 3),
    );
    expect(fraction.selection.baseOffset, 3);
    expect(formatter.formatEditUpdate(fraction, edit('')).text, '');
  });

  testWidgets(
    'amount field uses a native decimal keyboard and exact editable text',
    (tester) async {
      var value = '';
      await pumpTetri(
        tester,
        StatefulBuilder(
          builder: (context, setState) => MoneyAmountInput(
            value: value,
            currency: 'USD',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      final field = find.byType(TextField);
      final widget = tester.widget<TextField>(field);
      expect(
        widget.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(widget.textInputAction, TextInputAction.done);
      await tester.enterText(field, '00010,25');
      await tester.pump();
      expect(value, '10.25');
      expect(MoneyInput.minorUnits(value), 1025);
      await tester.enterText(field, '10.256');
      await tester.pump();
      expect(value, '10.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
    },
  );

  testWidgets(
    'external amount resets replace editable value and disabled input stays inactive',
    (tester) async {
      var changes = 0;
      await pumpTetri(
        tester,
        MoneyAmountInput(
          value: '12.34',
          currency: 'GEL',
          onChanged: (_) => changes++,
        ),
      );
      await pumpTetri(
        tester,
        MoneyAmountInput(
          value: '',
          currency: 'EUR',
          enabled: false,
          onChanged: (_) => changes++,
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '');
      expect(field.enabled, isFalse);
      expect(changes, 0);
    },
  );

  testWidgets(
    'large native input remains scrollable at narrow width and large text',
    (tester) async {
      await pumpTetri(
        tester,
        MoneyAmountInput(
          value: '92233720368547758.07',
          currency: 'USD',
          onChanged: (_) {},
          errorText: 'Enter a smaller amount.',
        ),
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
      );
      expect(find.text('Enter a smaller amount.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
