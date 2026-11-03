import 'package:flutter/material.dart';

@immutable
class TetriColors extends ThemeExtension<TetriColors> {
  const TetriColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.placeholder,
    required this.textDisabled,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.warningBg,
    required this.avatarPalette,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color placeholder;
  final Color textDisabled;
  final Color accent;
  final Color accentText;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color warningBg;
  final List<Color> avatarPalette;

  static const light = TetriColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F4),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFE7E5E4),
    textPrimary: Color(0xFF0C0A09),
    textSecondary: Color(0xFF57534E),
    placeholder: Color(0xFF6E6A66),
    textDisabled: Color(0xFFA8A29E),
    accent: Color(0xFF3B4BF5),
    accentText: Color(0xFF3B4BF5),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF15803D),
    negative: Color(0xFFB91C1C),
    warningBg: Color(0xFFFEF3C7),
    avatarPalette: [
      Color(0xFFE7ECE3),
      Color(0xFFE7E8EE),
      Color(0xFFEFE5DE),
      Color(0xFFE2EAE9),
    ],
  );

  static const dark = TetriColors(
    bg: Color(0xFF0B0B0C),
    surface: Color(0xFF161618),
    surfaceRaised: Color(0xFF1E1E21),
    border: Color(0xFF2A2A2E),
    textPrimary: Color(0xFFFAFAF9),
    textSecondary: Color(0xFFA8A29E),
    placeholder: Color(0xFF9A9AA0),
    textDisabled: Color(0xFF6B6B70),
    accent: Color(0xFF5360F5),
    accentText: Color(0xFF8C96FF),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFF87171),
    warningBg: Color(0xFF3A2E0A),
    avatarPalette: [
      Color(0xFF253128),
      Color(0xFF2D2C3B),
      Color(0xFF382D28),
      Color(0xFF243236),
    ],
  );

  static TetriColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<TetriColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  TetriColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? placeholder,
    Color? textDisabled,
    Color? accent,
    Color? accentText,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? warningBg,
    List<Color>? avatarPalette,
  }) => TetriColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    placeholder: placeholder ?? this.placeholder,
    textDisabled: textDisabled ?? this.textDisabled,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    onAccent: onAccent ?? this.onAccent,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    warningBg: warningBg ?? this.warningBg,
    avatarPalette: List.unmodifiable(avatarPalette ?? this.avatarPalette),
  );

  @override
  TetriColors lerp(covariant TetriColors? other, double t) {
    if (other == null) return this;
    return TetriColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      avatarPalette: avatarPalette.length == other.avatarPalette.length
          ? List.unmodifiable([
              for (var i = 0; i < avatarPalette.length; i++)
                Color.lerp(avatarPalette[i], other.avatarPalette[i], t)!,
            ])
          : (t < 0.5 ? avatarPalette : other.avatarPalette),
    );
  }
}

abstract final class TetriSpace {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x48 = 48;
  static const double x64 = 64;
}

abstract final class TetriRadii {
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double pill = 999;
}

abstract final class TetriSizes {
  static const double zero = 0;
  static const double tap = 48;
  static const double button = 56;
  static const double listRow = 64;
  static const double icon = 24;
  static const double iconSmall = 20;
  static const double iconLarge = 32;
  static const double tap48 = tap;
  static const double button56 = button;
  static const double listRow64 = listRow;
  static const double icon24 = icon;
  static const double borderWidth = 1;
  static const double focusBorderWidth = 1;
  static const double spinner = 20;
  static const double spinnerStroke = 2;
  static const double scaffoldExpandedHeight = 120;
  static const double statusIcon = 48;
  static const double avatar48 = 48;
  static const double currencyFlag40 = 40;
  static const double keypadKey64 = 64;
  static const double switchWidth = 52;
  static const double switchHeight = 32;
  static const double switchThumb = 24;
  static const double switchInset = 4;
  static const double contentMaxWidth = 560;
  static const double sheetMaxWidth = 480;
  static const double artworkHeight = 180;
}

abstract final class TetriOpacity {
  static const double hover = 0.06;
  static const double pressed = 0.10;
  static const double focused = 0.12;
  static const double scrim = 0.36;
  static const double skeletonMin = 0.45;
  static const double skeletonMax = 1;
}

abstract final class TetriMotion {
  static const fast = Duration(milliseconds: 150);
  static const screen = Duration(milliseconds: 250);
  static const balance = Duration(milliseconds: 300);
  static const skeletonPulse = Duration(milliseconds: 1200);
  static const curve = Curves.easeOutCubic;
}

abstract final class TetriProgress {
  static const double indeterminateFallback = 0.75;
}
