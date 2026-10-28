import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/history_item_model.dart';
import '../data/history_repository.dart';

/// Filter options for history list.
enum HistoryFilter { all, safe, dangerous }

final historyRepositoryProvider =
    Provider<HistoryRepository>((_) => HistoryRepository());

final historyFilterProvider =
    StateProvider<HistoryFilter>((_) => HistoryFilter.all);

final historySearchProvider = StateProvider<String>((_) => '');

/// Local scan history, filtered by the current screen controls.
final historyProvider =
    FutureProvider.autoDispose<List<HistoryItemModel>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final query = ref.watch(historySearchProvider);
  final filterName = switch (filter) {
    HistoryFilter.all => null,
    HistoryFilter.safe => 'safe',
    HistoryFilter.dangerous => 'dangerous',
  };

  return ref.read(historyRepositoryProvider).getHistory(
        page: 1,
        limit: 100,
        filter: filterName,
        query: query,
      );
});
