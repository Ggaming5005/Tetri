import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = TetriSizes.tap48,
  });

  final String userId;
  final String name;
  final double size;

  static int paletteIndex(String userId, int paletteLength) {
    final hash = userId.codeUnits.fold(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return hash % paletteLength;
  }

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    return '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                colors.avatarPalette[paletteIndex(
                  userId,
                  colors.avatarPalette.length,
                )],
            shape: BoxShape.circle,
          ),
          child: Text(
            initials,
            style: TetriTypography.label.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
