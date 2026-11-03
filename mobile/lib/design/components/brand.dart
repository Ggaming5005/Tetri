import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';

class TetriWordmark extends StatelessWidget {
  const TetriWordmark({super.key});

  @override
  Widget build(BuildContext context) => Text(
    TetriStrings.appName,
    style: TetriTypography.displayAmount.copyWith(
      color: TetriColors.of(context).textPrimary,
    ),
  );
}

class TetriArtwork extends StatelessWidget {
  const TetriArtwork({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/illustrations/welcome.png',
    height: TetriSizes.artworkHeight,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
