import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/strings_auth.dart';
import '../tokens.dart';
import '../typography.dart';

enum TetriTextStyle { headline, title, body, label, micro }

class TetriText extends StatelessWidget {
  const TetriText(
    this.text, {
    super.key,
    this.style = TetriTextStyle.body,
    this.secondary = false,
  });
  final String text;
  final TetriTextStyle style;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style:
        switch (style) {
          TetriTextStyle.headline => TetriTypography.headline,
          TetriTextStyle.title => TetriTypography.title,
          TetriTextStyle.body => TetriTypography.body,
          TetriTextStyle.label => TetriTypography.label,
          TetriTextStyle.micro => TetriTypography.micro,
        }.copyWith(
          color: secondary
              ? TetriColors.of(context).textSecondary
              : TetriColors.of(context).textPrimary,
        ),
  );
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (onBack != null) ...[
        IconButton(
          tooltip: AuthStrings.back,
          onPressed: onBack,
          constraints: const BoxConstraints(
            minWidth: TetriSizes.tap48,
            minHeight: TetriSizes.tap48,
          ),
          icon: Icon(
            PhosphorIconsRegular.arrowLeft,
            size: TetriSizes.icon24,
            color: TetriColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: TetriSpace.x24),
      ],
      TetriText(title, style: TetriTextStyle.headline),
      if (subtitle != null) ...[
        const SizedBox(height: TetriSpace.x12),
        TetriText(subtitle!, secondary: true),
      ],
    ],
  );
}

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AuthStrings.step(current, total),
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: TetriSpace.x8),
            Expanded(
              child: Container(
                height: TetriSpace.x4,
                decoration: BoxDecoration(
                  color: index < current
                      ? TetriColors.of(context).accent
                      : TetriColors.of(context).surface,
                  borderRadius: BorderRadius.circular(TetriRadii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
