import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/buttons.dart';
import 'package:tetri/design/components/currency_picker.dart';
import 'package:tetri/design/components/review_sheet.dart';
import 'package:tetri/design/components/selection_controls.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/banking_fakes.dart';
import '../helpers/pump_tetri.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 360.0, 430.0]) {
    testWidgets(
      'long buttons grow at $width with enlarged text without changing size while loading',
      (tester) async {
        var loading = false;
        StateSetter? rebuild;
        await pumpTetri(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PrimaryButton(
                  label: 'Confirm this currency conversion',
                  onPressed: () {},
                  isLoading: loading,
                );
              },
            ),
          ),
          size: Size(width, 800),
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        );
        final button = find.byType(FilledButton);
        final initialSize = tester.getSize(button);
        expect(initialSize.height, greaterThan(TetriSizes.button56));
        expect(
          tester.getSize(find.text('Confirm this currency conversion')).width,
          lessThanOrEqualTo(initialSize.width - TetriSpace.x24 * 2),
        );
        expect(tester.takeException(), isNull);
        rebuild!(() => loading = true);
        await tester.pumpAndSettle();
        expect(tester.getSize(button), initialSize);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  }

  testWidgets(
    'compact currency picker keeps the 48 point target without repeating its balance',
    (tester) async {
      await pumpTetri(
        tester,
        CurrencyPicker(
          accounts: sampleAccounts,
          selected: sampleAccounts.first,
          compact: true,
          onChanged: (_) {},
        ),
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(2),
      );
      expect(
        tester.getSize(find.byType(CurrencyPicker)).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      expect(find.byType(AmountText), findsNothing);
      expect(find.text('GEL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'activity filters stay selectable at 320 and text scale $scale',
      (tester) async {
        String? chosen;
        await pumpTetri(
          tester,
          TetriFilterBar<String>(
            filters: const {
              'all': 'All',
              'sent': 'Sent',
              'received': 'Received',
              'conversions': 'Conversions',
            },
            value: 'all',
            onChanged: (value) => chosen = value,
          ),
          size: const Size(320, 640),
          textScaler: TextScaler.linear(scale),
        );
        final scroll = find.descendant(
          of: find.byType(TetriFilterBar<String>),
          matching: find.byType(SingleChildScrollView),
        );
        if (scale == 1) {
          expect(scroll, findsOneWidget);
          await tester.drag(scroll, const Offset(-400, 0));
          await tester.pumpAndSettle();
        } else {
          expect(scroll, findsNothing);
        }
        await tester.tap(find.text('Conversions'));
        expect(chosen, 'conversions');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'review keeps exact values and reachable confirmation above a keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var confirmations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: TetriTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 240),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              resizeToAvoidBottomInset: false,
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => ReviewSheet(
                    title: 'Review conversion',
                    rows: const [
                      ReviewLine.text('To', 'Alexandra Longlastname'),
                      ReviewLine.money('Amount', Money(123456, 'USD')),
                      ReviewLine.money('You get', Money(331724, 'GEL')),
                    ],
                    confirmLabel: 'Confirm conversion',
                    onConfirm: () => confirmations++,
                  ),
                ),
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widgetList<AmountText>(find.byType(AmountText))
            .map((widget) => widget.amount),
        containsAll([const Money(123456, 'USD'), const Money(331724, 'GEL')]),
      );
      await tester.ensureVisible(find.text('Confirm conversion'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Confirm conversion')).bottom,
        lessThanOrEqualTo(400),
      );
      await tester.tap(find.text('Confirm conversion'));
      await tester.pump();
      expect(confirmations, 1);
    },
  );
}
