import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';

enum TextInputVariant { plain, password, search }

class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.variant = TextInputVariant.plain,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputVariant variant;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  bool _obscure = true;

  @override
  void didUpdateWidget(TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) _obscure = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final password = widget.variant == TextInputVariant.password;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TetriRadii.r12),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: TetriTypography.label.copyWith(
              color: widget.enabled
                  ? colors.textSecondary
                  : colors.textDisabled,
            ),
          ),
        ),
        const SizedBox(height: TetriSpace.x8),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            obscureText: password && _obscure,
            autocorrect: !password,
            enableSuggestions: !password,
            style: TetriTypography.body.copyWith(
              color: widget.enabled ? colors.textPrimary : colors.textDisabled,
            ),
            cursorColor: colors.accentText,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surface,
              hintText: widget.hint,
              hintStyle: TetriTypography.body.copyWith(
                color: colors.placeholder,
              ),
              errorText: widget.errorText,
              errorStyle: TetriTypography.label.copyWith(
                color: colors.negative,
              ),
              errorMaxLines: 3,
              contentPadding: const EdgeInsets.all(TetriSpace.x16),
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
              prefixIcon: widget.variant == TextInputVariant.search
                  ? Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: colors.textSecondary,
                      size: TetriSizes.icon24,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: TetriSizes.tap48,
                minHeight: TetriSizes.tap48,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: TetriSizes.tap48,
                minHeight: TetriSizes.tap48,
              ),
              suffixIcon: password
                  ? IconButton(
                      tooltip: _obscure
                          ? TetriStrings.showPassword
                          : TetriStrings.hidePassword,
                      onPressed: widget.enabled
                          ? () => setState(() => _obscure = !_obscure)
                          : null,
                      icon: Icon(
                        _obscure
                            ? PhosphorIconsRegular.eye
                            : PhosphorIconsRegular.eyeSlash,
                        color: widget.enabled
                            ? colors.textSecondary
                            : colors.textDisabled,
                        size: TetriSizes.icon24,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: TetriSizes.tap48,
                        minHeight: TetriSizes.tap48,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
