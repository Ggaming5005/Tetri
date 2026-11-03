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
    this.isPending = false,
    this.message,
  });

  final String title;
  final Money amount;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isSuccess;
  final bool isPending;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = Padding(
          padding: const EdgeInsets.symmetric(vertical: TetriSpace.x24),
          child: _summary(context),
        );
        final action = PrimaryButton(
          key: const ValueKey('status-action'),
          label: actionLabel,
          onPressed: onAction,
        );
        if (!constraints.hasBoundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              summary,
              const SizedBox(height: TetriSpace.x24),
              action,
            ],
          );
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Center(child: summary)),
                  const SizedBox(height: TetriSpace.x24),
                  action,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summary(BuildContext context) {
    final colors = TetriColors.of(context);
    return Column(
      key: const ValueKey('status-summary'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPending
              ? PhosphorIconsRegular.clock
              : isSuccess
              ? PhosphorIconsRegular.checkCircle
              : PhosphorIconsRegular.warningCircle,
          size: TetriSizes.statusIcon,
          color: isPending
              ? colors.textSecondary
              : isSuccess
              ? colors.positive
              : colors.negative,
        ),
        const SizedBox(height: TetriSpace.x24),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TetriTypography.headline.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: TetriSpace.x12),
        AmountText(amount, size: AmountSize.title, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: TetriSpace.x16),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: TetriTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
