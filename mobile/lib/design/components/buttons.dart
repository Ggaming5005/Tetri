import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => _TetriButton(
    label: label,
    onPressed: onPressed,
    isLoading: isLoading,
    kind: _ButtonKind.primary,
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => _TetriButton(
    label: label,
    onPressed: onPressed,
    isLoading: isLoading,
    kind: _ButtonKind.secondary,
  );
}

class TetriTextButton extends StatelessWidget {
  const TetriTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => _TetriButton(
    label: label,
    onPressed: onPressed,
    isLoading: isLoading,
    kind: _ButtonKind.text,
  );
}

enum _ButtonKind { primary, secondary, text }

class _TetriButton extends StatelessWidget {
  const _TetriButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.kind,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final _ButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final primary = kind == _ButtonKind.primary;
    final text = kind == _ButtonKind.text;
    final foreground = primary
        ? colors.onAccent
        : text
        ? colors.accentText
        : colors.textPrimary;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(TetriSizes.tap48, text ? TetriSizes.tap48 : TetriSizes.button56),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: text ? TetriSpace.x16 : TetriSpace.x24,
          vertical: TetriSpace.x12,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        text ? TetriTypography.label : TetriTypography.title,
      ),
      elevation: const WidgetStatePropertyAll(TetriSizes.zero),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isLoading
            ? colors.textDisabled
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (primary) {
          return states.contains(WidgetState.disabled) && !isLoading
              ? colors.surface
              : colors.accent;
        }
        return Colors.transparent;
      }),
      side: WidgetStatePropertyAll(
        kind == _ButtonKind.secondary
            ? BorderSide(color: colors.border, width: TetriSizes.borderWidth)
            : BorderSide.none,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetriRadii.r16),
        ),
      ),
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TetriMotion.fast,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    final content = Semantics(
      label: isLoading ? label : null,
      value: isLoading ? TetriStrings.loading : null,
      liveRegion: isLoading,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Visibility(
            visible: !isLoading,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(label, textAlign: TextAlign.center, softWrap: true),
          ),
          if (isLoading)
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: TetriSizes.icon24,
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context)
                      ? TetriProgress.indeterminateFallback
                      : null,
                  strokeWidth: TetriSizes.spinnerStroke,
                  color: foreground,
                ),
              ),
            ),
        ],
      ),
    );
    final callback = isLoading ? null : onPressed;
    final button = switch (kind) {
      _ButtonKind.primary => FilledButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      _ButtonKind.secondary => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      _ButtonKind.text => TextButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
    };
    return text ? button : SizedBox(width: double.infinity, child: button);
  }
}
