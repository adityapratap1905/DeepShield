import '../../../models/history_item_model.dart';

/// History repository — pure local/mock implementation.
/// The real data is provided by history_provider.dart which has full mock data.
class HistoryRepository {
  Future<List<HistoryItemModel>> getHistory({
    int page = 1,
    int limit = 20,
    String? filter,
    String? query,
  }) async {
    // Provider supplies mock data directly; this is a fallback no-op.
    return [];
  }

  Future<void> deleteHistoryItem(String id) async {
    // No-op: provider manages local state.
  }

  Future<void> clearAllHistory() async {
    // No-op: provider manages local state.
  }
}
