import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../currency_flag_tokens.dart';
import '../tokens.dart';

class CurrencyFlag extends StatelessWidget {
  const CurrencyFlag({super.key, required this.currency})
    : assert(currency == 'GEL' || currency == 'USD' || currency == 'EUR');
  final String currency;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: currency,
    child: SizedBox.square(
      dimension: TetriSizes.currencyFlag40,
      child: CustomPaint(painter: CurrencyFlagPainter(currency)),
    ),
  );
}

class CurrencyFlagPainter extends CustomPainter {
  const CurrencyFlagPainter(this.currency);
  final String currency;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.scale(size.width, size.height);
    switch (currency) {
      case 'GEL':
        _georgia(canvas);
        break;
      case 'USD':
        _unitedStates(canvas);
        break;
      case 'EUR':
        _europe(canvas);
        break;
    }
    canvas.restore();
  }

  void _georgia(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = CurrencyFlagTokens.white,
    );
    final paint = Paint()..color = CurrencyFlagTokens.georgiaRed;
    final width = CurrencyFlagTokens.mainCrossWidth;
    canvas.drawRect(Rect.fromLTWH((1 - width) / 2, 0, width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(0, (1 - width) / 2, 1, width), paint);
    for (final x in CurrencyFlagTokens.quadrantCenters) {
      for (final y in CurrencyFlagTokens.quadrantCenters) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: CurrencyFlagTokens.smallCrossWidth,
            height: CurrencyFlagTokens.smallCrossSize,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: CurrencyFlagTokens.smallCrossSize,
            height: CurrencyFlagTokens.smallCrossWidth,
          ),
          paint,
        );
      }
    }
  }

  void _unitedStates(Canvas canvas) {
    final stripe = 1 / CurrencyFlagTokens.usStripes;
    for (var row = 0; row < CurrencyFlagTokens.usStripes; row++) {
      canvas.drawRect(
        Rect.fromLTWH(0, row * stripe, 1, stripe),
        Paint()
          ..color = row.isEven
              ? CurrencyFlagTokens.usRed
              : CurrencyFlagTokens.white,
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        0,
        CurrencyFlagTokens.usCantonWidth,
        CurrencyFlagTokens.usCantonHeight,
      ),
      Paint()..color = CurrencyFlagTokens.usBlue,
    );
    for (var row = 0; row < CurrencyFlagTokens.usStarRows; row++) {
      final columns = row.isEven
          ? CurrencyFlagTokens.usLongStarRow
          : CurrencyFlagTokens.usShortStarRow;
      for (var column = 0; column < columns; column++) {
        _star(
          canvas,
          Offset(
            (column + 1) * CurrencyFlagTokens.usCantonWidth / (columns + 1),
            (row + 1) *
                CurrencyFlagTokens.usCantonHeight /
                (CurrencyFlagTokens.usStarRows + 1),
          ),
          CurrencyFlagTokens.usStarRadius,
          CurrencyFlagTokens.white,
        );
      }
    }
  }

  void _europe(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = CurrencyFlagTokens.euBlue,
    );
    for (var star = 0; star < CurrencyFlagTokens.euStars; star++) {
      final angle =
          star * 2 * math.pi / CurrencyFlagTokens.euStars - math.pi / 2;
      _star(
        canvas,
        Offset(
          0.5 + math.cos(angle) * CurrencyFlagTokens.euRingRadius,
          0.5 + math.sin(angle) * CurrencyFlagTokens.euRingRadius,
        ),
        CurrencyFlagTokens.euStarRadius,
        CurrencyFlagTokens.euGold,
      );
    }
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var vertex = 0; vertex < CurrencyFlagTokens.starPoints * 2; vertex++) {
      final angle =
          vertex * math.pi / CurrencyFlagTokens.starPoints - math.pi / 2;
      final length = vertex.isEven
          ? radius
          : radius * CurrencyFlagTokens.starInnerRatio;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * length;
      if (vertex == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(CurrencyFlagPainter oldDelegate) =>
      oldDelegate.currency != currency;
}
