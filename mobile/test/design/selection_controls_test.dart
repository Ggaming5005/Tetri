import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/design/components/selection_controls.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets(
    'switch updates its value, uses accent and exposes a 48 point target',
    (tester) async {
      var enabled = false;
      await pumpTetri(
        tester,
        StatefulBuilder(
          builder: (context, setState) => TetriSwitch(
            label: 'Biometric unlock',
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(TetriSwitch)).height,
        greaterThanOrEqualTo(TetriSizes.tap48),
      );
      await tester.tap(find.byType(TetriSwitch));
      await tester.pump();
      expect(enabled, isTrue);
      expect(
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byType(TetriSwitch),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        TetriColors.light.accent,
      );
    },
  );

  testWidgets('disabled switch remains unchanged', (tester) async {
    await pumpTetri(
      tester,
      const TetriSwitch(
        label: 'Biometric unlock',
        value: true,
        onChanged: null,
      ),
    );
    expect(
      tester.widget<TetriSwitch>(find.byType(TetriSwitch)).onChanged,
      isNull,
    );
    await tester.tap(find.byType(TetriSwitch));
    expect(tester.widget<TetriSwitch>(find.byType(TetriSwitch)).value, isTrue);
  });

  testWidgets('reduced motion switches immediately and announces its value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    await pumpTetri(
      tester,
      StatefulBuilder(
        builder: (context, setState) => TetriSwitch(
          label: 'Biometric unlock',
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
      ),
      disableAnimations: true,
    );
    await tester.tap(find.byType(TetriSwitch));
    await tester.pump();
    final alignment = tester.widget<AnimatedAlign>(
      find.descendant(
        of: find.byType(TetriSwitch),
        matching: find.byType(AnimatedAlign),
      ),
    );
    expect(alignment.duration, Duration.zero);
    expect(alignment.alignment, Alignment.centerRight);
    expect(
      tester.getSemantics(find.byType(TetriSwitch)),
      matchesSemantics(
        label: 'Biometric unlock',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets(
    'segmented control changes exactly one selection with accessible targets',
    (tester) async {
      var value = 'system';
      await pumpTetri(
        tester,
        StatefulBuilder(
          builder: (context, setState) => TetriSegmentedControl<String>(
            segments: const {
              'system': 'System',
              'light': 'Light',
              'dark': 'Dark',
            },
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(value, 'dark');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'dark'},
      );
      final buttons = find.descendant(
        of: find.byType(SegmentedButton<String>),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(3));
      for (final element in buttons.evaluate()) {
        final size = tester.getSize(
          find.byElementPredicate((candidate) => candidate == element),
        );
        expect(size.height, greaterThanOrEqualTo(TetriSizes.tap48));
        expect(size.width, greaterThanOrEqualTo(TetriSizes.tap48));
      }
    },
  );

  testWidgets('disabled segmented control has no selection callback', (
    tester,
  ) async {
    await pumpTetri(
      tester,
      const TetriSegmentedControl<String>(
        segments: {'all': 'All', 'sent': 'Sent'},
        value: 'all',
        onChanged: null,
      ),
    );
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .onSelectionChanged,
      isNull,
    );
  });

  testWidgets('filter chip can be selected with a 48 point target', (
    tester,
  ) async {
    var selected = false;
    await pumpTetri(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: StatefulBuilder(
          builder: (context, setState) => TetriFilterChip(
            label: 'Sent',
            selected: selected,
            onSelected: (next) => setState(() => selected = next),
          ),
        ),
      ),
    );
    final chip = find.byType(FilterChip);
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(TetriSizes.tap48));
    await tester.tap(chip);
    await tester.pump();
    expect(selected, isTrue);
    expect(
      tester.widget<FilterChip>(chip).labelStyle!.color,
      TetriColors.light.accentText,
    );
  });

  testWidgets('disabled filter chip has no callback', (tester) async {
    await pumpTetri(
      tester,
      const TetriFilterChip(label: 'Sent', selected: false, onSelected: null),
    );
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).onSelected,
      isNull,
    );
  });
}
