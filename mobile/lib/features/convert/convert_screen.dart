import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/api_models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/strings_money.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/components.dart';
import '../../design/components/money_flow_components.dart';
import '../../design/tokens.dart';
import '../home/banking_providers.dart';
import 'conversion_controller.dart';

class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key, this.initialCurrency});
  final String? initialCurrency;
  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  late final ConversionController _controller;
  late String _from, _to;
  String _value = '0';
  bool _resultVisible = false, _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    _from = const ['GEL', 'USD', 'EUR'].contains(widget.initialCurrency)
        ? widget.initialCurrency!
        : 'USD';
    _to = _from == 'GEL' ? 'USD' : 'GEL';
    _controller = ConversionController(ref.read(bankApiProvider))
      ..addListener(_changed);
    _controller.updateInput(Money(0, _from), _to);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _update({String? from, String? to, String? value}) {
    setState(() {
      if (from != null) {
        if (from == _to) _to = _from;
        _from = from;
      }
      if (to != null) _to = to;
      if (value != null) _value = value;
    });
    _controller.updateInput(Money(MoneyInput.minorUnits(_value), _from), _to);
  }

  Future<void> _continue() async {
    if (_reviewOpen || _controller.reviewLoading) return;
    if (await _controller.openReview() && mounted) await _showReview();
  }

  Future<void> _showReview() async {
    if (_reviewOpen || !mounted) return;
    _reviewOpen = true;
    final original = _controller.review ?? _controller.preview;
    if (original == null) {
      _reviewOpen = false;
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: moneySheetAnimation(context),
      builder: (sheetContext) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final quote = _controller.review ?? original;
          final busy = _controller.isSubmitting || _controller.reviewLoading;
          return PopScope(
            canPop: !busy && !_controller.uncertain,
            child: MoneyReviewSheet(
              title: MoneyStrings.reviewConversion,
              rows: _rows(quote),
              notice:
                  _controller.error?.message ??
                  (_controller.refreshed ? MoneyStrings.quoteRefreshed : null),
              confirmLabel: _controller.review == null
                  ? MoneyStrings.requestNewQuote
                  : MoneyStrings.convertConfirm,
              isLoading: busy,
              onEdit: busy || _controller.uncertain
                  ? null
                  : () => Navigator.pop(sheetContext, false),
              onConfirm: () async {
                if (_controller.review == null) {
                  await _controller.openReview();
                  return;
                }
                await _controller.confirm();
                if (_controller.needsReview) return;
                if (mounted && _controller.receipt != null) {
                  refreshBankViews(ref);
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
              },
            ),
          );
        },
      ),
    );
    _reviewOpen = false;
    if (mounted) setState(() => _resultVisible = confirmed == true);
  }

  List<ReviewLine> _rows(FxQuote quote) => [
    ReviewLine.money(MoneyStrings.amount, quote.amountIn),
    ReviewLine.money(MoneyStrings.youGet, quote.netOut),
    ReviewLine.money(MoneyStrings.fee, quote.fee),
    ReviewLine.text(
      MoneyStrings.rate,
      MoneyStrings.rateText(
        quote.amountIn.currency,
        quote.rate,
        quote.netOut.currency,
      ),
    ),
    ReviewLine.text(
      MoneyStrings.rateDate,
      MoneyStrings.dateText(quote.rateDate),
    ),
    ReviewLine.money(MoneyStrings.total, quote.amountIn),
  ];

  Future<void> _retry() async {
    await _controller.confirm();
    if (!mounted) return;
    if (_controller.needsReview) {
      await _showReview();
    } else if (_controller.receipt != null) {
      refreshBankViews(ref);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_controller.isSubmitting && !_controller.uncertain,
    child: TetriScaffold(
      child: _resultVisible
          ? _result()
          : ref
                .watch(accountsProvider)
                .when(
                  loading: () => const LoadingList(),
                  error: (_, _) => PageMessage(
                    message: MoneyStrings.accountsUnavailable,
                    actionLabel: MoneyStrings.retry,
                    onAction: () => ref.invalidate(accountsProvider),
                  ),
                  data: (accounts) => accounts.length < 2
                      ? PageMessage(
                          message: MoneyStrings.noAccounts,
                          actionLabel: MoneyStrings.retry,
                          onAction: () => ref.invalidate(accountsProvider),
                        )
                      : _input(accounts),
                ),
    ),
  );

  Widget _input(List<MoneyAccount> accounts) {
    final from = accounts.firstWhere(
      (account) => account.currency == _from,
      orElse: () => accounts.first,
    );
    final targets = accounts
        .where((account) => account.currency != from.currency)
        .toList();
    final to = targets.firstWhere(
      (account) => account.currency == _to,
      orElse: () => targets.first,
    );
    final amount = Money(MoneyInput.minorUnits(_value), from.currency);
    final insufficient = amount.minor > from.balance.minor;
    final busy = _controller.reviewLoading || _reviewOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlowNavigation(onBack: busy ? null : () => context.go('/home')),
        const SizedBox(height: TetriSpace.x16),
        const PageHeading(
          title: MoneyStrings.convertTitle,
          subtitle: MoneyStrings.convertHint,
        ),
        const SizedBox(height: TetriSpace.x24),
        const SectionHeading(title: MoneyStrings.from),
        const SizedBox(height: TetriSpace.x8),
        CurrencyPicker(
          accounts: accounts,
          selected: from,
          enabled: !busy,
          onChanged: (account) => _update(from: account.currency),
        ),
        const SizedBox(height: TetriSpace.x16),
        const SectionHeading(title: MoneyStrings.to),
        const SizedBox(height: TetriSpace.x8),
        CurrencyPicker(
          accounts: targets,
          selected: to,
          enabled: !busy,
          onChanged: (account) => _update(to: account.currency),
        ),
        const SizedBox(height: TetriSpace.x24),
        MoneyEntrySummary(amount: amount, available: from.balance),
        const SizedBox(height: TetriSpace.x16),
        if (insufficient)
          InlineBanner(
            message: MoneyStrings.notEnough(from.currency),
            kind: BannerKind.warning,
          ),
        AmountKeypad(
          value: _value,
          enabled: !busy,
          onChanged: (value) => _update(value: value),
        ),
        const SizedBox(height: TetriSpace.x16),
        if (_controller.previewLoading)
          const Skeleton(height: TetriSizes.scaffoldExpandedHeight)
        else if (_controller.error != null)
          PageMessage(
            message: _controller.error!.message,
            actionLabel: MoneyStrings.retry,
            onAction: _controller.loadPreview,
          )
        else if (_controller.preview != null)
          QuoteSummary(quote: _controller.preview!)
        else
          const PageMessage(
            icon: PhosphorIconsRegular.arrowsLeftRight,
            message: MoneyStrings.quoteEmpty,
          ),
        const SizedBox(height: TetriSpace.x24),
        PrimaryButton(
          label: MoneyStrings.continueLabel,
          isLoading: _controller.reviewLoading,
          onPressed:
              !busy &&
                  amount.minor > 0 &&
                  !insufficient &&
                  _controller.preview != null
              ? _continue
              : null,
        ),
      ],
    );
  }

  Widget _result() {
    if (_controller.isSubmitting || _controller.reviewLoading) {
      return const LoadingList();
    }
    final successful = _controller.receipt != null;
    final amount =
        _controller.receipt?.netOut ??
        _controller.review?.netOut ??
        _controller.preview!.netOut;
    return StatusView(
      title: successful
          ? MoneyStrings.converted
          : _controller.uncertain
          ? MoneyStrings.checking
          : MoneyStrings.notConverted,
      amount: amount,
      isSuccess: successful,
      message: successful
          ? null
          : _controller.retryWindowExpired
          ? MoneyStrings.confirmationExpired
          : _controller.uncertain
          ? MoneyStrings.uncertain
          : _controller.error?.message ?? MoneyStrings.genericFailure,
      actionLabel: successful
          ? MoneyStrings.done
          : _controller.retryWindowExpired
          ? MoneyStrings.checkActivity
          : _controller.uncertain
          ? MoneyStrings.retry
          : MoneyStrings.editAmount,
      onAction: successful
          ? () => context.go('/home')
          : _controller.retryWindowExpired
          ? () => context.go('/activity')
          : _controller.uncertain
          ? _retry
          : () {
              ref.invalidate(accountsProvider);
              setState(() => _resultVisible = false);
              _update();
            },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }
}
