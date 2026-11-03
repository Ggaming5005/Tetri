import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class TetriTheme {
  static final light = _build(TetriColors.light, Brightness.light);
  static final dark = _build(TetriColors.dark, Brightness.dark);

  static ThemeData _build(TetriColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.surface,
      onPrimaryContainer: colors.accentText,
      secondary: colors.textSecondary,
      onSecondary: colors.bg,
      secondaryContainer: colors.surface,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.accentText,
      onTertiary: colors.bg,
      tertiaryContainer: colors.surface,
      onTertiaryContainer: colors.accentText,
      error: colors.negative,
      onError: colors.bg,
      errorContainer: colors.surface,
      onErrorContainer: colors.negative,
      surface: colors.bg,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.bg,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceRaised,
      surfaceContainerHighest: colors.surfaceRaised,
      surfaceBright: colors.surfaceRaised,
      surfaceDim: colors.surface,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: Colors.transparent,
      scrim: Colors.black,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.bg,
      inversePrimary: brightness == Brightness.dark
          ? TetriColors.light.accentText
          : TetriColors.dark.accentText,
      surfaceTint: Colors.transparent,
    );
    final textTheme = TetriTypography.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TetriRadii.r16),
    );
    final inputShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TetriRadii.r12),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      fontFamily: TetriTypography.body.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      cardColor: colors.surface,
      dividerColor: colors.border,
      disabledColor: colors.textDisabled,
      shadowColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: colors.accentText.withValues(alpha: TetriOpacity.hover),
      focusColor: colors.accentText.withValues(alpha: TetriOpacity.focused),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(
        color: colors.textPrimary,
        size: TetriSizes.icon,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.bg,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: TetriSizes.zero,
        scrolledUnderElevation: TetriSizes.zero,
        centerTitle: false,
        titleSpacing: TetriSpace.x24,
        titleTextStyle: TetriTypography.title.copyWith(
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: colors.textPrimary,
          size: TetriSizes.icon,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: TetriSizes.zero,
        margin: EdgeInsets.zero,
        shape: buttonShape,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: TetriSizes.borderWidth,
        space: TetriSizes.borderWidth,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, TetriSizes.button),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.surface
                : colors.accent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.onAccent,
          ),
          overlayColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: TetriOpacity.pressed),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(TetriTypography.title),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: TetriSpace.x24,
              vertical: TetriSpace.x16,
            ),
          ),
          elevation: const WidgetStatePropertyAll(TetriSizes.zero),
          animationDuration: TetriMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textDisabled,
          minimumSize: const Size(double.infinity, TetriSizes.button),
          padding: const EdgeInsets.symmetric(
            horizontal: TetriSpace.x24,
            vertical: TetriSpace.x16,
          ),
          textStyle: TetriTypography.title,
          shape: buttonShape,
          side: BorderSide(color: colors.border, width: TetriSizes.borderWidth),
          elevation: TetriSizes.zero,
          animationDuration: TetriMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          disabledForegroundColor: colors.textDisabled,
          minimumSize: const Size(TetriSizes.tap, TetriSizes.tap),
          padding: const EdgeInsets.symmetric(horizontal: TetriSpace.x16),
          textStyle: TetriTypography.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TetriRadii.r8),
          ),
          animationDuration: TetriMotion.fast,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.all(TetriSpace.x16),
        hintStyle: TetriTypography.body.copyWith(color: colors.placeholder),
        labelStyle: TetriTypography.label.copyWith(color: colors.textSecondary),
        errorStyle: TetriTypography.label.copyWith(color: colors.negative),
        border: inputShape,
        enabledBorder: inputShape,
        disabledBorder: inputShape,
        focusedBorder: inputShape.copyWith(
          borderSide: BorderSide(
            color: colors.accent,
            width: TetriSizes.focusBorderWidth,
          ),
        ),
        errorBorder: inputShape.copyWith(
          borderSide: BorderSide(
            color: colors.negative,
            width: TetriSizes.borderWidth,
          ),
        ),
        focusedErrorBorder: inputShape.copyWith(
          borderSide: BorderSide(
            color: colors.negative,
            width: TetriSizes.focusBorderWidth,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        modalBackgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: TetriSizes.zero,
        modalElevation: TetriSizes.zero,
        modalBarrierColor: Colors.black.withValues(alpha: TetriOpacity.scrim),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TetriRadii.r24),
          ),
        ),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: TetriSizes.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetriRadii.r24),
        ),
        titleTextStyle: TetriTypography.title.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: TetriTypography.body.copyWith(
          color: colors.textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        minTileHeight: TetriSizes.listRow,
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        titleTextStyle: TetriTypography.title.copyWith(
          color: colors.textPrimary,
        ),
        subtitleTextStyle: TetriTypography.label.copyWith(
          color: colors.textSecondary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentText,
        selectionColor: colors.accentText.withValues(
          alpha: TetriOpacity.focused,
        ),
        selectionHandleColor: colors.accentText,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentText,
      ),
    );
  }
}
