import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/money.dart';
import '../tokens.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'buttons.dart';

class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.title,
    required this.amount,
    required this.actionLabel,
    required this.onAction,
    this.isSuccess = true,
    this.message,
  });

  final String title;
  final Money amount;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isSuccess;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TetriSpace.x48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.warningCircle,
                  size: TetriSizes.statusIcon,
                  color: isSuccess ? colors.positive : colors.negative,
                ),
                const SizedBox(height: TetriSpace.x24),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TetriTypography.headline.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: TetriSpace.x12),
                AmountText(
                  amount,
                  size: AmountSize.title,
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: TetriSpace.x16),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TetriTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: TetriSpace.x48),
                PrimaryButton(label: actionLabel, onPressed: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
