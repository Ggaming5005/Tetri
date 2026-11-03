import 'package:flutter/material.dart';

/// Flag artwork is separate from the app's interactive color palette.
abstract final class CurrencyFlagTokens {
  static const white = Color(0xFFFFFFFF);
  static const georgiaRed = Color(0xFFFF0000);
  static const usRed = Color(0xFFB22234);
  static const usBlue = Color(0xFF3C3B6E);
  static const euBlue = Color(0xFF003399);
  static const euGold = Color(0xFFFFCC00);
  static const mainCrossWidth = 0.16;
  static const smallCrossSize = 0.16;
  static const smallCrossWidth = 0.045;
  static const quadrantCenters = [0.25, 0.75];
  static const usStripes = 13;
  static const usCantonWidth = 0.52;
  static const usCantonHeight = 7 / usStripes;
  static const usStarRows = 9;
  static const usLongStarRow = 6;
  static const usShortStarRow = 5;
  static const usStarRadius = 0.022;
  static const euStars = 12;
  static const euRingRadius = 0.29;
  static const euStarRadius = 0.065;
  static const starPoints = 5;
  static const starInnerRatio = 0.38196601125;
}
