import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../tokens.dart';
import '../typography.dart';

class NavigationAction extends StatelessWidget {
  const NavigationAction({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title, description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Semantics(
      button: true,
      label: title,
      hint: description,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(TetriRadii.r16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TetriRadii.r16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TetriSizes.listRow),
              child: Padding(
                padding: const EdgeInsets.all(TetriSpace.x16),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: TetriSizes.tap,
                      child: Icon(
                        icon,
                        size: TetriSizes.icon,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: TetriSpace.x12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TetriTypography.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: TetriSpace.x4),
                          Text(
                            description,
                            style: TetriTypography.label.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TetriSpace.x12),
                    Icon(
                      PhosphorIconsRegular.caretRight,
                      size: TetriSizes.icon,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
