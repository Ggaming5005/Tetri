import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/money.dart';
import '../../core/strings.dart';
import '../../core/strings_banking.dart';
import '../browse_tokens.dart';
import '../tokens.dart';
import '../typography.dart';
import 'account_card.dart';
import 'avatar.dart';
import 'buttons.dart';
import 'empty_state.dart';
import 'inline_banner.dart';
import 'skeleton.dart';

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: TetriTypography.headline.copyWith(
            color: TetriColors.of(context).textPrimary,
          ),
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: TetriSpace.x8),
        Text(
          subtitle!,
          style: TetriTypography.body.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
      ],
    ],
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: TetriTypography.title.copyWith(
              color: TetriColors.of(context).textPrimary,
            ),
          ),
        ),
      ),
      if (actionLabel != null)
        TetriTextButton(label: actionLabel!, onPressed: onAction),
    ],
  );
}

class PageMessage extends StatelessWidget {
  const PageMessage({
    super.key,
    this.icon = PhosphorIconsRegular.cloudSlash,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Skeleton(height: TetriSizes.listRow64),
      SizedBox(height: TetriSpace.x16),
      Skeleton(height: TetriSizes.listRow64),
      SizedBox(height: TetriSpace.x16),
      Skeleton(height: TetriSizes.listRow64),
    ],
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TetriRadii.r12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: TetriSizes.button56,
                    child: Icon(
                      icon,
                      size: TetriSizes.icon24,
                      color: onTap == null
                          ? colors.textDisabled
                          : colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: TetriSpace.x8),
                Text(
                  label,
                  style: TetriTypography.label.copyWith(
                    color: onTap == null
                        ? colors.textDisabled
                        : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountPager extends StatefulWidget {
  const AccountPager({
    super.key,
    required this.accounts,
    required this.onSelected,
  });
  final List<MoneyAccount> accounts;
  final ValueChanged<MoneyAccount> onSelected;
  @override
  State<AccountPager> createState() => _AccountPagerState();
}

class _AccountPagerState extends State<AccountPager> {
  final _controller = PageController(
    viewportFraction: TetriBrowseSizes.accountPageFraction,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth =
          constraints.maxWidth * TetriBrowseSizes.accountPageFraction -
          TetriSpace.x12;
      final textWidth = math.max(
        TetriSizes.tap48,
        cardWidth -
            TetriSpace.x24 * 2 -
            TetriSizes.currencyFlag40 -
            TetriSpace.x12,
      );
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: textWidth);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      var height = TetriBrowseSizes.accountPagerHeight;
      for (final account in widget.accounts) {
        final labelHeight =
            measure(account.currency, TetriTypography.title) +
            measure(
              TetriStrings.currencyName(account.currency),
              TetriTypography.label,
            );
        final amountHeight =
            MediaQuery.textScalerOf(context)
                .scale(TetriTypography.titleAmount.fontSize!) *
            TetriTypography.titleAmount.height!;
        height = math.max(
          height,
          TetriSpace.x24 * 2 +
              math.max(TetriSizes.currencyFlag40, labelHeight) +
              TetriSpace.x24 +
              amountHeight,
        );
      }
      return SizedBox(
        height: height,
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          itemCount: widget.accounts.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: TetriSpace.x12),
            child: AccountCard(
              account: widget.accounts[index],
              onTap: () => widget.onSelected(widget.accounts[index]),
            ),
          ),
        ),
      );
    },
  );
}

class DateSection extends StatelessWidget {
  const DateSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          top: TetriSpace.x24,
          bottom: TetriSpace.x8,
        ),
        child: Text(
          title,
          style: TetriTypography.label.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
      ),
      ...children,
    ],
  );
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, this.value, this.trailing})
    : assert(value != null || trailing != null);
  final String label;
  final String? value;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TetriSpace.x12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TetriTypography.body.copyWith(
              color: TetriColors.of(context).textSecondary,
            ),
          ),
        ),
        const SizedBox(width: TetriSpace.x16),
        Expanded(
          child:
              trailing ??
              Text(
                value!,
                textAlign: TextAlign.end,
                style: TetriTypography.body.copyWith(
                  color: TetriColors.of(context).textPrimary,
                ),
              ),
        ),
      ],
    ),
  );
}

class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.userId,
    required this.name,
    required this.handle,
    this.email,
  });
  final String userId;
  final String name;
  final String handle;
  final String? email;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Avatar(userId: userId, name: name),
      const SizedBox(width: TetriSpace.x16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TetriTypography.title.copyWith(
                color: TetriColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: TetriSpace.x4),
            Text(
              handle,
              style: TetriTypography.body.copyWith(
                color: TetriColors.of(context).textSecondary,
              ),
            ),
            if (email != null)
              Text(
                email!,
                style: TetriTypography.label.copyWith(
                  color: TetriColors.of(context).textSecondary,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ReferenceCopy extends StatefulWidget {
  const ReferenceCopy({super.key, required this.reference});
  final String reference;
  @override
  State<ReferenceCopy> createState() => _ReferenceCopyState();
}

class _ReferenceCopyState extends State<ReferenceCopy> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeading(title: BankingStrings.reference),
      const SizedBox(height: TetriSpace.x8),
      Text(
        widget.reference,
        style: TetriTypography.body.copyWith(
          color: TetriColors.of(context).textSecondary,
        ),
      ),
      TetriTextButton(
        label: BankingStrings.copyReference,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.reference));
          if (mounted) setState(() => _copied = true);
        },
      ),
      if (_copied) const InlineBanner(message: BankingStrings.referenceCopied),
    ],
  );
}

class TetriNavigation extends StatelessWidget {
  const TetriNavigation({super.key, required this.selectedIndex});
  final int selectedIndex;
  @override
  Widget build(BuildContext context) {
    final colors = TetriColors.of(context);
    const labels = [
      BankingStrings.home,
      BankingStrings.activity,
      BankingStrings.settings,
    ];
    const icons = [
      PhosphorIconsRegular.house,
      PhosphorIconsRegular.clockCounterClockwise,
      PhosphorIconsRegular.gearSix,
    ];
    const routes = ['/home', '/activity', '/settings'];
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: colors.bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TetriSpace.x24,
            vertical: TetriSpace.x8,
          ),
          child: Row(
            children: [
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: Semantics(
                    selected: index == selectedIndex,
                    button: true,
                    label: labels[index],
                    onTap: () => context.go(routes[index]),
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go(routes[index]),
                          borderRadius: BorderRadius.circular(TetriRadii.r12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: TetriSizes.button56,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icons[index],
                                  size: TetriSizes.icon24,
                                  color: index == selectedIndex
                                      ? colors.accentText
                                      : colors.textSecondary,
                                ),
                                const SizedBox(height: TetriSpace.x4),
                                Text(
                                  labels[index],
                                  style: TetriTypography.label.copyWith(
                                    color: index == selectedIndex
                                        ? colors.accentText
                                        : colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class BrowseBackButton extends StatelessWidget {
  const BrowseBackButton({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TetriTextButton(
      label: BankingStrings.back,
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  );
}
