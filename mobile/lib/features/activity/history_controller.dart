import 'package:flutter/foundation.dart';

import '../../core/api_models.dart';
import '../../core/api.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this.api, {this.accountId});
  final BankApi api;
  final String? accountId;
  List<TransactionView> items = [];
  String filter = 'all';
  String? nextCursor;
  Object? error;
  bool loading = true;
  bool loadingMore = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> refresh({String? newFilter}) async {
    final generation = ++_generation;
    if (newFilter != null) filter = newFilter;
    loading = true;
    loadingMore = false;
    error = null;
    items = [];
    nextCursor = null;
    notifyListeners();
    await _load(generation, null);
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || nextCursor == null) return;
    loadingMore = true;
    error = null;
    notifyListeners();
    await _load(_generation, nextCursor);
  }

  Future<void> _load(int generation, String? cursor) async {
    try {
      final page = await api.transactions(
        accountId: accountId,
        filter: filter,
        cursor: cursor,
      );
      if (_disposed || generation != _generation) return;
      final known = items.map((item) => item.id).toSet();
      items = [...items, ...page.items.where((item) => known.add(item.id))];
      nextCursor = page.nextCursor;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
