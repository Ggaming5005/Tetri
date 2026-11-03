import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../tokens.dart';
import '../typography.dart';
import 'account_card.dart';
import 'amount_text.dart';

class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({
    super.key,
    required this.accounts,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final List<MoneyAccount> accounts;
  final MoneyAccount selected;
  final ValueChanged<MoneyAccount> onChanged;
  final bool enabled;
  final bool compact;

  Future<void> _choose(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final colors = TetriColors.of(context);
    final chosen = await showModalBottomSheet<MoneyAccount>(
      context: context,
      backgroundColor: colors.surfaceRaised,
      elevation: TetriSizes.zero,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: TetriMotion.screen,
              reverseDuration: TetriMotion.screen,
              curve: TetriMotion.curve,
              reverseCurve: TetriMotion.curve,
            ),
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: TetriSizes.sheetMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TetriRadii.r24),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TetriSpace.x24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    TetriStrings.chooseAccount,
                    style: TetriTypography.headline.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: TetriSpace.x24),
                for (final account in accounts)
                  _AccountChoice(
                    account: account,
                    selected: account.id == selected.id,
                    onTap: () => Navigator.pop(context, account),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen != null && context.mounted) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    final canChoose = enabled && accounts.isNotEmpty;
    return Semantics(
      button: true,
      enabled: canChoose,
      label: TetriStrings.chooseAccount,
      child: Material(
        color: compact ? Colors.transparent : colors.surface,
        borderRadius: BorderRadius.circular(TetriRadii.r12),
        child: InkWell(
          onTap: canChoose ? () => _choose(context) : null,
          borderRadius: BorderRadius.circular(TetriRadii.r12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TetriSizes.tap48),
            child: Padding(
              padding: compact
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(
                      horizontal: TetriSpace.x16,
                      vertical: TetriSpace.x12,
                    ),
              child: Row(
                children: [
                  CurrencyBadge(currency: selected.currency),
                  const SizedBox(width: TetriSpace.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.currency,
                          style: TetriTypography.title.copyWith(
                            color: canChoose
                                ? colors.textPrimary
                                : colors.textDisabled,
                          ),
                        ),
                        if (!compact)
                          AmountText(selected.balance, size: AmountSize.label),
                      ],
                    ),
                  ),
                  Icon(
                    PhosphorIconsRegular.caretDown,
                    size: TetriSizes.icon24,
                    color: canChoose
                        ? colors.textSecondary
                        : colors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountChoice extends StatelessWidget {
  const _AccountChoice({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final MoneyAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('currency-account-${account.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(TetriRadii.r12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TetriSizes.listRow64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TetriSpace.x12),
            child: Row(
              children: [
                CurrencyBadge(currency: account.currency),
                const SizedBox(width: TetriSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TetriStrings.currencyName(account.currency),
                        style: TetriTypography.title.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      AmountText(account.balance, size: AmountSize.label),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    PhosphorIconsRegular.check,
                    size: TetriSizes.icon24,
                    color: colors.accentText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
