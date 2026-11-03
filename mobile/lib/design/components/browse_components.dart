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

class DashboardHeading extends StatelessWidget {
  const DashboardHeading({
    super.key,
    required this.title,
    required this.onProfile,
    this.userId,
    this.name,
  });

  final String title;
  final String? userId, name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: PageHeading(title: title)),
      const SizedBox(width: TetriSpace.x16),
      IconButton(
        tooltip: BankingStrings.profile,
        onPressed: onProfile,
        padding: const EdgeInsets.all(TetriSpace.x4),
        constraints: const BoxConstraints(
          minWidth: TetriSizes.tap48,
          minHeight: TetriSizes.tap48,
        ),
        icon: ExcludeSemantics(
          child: userId != null && name != null
              ? Avatar(
                  userId: userId!,
                  name: name!,
                  size: TetriSizes.currencyFlag40,
                )
              : Icon(
                  PhosphorIconsRegular.userCircle,
                  size: TetriSizes.icon24,
                  color: TetriColors.of(context).textPrimary,
                ),
        ),
      ),
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
    this.onPageChanged,
  });
  final List<MoneyAccount> accounts;
  final ValueChanged<MoneyAccount> onSelected;
  final ValueChanged<MoneyAccount>? onPageChanged;
  @override
  State<AccountPager> createState() => _AccountPagerState();
}

class _AccountPagerState extends State<AccountPager> {
  final _controller = PageController(
    viewportFraction: TetriBrowseSizes.accountPageFraction,
  );
  int _currentPage = 0;
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
      final selected = widget.accounts.isEmpty
          ? 0
          : _currentPage.clamp(0, widget.accounts.length - 1);
      final colors = TetriColors.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: widget.accounts.length,
              onPageChanged: (index) {
                if (index == _currentPage) return;
                setState(() => _currentPage = index);
                widget.onPageChanged?.call(widget.accounts[index]);
              },
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: TetriSpace.x12),
                child: AccountCard(
                  account: widget.accounts[index],
                  onTap: () => widget.onSelected(widget.accounts[index]),
                ),
              ),
            ),
          ),
          if (widget.accounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TetriSpace.x12),
              child: Semantics(
                key: const ValueKey('account-page-position'),
                label:
                    '${BankingStrings.account} ${selected + 1}/${widget.accounts.length}, ${widget.accounts[selected].currency}',
                liveRegion: true,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (
                        var index = 0;
                        index < widget.accounts.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: TetriSpace.x8),
                        DecoratedBox(
                          key: ValueKey('account-page-indicator-$index'),
                          decoration: BoxDecoration(
                            color: index == selected
                                ? colors.accent
                                : colors.border,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(
                            dimension: TetriSpace.x8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    padding: const EdgeInsets.symmetric(vertical: TetriSpace.x8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final colors = TetriColors.of(context);
        final stack =
            constraints.maxWidth < TetriBrowseSizes.detailStackBreakpoint ||
            MediaQuery.textScalerOf(context)
                    .scale(TetriTypography.body.fontSize!) >=
                TetriTypography.body.fontSize! *
                    TetriBrowseSizes.accessibilityTextScale;
        final labelWidget = Text(
          label,
          style: (stack ? TetriTypography.label : TetriTypography.body)
              .copyWith(color: colors.textSecondary),
        );
        final valueWidget =
            trailing ??
            Text(
              value!,
              textAlign: stack ? TextAlign.start : TextAlign.end,
              style: TetriTypography.body.copyWith(color: colors.textPrimary),
            );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: TetriSpace.x4),
              valueWidget,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: TetriSpace.x16),
            Expanded(flex: 2, child: valueWidget),
          ],
        );
      },
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
      BankingStrings.payments,
      BankingStrings.activity,
    ];
    const icons = [
      PhosphorIconsRegular.house,
      PhosphorIconsRegular.arrowsLeftRight,
      PhosphorIconsRegular.clockCounterClockwise,
    ];
    const routes = ['/home', '/payments', '/activity'];
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: colors.bg,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TetriSizes.contentMaxWidth,
            ),
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
                              borderRadius: BorderRadius.circular(
                                TetriRadii.r12,
                              ),
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
                                      textAlign: TextAlign.center,
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
