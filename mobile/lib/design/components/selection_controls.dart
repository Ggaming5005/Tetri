import 'package:flutter/material.dart';

import '../tokens.dart';
import '../browse_tokens.dart';
import '../typography.dart';

class TetriSwitch extends StatelessWidget {
  const TetriSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TetriMotion.fast;
    final toggle = onChanged == null ? null : () => onChanged!(!value);
    return Semantics(
      label: label,
      toggled: value,
      enabled: onChanged != null,
      onTap: toggle,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: toggle,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(TetriRadii.r12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TetriSizes.tap48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TetriTypography.body.copyWith(
                      color: onChanged == null
                          ? colors.textDisabled
                          : colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: TetriSpace.x16),
                AnimatedContainer(
                  duration: duration,
                  curve: TetriMotion.curve,
                  width: TetriSizes.switchWidth,
                  height: TetriSizes.switchHeight,
                  padding: const EdgeInsets.all(TetriSizes.switchInset),
                  decoration: BoxDecoration(
                    color: value && onChanged != null
                        ? colors.accent
                        : colors.surface,
                    borderRadius: BorderRadius.circular(TetriRadii.pill),
                  ),
                  child: AnimatedAlign(
                    duration: duration,
                    curve: TetriMotion.curve,
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: TetriSizes.switchThumb,
                      height: TetriSizes.switchThumb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onChanged == null
                            ? colors.textDisabled
                            : value
                            ? colors.onAccent
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TetriSegmentedControl<T> extends StatelessWidget {
  const TetriSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    assert(segments.length > 1 && segments.containsKey(value));
    final colors = TetriColors.of(context);
    return SegmentedButton<T>(
      segments: segments.entries
          .map(
            (segment) => ButtonSegment<T>(
              value: segment.key,
              label: Text(segment.value),
            ),
          )
          .toList(),
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.single),
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(TetriSizes.tap48, TetriSizes.tap48),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: TetriSpace.x16,
            vertical: TetriSpace.x12,
          ),
        ),
        textStyle: WidgetStatePropertyAll(TetriTypography.label),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.surface,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (!states.any(
            {
              WidgetState.pressed,
              WidgetState.hovered,
              WidgetState.focused,
            }.contains,
          )) {
            return Colors.transparent;
          }
          final tint = states.contains(WidgetState.selected)
              ? Colors.black
              : colors.textPrimary;
          return tint.withValues(alpha: TetriOpacity.pressed);
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.textDisabled
              : states.contains(WidgetState.selected)
              ? colors.onAccent
              : colors.textSecondary,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TetriRadii.r12),
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TetriMotion.fast,
      ),
    );
  }
}

class TetriFilterChip extends StatelessWidget {
  const TetriFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TetriSizes.tap48,
        minHeight: TetriSizes.tap48,
      ),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        backgroundColor: colors.bg,
        selectedColor: colors.surface,
        disabledColor: colors.surface,
        labelStyle: TetriTypography.label.copyWith(
          color: onSelected == null
              ? colors.textDisabled
              : selected
              ? colors.accentText
              : colors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? colors.accentText : colors.border,
          width: TetriSizes.borderWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetriRadii.r8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: TetriSpace.x8,
          vertical: TetriSpace.x8,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        elevation: TetriSizes.zero,
        pressElevation: TetriSizes.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

class TetriFilterBar<T> extends StatelessWidget {
  const TetriFilterBar({
    super.key,
    required this.filters,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> filters;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final filter in filters.entries)
        TetriFilterChip(
          label: filter.value,
          selected: filter.key == value,
          onSelected: (_) => onChanged(filter.key),
        ),
    ];
    final largeText =
        MediaQuery.textScalerOf(context)
            .scale(TetriTypography.label.fontSize!) >=
        TetriTypography.label.fontSize! *
            TetriBrowseSizes.accessibilityTextScale;
    if (largeText) {
      return Wrap(
        spacing: TetriSpace.x8,
        runSpacing: TetriSpace.x4,
        children: chips,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            if (index > 0) const SizedBox(width: TetriSpace.x8),
            chips[index],
          ],
        ],
      ),
    );
  }
}
