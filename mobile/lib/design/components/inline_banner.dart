import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../tokens.dart';
import '../typography.dart';

enum BannerKind { info, warning }

class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.info,
  });

  final String message;
  final BannerKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kind == BannerKind.warning ? colors.warningBg : colors.surface,
          borderRadius: BorderRadius.circular(TetriRadii.r12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TetriSpace.x16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kind == BannerKind.warning
                    ? PhosphorIconsRegular.warningCircle
                    : PhosphorIconsRegular.info,
                size: TetriSizes.icon24,
                color: colors.textPrimary,
              ),
              const SizedBox(width: TetriSpace.x12),
              Expanded(
                child: Text(
                  message,
                  style: TetriTypography.body.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
