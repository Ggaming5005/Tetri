import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../core/api_error.dart';
import '../../core/api_models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/strings_money.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/components.dart';
import '../../design/components/money_flow_components.dart';
import '../../design/tokens.dart';
import '../home/banking_providers.dart';
import 'transfer_controller.dart';

enum _SendStep { recipient, amount, result }

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, this.initialCurrency});
  final String? initialCurrency;
  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  late final TransferController _controller;
  final _search = TextEditingController();
  Timer? _searchTimer;
  int _searchRevision = 0;
  _SendStep _step = _SendStep.recipient;
  RecipientView? _recipient, _found;
  List<RecipientView> _recent = [];
  ApiError? _lookupError, _recentError;
  bool _lookupLoading = false, _recentLoading = true, _reviewOpen = false;
  String _value = '';
  late String _currency;

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency ?? 'GEL';
    _controller = TransferController(ref.read(bankApiProvider))
      ..addListener(_changed);
    unawaited(_loadRecent());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecent() async {
    setState(() {
      _recentLoading = true;
      _recentError = null;
    });
    try {
      final page = await ref
          .read(bankApiProvider)
          .transactions(filter: 'sent', pageSize: 20);
      final unique = <String, RecipientView>{};
      for (final transaction in page.items) {
        final person = transaction.counterparty;
        if (person != null) unique.putIfAbsent(person.handle, () => person);
      }
      if (mounted) setState(() => _recent = unique.values.take(5).toList());
    } catch (error) {
      if (mounted) setState(() => _recentError = ApiError.from(error));
    } finally {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  void _searchChanged(String value) {
    _searchTimer?.cancel();
    final revision = ++_searchRevision;
    final handle = value.trim();
    setState(() {
      _found = null;
      _lookupError = null;
      _lookupLoading = handle.isNotEmpty;
    });
    if (handle.isEmpty) return;
    _searchTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final person = await ref
            .read(bankApiProvider)
            .lookup(handle.startsWith('@') ? handle : '@$handle');
        if (mounted && revision == _searchRevision) {
          setState(() => _found = person);
        }
      } catch (error) {
        if (mounted && revision == _searchRevision) {
          setState(() => _lookupError = ApiError.from(error));
        }
      } finally {
        if (mounted && revision == _searchRevision) {
          setState(() => _lookupLoading = false);
        }
      }
    });
  }

  void _select(RecipientView recipient) {
    FocusScope.of(context).unfocus();
    setState(() {
      _recipient = recipient;
      _step = _SendStep.amount;
    });
  }

  Future<void> _openReview(Money amount) async {
    if (_reviewOpen) return;
    FocusScope.of(context).unfocus();
    _reviewOpen = true;
    _controller.openReview(_recipient!, amount);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: TetriSizes.sheetMaxWidth),
      useSafeArea: true,
      sheetAnimationStyle: moneySheetAnimation(context),
      builder: (sheetContext) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => PopScope(
          canPop: !_controller.isSubmitting && !_controller.uncertain,
          child: MoneyReviewSheet(
            title: MoneyStrings.reviewSend,
            rows: [
              ReviewLine.text(MoneyStrings.to, _recipient!.handle),
              ReviewLine.money(MoneyStrings.amount, amount),
              ReviewLine.money(MoneyStrings.fee, Money(0, amount.currency)),
              ReviewLine.money(MoneyStrings.total, amount),
            ],
            confirmLabel: MoneyStrings.sendConfirm,
            isLoading: _controller.isSubmitting,
            onEdit: _controller.isSubmitting || _controller.uncertain
                ? null
                : () => Navigator.pop(sheetContext, false),
            onConfirm: () async {
              await _controller.confirm();
              if (mounted && _controller.receipt != null) refreshBankViews(ref);
              if (sheetContext.mounted) Navigator.pop(sheetContext, true);
            },
          ),
        ),
      ),
    );
    _reviewOpen = false;
    if (mounted && confirmed == true) setState(() => _step = _SendStep.result);
  }

  Future<void> _retry() async {
    await _controller.confirm();
    if (mounted && _controller.receipt != null) refreshBankViews(ref);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    return PopScope(
      canPop: !_controller.isSubmitting && !_controller.uncertain,
      child: TetriScaffold(
        fillViewport: _step == _SendStep.result,
        bottomAction: _step == _SendStep.amount
            ? accounts.whenOrNull(
                data: (items) => items.isEmpty ? null : _continueButton(items),
              )
            : null,
        child: _step == _SendStep.result
            ? _result()
            : accounts.when(
                loading: () => const LoadingList(),
                error: (error, _) => PageMessage(
                  message: MoneyStrings.accountsUnavailable,
                  actionLabel: MoneyStrings.retry,
                  onAction: () => ref.invalidate(accountsProvider),
                ),
                data: (items) => items.isEmpty
                    ? PageMessage(
                        message: MoneyStrings.noAccounts,
                        actionLabel: MoneyStrings.retry,
                        onAction: () => ref.invalidate(accountsProvider),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FlowNavigation(
                            title: _step == _SendStep.amount
                                ? MoneyStrings.send
                                : null,
                            onBack: _reviewOpen
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    if (_step == _SendStep.amount) {
                                      setState(
                                        () => _step = _SendStep.recipient,
                                      );
                                    } else {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/home');
                                      }
                                    }
                                  },
                          ),
                          const SizedBox(height: TetriSpace.x16),
                          if (_step == _SendStep.recipient)
                            _recipients()
                          else
                            _amount(items),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _recipients() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        title: MoneyStrings.recipientTitle,
        subtitle: MoneyStrings.recipientHint,
      ),
      const SizedBox(height: TetriSpace.x24),
      TextInput(
        label: MoneyStrings.searchLabel,
        hint: MoneyStrings.searchHint,
        controller: _search,
        variant: TextInputVariant.search,
        onChanged: _searchChanged,
      ),
      const SizedBox(height: TetriSpace.x24),
      if (_search.text.trim().isNotEmpty) ...[
        if (_lookupLoading)
          const LoadingList()
        else if (_found != null)
          RecipientRow(recipient: _found!, onTap: () => _select(_found!))
        else
          PageMessage(
            icon: PhosphorIconsRegular.magnifyingGlass,
            message: _lookupError?.status == 404
                ? MoneyStrings.recipientNotFound
                : _lookupError?.message ?? MoneyStrings.searchEmpty,
            actionLabel: _lookupError?.retryable == true
                ? MoneyStrings.retry
                : null,
            onAction: _lookupError?.retryable == true
                ? () => _searchChanged(_search.text)
                : null,
          ),
      ] else if (_recentLoading)
        const LoadingList()
      else if (_recentError != null)
        PageMessage(
          message: MoneyStrings.recipientsUnavailable,
          actionLabel: MoneyStrings.retry,
          onAction: _loadRecent,
        )
      else if (_recent.isEmpty)
        const PageMessage(
          icon: PhosphorIconsRegular.magnifyingGlass,
          message: MoneyStrings.searchEmpty,
        )
      else ...[
        const SectionHeading(title: MoneyStrings.recent),
        const SizedBox(height: TetriSpace.x8),
        for (final person in _recent)
          RecipientRow(recipient: person, onTap: () => _select(person)),
      ],
    ],
  );

  Widget _amount(List<MoneyAccount> accounts) {
    final selected = accounts.firstWhere(
      (account) => account.currency == _currency,
      orElse: () => accounts.first,
    );
    final amount = Money(MoneyInput.minorUnits(_value), selected.currency);
    final insufficient = amount.minor > selected.balance.minor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipientRow(
          recipient: _recipient!,
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _step = _SendStep.recipient);
          },
        ),
        const SizedBox(height: TetriSpace.x16),
        MoneyAccountPanel(
          label: MoneyStrings.youSend,
          available: selected.balance,
          selector: CurrencyPicker(
            compact: true,
            accounts: accounts,
            selected: selected,
            enabled: !_reviewOpen,
            onChanged: (account) => setState(() {
              _currency = account.currency;
              _value = '';
            }),
          ),
          child: MoneyAmountInput(
            value: _value,
            currency: selected.currency,
            enabled: !_reviewOpen,
            errorText: insufficient
                ? MoneyStrings.notEnough(selected.currency)
                : null,
            onChanged: (value) => setState(() => _value = value),
          ),
        ),
      ],
    );
  }

  Widget _continueButton(List<MoneyAccount> accounts) {
    final selected = accounts.firstWhere(
      (account) => account.currency == _currency,
      orElse: () => accounts.first,
    );
    final amount = Money(MoneyInput.minorUnits(_value), selected.currency);
    return PrimaryButton(
      label: MoneyStrings.continueLabel,
      onPressed:
          amount.minor > 0 &&
              amount.minor <= selected.balance.minor &&
              !_reviewOpen
          ? () => _openReview(amount)
          : null,
    );
  }

  Widget _result() {
    if (_controller.isSubmitting) return const LoadingList();
    final successful = _controller.receipt != null;
    return StatusView(
      title: successful
          ? MoneyStrings.sent
          : _controller.uncertain
          ? MoneyStrings.checking
          : MoneyStrings.notSent,
      amount: _controller.review!.amount,
      isSuccess: successful,
      isPending: _controller.uncertain,
      message: successful
          ? MoneyStrings.recipient(_controller.review!.recipient.displayName)
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
              setState(() => _step = _SendStep.amount);
            },
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }
}
