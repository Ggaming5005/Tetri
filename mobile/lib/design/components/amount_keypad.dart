import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', MoneyInput.backspace],
  ];

  void _press(String key) {
    final next = MoneyInput.press(value, key);
    unawaited(HapticFeedback.lightImpact());
    if (next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: TetriStrings.amountKeypad,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row) Expanded(child: _key(context, key)),
            ],
          ),
      ],
    ),
  );

  Widget _key(BuildContext context, String key) {
    final colors = TetriColors.of(context);
    final color = enabled ? colors.textPrimary : colors.textDisabled;
    final label = switch (key) {
      '.' => TetriStrings.decimalPoint,
      MoneyInput.backspace => TetriStrings.deleteDigit,
      _ => key,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => _press(key) : null,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('amount-key-$key'),
          onTap: enabled ? () => _press(key) : null,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(TetriRadii.r16),
          child: SizedBox(
            height: TetriSizes.keypadKey64,
            child: Center(
              child: key == MoneyInput.backspace
                  ? Icon(
                      PhosphorIconsRegular.backspace,
                      size: TetriSizes.icon24,
                      color: color,
                    )
                  : Text(
                      key,
                      style: TetriTypography.headline.copyWith(color: color),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
