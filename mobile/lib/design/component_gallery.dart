import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../core/money.dart';
import '../core/strings.dart';
import 'components/components.dart';
import 'tokens.dart';
import 'typography.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  static const accounts = [
    MoneyAccount(id: 'gel', balance: Money(100000, 'GEL')),
    MoneyAccount(id: 'usd', balance: Money(30000, 'USD')),
    MoneyAccount(id: 'eur', balance: Money(30000, 'EUR')),
  ];
  String amount = '25';
  MoneyAccount selected = accounts.first;
  bool biometrics = true;
  String filter = TetriStrings.all;

  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return TetriScaffold(
      title: TetriStrings.gallery,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            TetriStrings.galleryIntroduction,
            style: TetriTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: TetriSpace.x24),
          TetriSegmentedControl<ThemeMode>(
            segments: const {
              ThemeMode.system: TetriStrings.system,
              ThemeMode.light: TetriStrings.light,
              ThemeMode.dark: TetriStrings.dark,
            },
            value: widget.themeMode,
            onChanged: widget.onThemeChanged,
          ),
          _section(TetriStrings.typography),
          const TetriWordmark(),
          const TetriArtwork(),
          const AmountText(Money(123456, 'GEL'), size: AmountSize.display),
          const SizedBox(height: TetriSpace.x16),
          const AmountText(Money(30000, 'USD'), size: AmountSize.title),
          const AmountText(Money(2500, 'EUR'), showSign: true),
          const AmountText(Money(-2500, 'GEL'), showSign: true),
          _section(TetriStrings.accounts),
          for (final account in accounts) ...[
            AccountCard(
              account: account,
              onTap: () => setState(() => selected = account),
            ),
            const SizedBox(height: TetriSpace.x12),
          ],
          CurrencyPicker(
            accounts: accounts,
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
          const SizedBox(height: TetriSpace.x12),
          CurrencyPicker(
            accounts: accounts,
            selected: selected,
            onChanged: (_) {},
            enabled: false,
          ),
          _section(TetriStrings.transactions),
          const TransactionRow(
            title: TetriStrings.demoNino,
            subtitle: TetriStrings.demoDate,
            amount: Money(-2500, 'GEL'),
            leading: Avatar(userId: 'nino', name: TetriStrings.demoNino),
          ),
          const TransactionRow(
            title: TetriStrings.demoGiorgi,
            subtitle: TetriStrings.demoDate,
            amount: Money(12500, 'GEL'),
            leading: Avatar(userId: 'giorgi', name: TetriStrings.demoGiorgi),
          ),
          _section(TetriStrings.controls),
          PrimaryButton(
            label: TetriStrings.sendMoney,
            onPressed: () => _review(),
          ),
          const SizedBox(height: TetriSpace.x12),
          const PrimaryButton(
            label: TetriStrings.continueLabel,
            onPressed: null,
          ),
          const SizedBox(height: TetriSpace.x12),
          const PrimaryButton(
            label: TetriStrings.continueLabel,
            onPressed: null,
            isLoading: true,
          ),
          const SizedBox(height: TetriSpace.x12),
          SecondaryButton(label: TetriStrings.cancel, onPressed: () {}),
          const SizedBox(height: TetriSpace.x12),
          const SecondaryButton(label: TetriStrings.cancel, onPressed: null),
          const SizedBox(height: TetriSpace.x12),
          const SecondaryButton(
            label: TetriStrings.cancel,
            onPressed: null,
            isLoading: true,
          ),
          TetriTextButton(label: TetriStrings.retry, onPressed: () {}),
          const TetriTextButton(label: TetriStrings.retry, onPressed: null),
          const TetriTextButton(
            label: TetriStrings.retry,
            onPressed: null,
            isLoading: true,
          ),
          const TextInput(
            label: TetriStrings.email,
            hint: TetriStrings.emailHint,
          ),
          const SizedBox(height: TetriSpace.x16),
          const TextInput(
            label: TetriStrings.email,
            hint: TetriStrings.emailHint,
            errorText: TetriStrings.invalidEmail,
          ),
          const SizedBox(height: TetriSpace.x16),
          const TextInput(
            label: TetriStrings.email,
            hint: TetriStrings.emailHint,
            enabled: false,
          ),
          const SizedBox(height: TetriSpace.x16),
          const TextInput(
            label: TetriStrings.password,
            hint: TetriStrings.passwordHint,
            variant: TextInputVariant.password,
          ),
          const SizedBox(height: TetriSpace.x16),
          const TextInput(
            label: TetriStrings.search,
            hint: TetriStrings.handleHint,
            variant: TextInputVariant.search,
          ),
          const SizedBox(height: TetriSpace.x32),
          AmountText(
            Money(MoneyInput.minorUnits(amount), selected.currency),
            size: AmountSize.title,
          ),
          AmountKeypad(
            value: amount,
            onChanged: (value) => setState(() => amount = value),
          ),
          AmountKeypad(value: amount, onChanged: (_) {}, enabled: false),
          _section(TetriStrings.preferences),
          TetriSwitch(
            label: TetriStrings.biometricUnlock,
            value: biometrics,
            onChanged: (value) => setState(() => biometrics = value),
          ),
          const TetriSwitch(
            label: TetriStrings.biometricUnlock,
            value: false,
            onChanged: null,
          ),
          const TetriSwitch(
            label: TetriStrings.biometricUnlock,
            value: true,
            onChanged: null,
          ),
          const TetriSegmentedControl<String>(
            segments: {
              TetriStrings.all: TetriStrings.all,
              TetriStrings.sent: TetriStrings.sent,
            },
            value: TetriStrings.all,
            onChanged: null,
          ),
          Wrap(
            spacing: TetriSpace.x8,
            runSpacing: TetriSpace.x8,
            children: [
              for (final value in [
                TetriStrings.all,
                TetriStrings.sent,
                TetriStrings.received,
                TetriStrings.conversions,
              ])
                TetriFilterChip(
                  label: value,
                  selected: filter == value,
                  onSelected: (_) => setState(() => filter = value),
                ),
            ],
          ),
          _section(TetriStrings.feedback),
          const TetriFilterChip(
            label: TetriStrings.all,
            selected: true,
            onSelected: null,
          ),
          const InlineBanner(message: TetriStrings.sandbox),
          const SizedBox(height: TetriSpace.x16),
          const InlineBanner(
            message: TetriStrings.quoteRefreshed,
            kind: BannerKind.warning,
          ),
          const SizedBox(height: TetriSpace.x24),
          const Skeleton(width: double.infinity, height: TetriSizes.listRow),
          const SizedBox(height: TetriSpace.x24),
          EmptyState(
            icon: PhosphorIconsRegular.receipt,
            message: TetriStrings.noActivity,
            actionLabel: TetriStrings.sendMoney,
            onAction: () => _review(),
          ),
          const EmptyState(
            icon: PhosphorIconsRegular.receipt,
            message: TetriStrings.noActivity,
          ),
          SecondaryButton(
            label: TetriStrings.loadingReview,
            onPressed: () => _review(isLoading: true),
          ),
          const SizedBox(height: TetriSpace.x12),
          SecondaryButton(
            label: TetriStrings.disabledReview,
            onPressed: () => _review(disabled: true),
          ),
          const SizedBox(height: TetriSpace.x12),
          SecondaryButton(
            label: TetriStrings.sent,
            onPressed: () => _status(true),
          ),
          const SizedBox(height: TetriSpace.x12),
          SecondaryButton(
            label: TetriStrings.transferFailed,
            onPressed: () => _status(false),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: TetriSpace.x48, bottom: TetriSpace.x24),
    child: Text(
      title,
      style: TetriTypography.title.copyWith(
        color: TetriColors.of(context).textPrimary,
      ),
    ),
  );

  void _review({bool isLoading = false, bool disabled = false}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: TetriMotion.screen,
                reverseDuration: TetriMotion.screen,
                curve: TetriMotion.curve,
                reverseCurve: TetriMotion.curve,
              ),
        builder: (context) => ReviewSheet(
          title: TetriStrings.reviewTransfer,
          rows: const [
            ReviewLine.text(TetriStrings.to, TetriStrings.demoNinoHandle),
            ReviewLine.money(TetriStrings.amount, Money(2500, 'GEL')),
            ReviewLine.money(TetriStrings.fee, Money(0, 'GEL')),
            ReviewLine.money(TetriStrings.total, Money(2500, 'GEL')),
          ],
          isLoading: isLoading,
          onConfirm: disabled ? null : () => Navigator.of(context).pop(),
        ),
      );

  void _status(bool success) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => TetriScaffold(
        child: StatusView(
          title: success ? TetriStrings.sent : TetriStrings.transferFailed,
          amount: const Money(2500, 'GEL'),
          actionLabel: TetriStrings.done,
          onAction: () => Navigator.of(context).pop(),
          isSuccess: success,
          message: success ? null : TetriStrings.tryAgain,
        ),
      ),
    ),
  );
}
