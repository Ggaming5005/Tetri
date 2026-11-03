import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/strings_banking.dart';
import '../../design/browse_tokens.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/selection_controls.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';
import '../home/banking_providers.dart';
import 'history_content.dart';
import 'history_controller.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final HistoryController _history;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _history = HistoryController(ref.read(bankApiProvider));
    unawaited(_history.refresh());
    _scroll.addListener(_loadNearEnd);
  }

  void _loadNearEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < TetriBrowseSizes.paginationThreshold &&
        _history.error == null) {
      unawaited(_history.loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      bankViewRevisionProvider,
      (previous, next) => unawaited(_history.refresh()),
    );
    const filters = {
      'all': BankingStrings.all,
      'sent': BankingStrings.sent,
      'received': BankingStrings.received,
      'conversions': BankingStrings.conversions,
    };
    return ListenableBuilder(
      listenable: _history,
      builder: (context, child) => TetriScaffold(
        title: BankingStrings.activity,
        scrollController: _scroll,
        bottomNavigationBar: const TetriNavigation(selectedIndex: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: TetriSpace.x8,
              runSpacing: TetriSpace.x4,
              children: [
                for (final filter in filters.entries)
                  TetriFilterChip(
                    label: filter.value,
                    selected: _history.filter == filter.key,
                    onSelected: (_) {
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                      unawaited(_history.refresh(newFilter: filter.key));
                    },
                  ),
              ],
            ),
            HistoryContent(controller: _history),
          ],
        ),
      ),
    );
  }
}
