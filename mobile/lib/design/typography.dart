import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class TetriTypography {
  static final displayAmount = GoogleFonts.inter(
    fontSize: 44,
    height: 52 / 44,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static final titleAmount = GoogleFonts.inter(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static final headline = GoogleFonts.inter(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
  );
  static final title = GoogleFonts.inter(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
  );
  static final body = GoogleFonts.inter(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static final label = GoogleFonts.inter(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );
  static final micro = GoogleFonts.inter(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayAmount,
    displayMedium: displayAmount,
    displaySmall: titleAmount,
    headlineLarge: headline,
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: title,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: label,
    labelLarge: title,
    labelMedium: label,
    labelSmall: micro,
  );
}
