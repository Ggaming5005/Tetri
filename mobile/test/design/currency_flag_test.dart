import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/currency_flag.dart';
import 'package:tetri/design/currency_flag_tokens.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  for (final currency in ['GEL', 'USD', 'EUR']) {
    testWidgets('$currency is rendered without a platform font', (
      tester,
    ) async {
      await pumpTetri(tester, CurrencyFlag(currency: currency));
      expect(
        find.descendant(
          of: find.byType(CurrencyFlag),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(CurrencyFlag)),
        const Size.square(TetriSizes.currencyFlag40),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(CurrencyFlag),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CurrencyFlagPainter;
      expect(painter.currency, currency);
    });
  }

  test('flag art clips its corners and paints country colors', () async {
    for (final entry in {
      'GEL': CurrencyFlagTokens.georgiaRed,
      'USD': CurrencyFlagTokens.usRed,
      'EUR': CurrencyFlagTokens.euBlue,
    }.entries) {
      final recorder = ui.PictureRecorder();
      CurrencyFlagPainter(entry.key)
          .paint(Canvas(recorder), const Size.square(100));
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      final pixels = (await image.toByteData())!;
      expect(pixels.getUint8(3), 0);
      final expected = entry.value.toARGB32();
      var matches = 0;
      for (var index = 0; index < pixels.lengthInBytes; index += 4) {
        if (pixels.getUint8(index) == ((expected >> 16) & 255) &&
            pixels.getUint8(index + 1) == ((expected >> 8) & 255) &&
            pixels.getUint8(index + 2) == (expected & 255) &&
            pixels.getUint8(index + 3) == 255) {
          matches++;
        }
      }
      expect(matches, greaterThan(100));
      image.dispose();
      picture.dispose();
    }
  });
}
