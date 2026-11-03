import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/strings_money.dart';
import '../tokens.dart';
import '../typography.dart';

/// Accepts decimal keyboard edits without converting money through a float.
class MoneyAmountFormatter extends TextInputFormatter {
  const MoneyAmountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (!RegExp(r'^[0-9]*([.,][0-9]{0,2})?$').hasMatch(raw)) return oldValue;
    if (raw.isEmpty) return newValue;
    var normalized = raw.replaceAll(',', '.');
    if (normalized.startsWith('.')) normalized = '0$normalized';
    normalized = normalized.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
    try {
      MoneyInput.minorUnits(normalized);
    } on FormatException {
      return oldValue;
    }
    if (normalized == raw) return newValue;
    final shift = normalized.length - raw.length;
    int offset(int original) => (original + shift).clamp(0, normalized.length);
    return newValue.copyWith(
      text: normalized,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}

/// A native decimal keyboard field. The public value remains exact decimal text.
class MoneyAmountInput extends StatefulWidget {
  const MoneyAmountInput({
    super.key,
    required this.value,
    required this.currency,
    required this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.label,
    this.focusNode,
  });

  final String value, currency;
  final ValueChanged<String> onChanged;
  final bool enabled, autofocus;
  final String? errorText, label;
  final FocusNode? focusNode;

  @override
  State<MoneyAmountInput> createState() => _MoneyAmountInputState();
}

class _MoneyAmountInputState extends State<MoneyAmountInput> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(MoneyAmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.value) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final style = TetriTypography.titleAmount.copyWith(
      color: widget.enabled ? colors.textPrimary : colors.textDisabled,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final border = UnderlineInputBorder(
      borderSide: BorderSide(
        color: colors.border,
        width: TetriSizes.borderWidth,
      ),
    );
    return Semantics(
      label: '${widget.label ?? MoneyStrings.amount} ${widget.currency}',
      child: TextField(
        controller: _text,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: const [MoneyAmountFormatter()],
        autocorrect: false,
        enableSuggestions: false,
        onChanged: widget.onChanged,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        style: style,
        cursorColor: colors.accentText,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          prefixText: MoneyFormat.symbol(widget.currency),
          prefixStyle: style,
          hintText: MoneyStrings.amountPlaceholder,
          hintStyle: style.copyWith(color: colors.placeholder),
          errorText: widget.errorText,
          errorMaxLines: 4,
          errorStyle: TetriTypography.label.copyWith(color: colors.negative),
          contentPadding: const EdgeInsets.symmetric(vertical: TetriSpace.x12),
          constraints: const BoxConstraints(minHeight: TetriSizes.tap48),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: colors.accent,
              width: TetriSizes.focusBorderWidth,
            ),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(
              color: colors.negative,
              width: TetriSizes.borderWidth,
            ),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(
              color: colors.negative,
              width: TetriSizes.focusBorderWidth,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
