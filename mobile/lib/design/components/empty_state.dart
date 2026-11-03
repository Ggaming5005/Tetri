import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TetriSpace.x48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: TetriSizes.statusIcon,
          color: TetriColors.of(context).textSecondary,
        ),
        const SizedBox(height: TetriSpace.x16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TetriTypography.body.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: TetriSpace.x16),
          TetriTextButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    ),
  );
}
