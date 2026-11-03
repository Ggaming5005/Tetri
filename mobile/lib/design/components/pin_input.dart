import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_pin.dart';
import '../tokens.dart';
import '../typography.dart';

/// One native secure field keeps keyboard, focus and accessibility predictable.
class PinInput extends StatelessWidget {
  const PinInput({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TetriRadii.r12),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: TetriTypography.label.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: TetriSpace.x8),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(AppPinController.pinLength),
            ],
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            enableInteractiveSelection: false,
            textAlign: TextAlign.center,
            style: TetriTypography.titleAmount.copyWith(
              color: enabled ? colors.textPrimary : colors.textDisabled,
              letterSpacing: TetriSpace.x8,
            ),
            cursorColor: colors.accentText,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.all(TetriSpace.x16),
              constraints: const BoxConstraints(minHeight: TetriSizes.tap48),
              border: border,
              enabledBorder: errorText == null
                  ? border
                  : border.copyWith(
                      borderSide: BorderSide(
                        color: colors.negative,
                        width: TetriSizes.borderWidth,
                      ),
                    ),
              disabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: errorText == null ? colors.accent : colors.negative,
                  width: TetriSizes.focusBorderWidth,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: TetriSpace.x8),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: TetriTypography.label.copyWith(color: colors.negative),
            ),
          ),
        ],
      ],
    );
  }
}
