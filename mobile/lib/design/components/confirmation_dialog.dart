import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';
import 'content.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: TetriColors.of(context).surfaceRaised,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TetriRadii.r24),
    ),
    insetPadding: const EdgeInsets.all(TetriSpace.x24),
    title: TetriText(title, style: TetriTextStyle.headline),
    content: TetriText(message),
    actionsPadding: const EdgeInsets.all(TetriSpace.x16),
    actions: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: TetriSpace.x8),
          TetriTextButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ],
  );
}
