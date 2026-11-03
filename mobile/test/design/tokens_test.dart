import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';
import 'package:tetri/design/typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await GoogleFonts.pendingFonts([
      TetriTypography.displayAmount,
      TetriTypography.titleAmount,
      TetriTypography.headline,
      TetriTypography.title,
      TetriTypography.body,
      TetriTypography.label,
      TetriTypography.micro,
    ]);
  });

  for (final theme in {
    'light': TetriColors.light,
    'dark': TetriColors.dark,
  }.entries) {
    final colors = theme.value;
    final textColors = {
      'textPrimary': colors.textPrimary,
      'textSecondary': colors.textSecondary,
      'placeholder': colors.placeholder,
      'accentText': colors.accentText,
      'positive': colors.positive,
      'negative': colors.negative,
    };
    final surfaces = {
      'bg': colors.bg,
      'surface': colors.surface,
      'surfaceRaised': colors.surfaceRaised,
    };

    for (final text in textColors.entries) {
      for (final surface in surfaces.entries) {
        test('${theme.key}: ${text.key} on ${surface.key} meets WCAG AA', () {
          expect(
            _contrast(text.value, surface.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }

    test('${theme.key}: onAccent on accent meets WCAG AA', () {
      expect(
        _contrast(colors.onAccent, colors.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    for (var index = 0; index < colors.avatarPalette.length; index++) {
      test('${theme.key}: initials on avatar palette $index meet WCAG AA', () {
        expect(
          _contrast(colors.textPrimary, colors.avatarPalette[index]),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    for (final text in {
      'textPrimary': colors.textPrimary,
      'textSecondary': colors.textSecondary,
    }.entries) {
      test('${theme.key}: ${text.key} on warningBg meets WCAG AA', () {
        expect(
          _contrast(text.value, colors.warningBg),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test('theme extension interpolation includes every semantic color', () {
    final light = _colorValues(TetriColors.light);
    final dark = _colorValues(TetriColors.dark);
    for (final progress in [0.0, 0.5, 1.0]) {
      final interpolated = _colorValues(
        TetriColors.light.lerp(TetriColors.dark, progress),
      );
      for (var index = 0; index < light.length; index++) {
        expect(
          interpolated[index],
          Color.lerp(light[index], dark[index], progress),
        );
      }
    }
    expect(TetriColors.light.lerp(null, 0.5), same(TetriColors.light));
  });

  test(
    'copyWith keeps untouched colors and copies a mutable avatar palette',
    () {
      final palette = [Colors.black];
      final copied = TetriColors.light.copyWith(
        bg: Colors.black,
        avatarPalette: palette,
      );
      palette[0] = Colors.white;
      expect(copied.bg, Colors.black);
      expect(copied.textPrimary, TetriColors.light.textPrimary);
      expect(copied.avatarPalette, [Colors.black]);
      expect(
        () => copied.avatarPalette.add(Colors.white),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'typography preserves the specified Inter sizes, line heights and weights',
    () {
      final specifications = [
        (TetriTypography.displayAmount, 44.0, 52.0, FontWeight.w600),
        (TetriTypography.titleAmount, 32.0, 40.0, FontWeight.w600),
        (TetriTypography.headline, 24.0, 32.0, FontWeight.w600),
        (TetriTypography.title, 17.0, 24.0, FontWeight.w600),
        (TetriTypography.body, 15.0, 22.0, FontWeight.w400),
        (TetriTypography.label, 13.0, 18.0, FontWeight.w500),
        (TetriTypography.micro, 11.0, 14.0, FontWeight.w500),
      ];
      for (final (style, size, lineHeight, weight) in specifications) {
        expect(style.fontFamily, startsWith('Inter'));
        expect(style.fontSize, size);
        expect(style.height! * size, closeTo(lineHeight, 0.0001));
        expect(style.fontWeight, weight);
      }
      expect(TetriTypography.micro.letterSpacing, 0.5);
    },
  );

  test('large amounts always use tabular figures', () {
    for (final style in [
      TetriTypography.displayAmount,
      TetriTypography.titleAmount,
    ]) {
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  for (final mode in [Brightness.light, Brightness.dark]) {
    test(
      '${mode.name}: primary button state overlays preserve label contrast',
      () {
        final theme = mode == Brightness.light
            ? TetriTheme.light
            : TetriTheme.dark;
        final style = theme.filledButtonTheme.style!;
        for (final state in [
          WidgetState.pressed,
          WidgetState.hovered,
          WidgetState.focused,
        ]) {
          final states = {state};
          final background = style.backgroundColor!.resolve(states)!;
          final foreground = style.foregroundColor!.resolve(states)!;
          final overlay = style.overlayColor!.resolve(states)!;
          expect(
            _contrast(foreground, Color.alphaBlend(overlay, background)),
            greaterThanOrEqualTo(4.5),
          );
        }
      },
    );

    testWidgets(
      '${mode.name}: theme exposes tokens and keeps Material surfaces flat',
      (tester) async {
        final theme = mode == Brightness.light
            ? TetriTheme.light
            : TetriTheme.dark;
        final colors = mode == Brightness.light
            ? TetriColors.light
            : TetriColors.dark;
        TetriColors? inherited;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                inherited = TetriColors.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(inherited, same(colors));
        expect(theme.brightness, mode);
        expect(theme.scaffoldBackgroundColor, colors.bg);
        expect(theme.textTheme.bodyMedium?.color, colors.textPrimary);
        expect(theme.colorScheme.primary, colors.accent);
        expect(theme.shadowColor, Colors.transparent);
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.bottomSheetTheme.modalElevation, 0);
        expect(theme.dialogTheme.elevation, 0);
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({}),
          const Size(double.infinity, TetriSizes.button),
        );
      },
    );
  }
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  return (math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
      (math.min(foregroundLuminance, backgroundLuminance) + 0.05);
}

List<Color> _colorValues(TetriColors colors) => [
  colors.bg,
  colors.surface,
  colors.surfaceRaised,
  colors.border,
  colors.textPrimary,
  colors.textSecondary,
  colors.placeholder,
  colors.textDisabled,
  colors.accent,
  colors.accentText,
  colors.onAccent,
  colors.positive,
  colors.negative,
  colors.warningBg,
  ...colors.avatarPalette,
];
