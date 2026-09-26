import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/history_item_model.dart';
import '../../../models/scan_result_model.dart';
import '../data/history_repository.dart';

/// Filter options for history list
enum HistoryFilter { all, safe, dangerous }

final historyRepositoryProvider = Provider<HistoryRepository>((_) => HistoryRepository());

/// Current filter state
final historyFilterProvider = StateProvider<HistoryFilter>((_) => HistoryFilter.all);

/// Current search query
final historySearchProvider = StateProvider<String>((_) => '');

/// History list — refreshable + filterable
final historyProvider = FutureProvider.autoDispose<List<HistoryItemModel>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final query = ref.watch(historySearchProvider);

  // Simulate API + filter locally with mock data
  await Future.delayed(const Duration(milliseconds: 600));

  // TODO: Replace with real API call
  // return ref.read(historyRepositoryProvider).getHistory(
  //   filter: filter.name,
  //   query: query,
  // );

  final now = DateTime.now();
  final mockData = [
    HistoryItemModel(id: '1', scanType: ScanType.url, target: 'https://viral-news.com/deepfake-video', threatLevel: ThreatLevel.critical, isSafe: false, scannedAt: now.subtract(const Duration(minutes: 10)), confidenceScore: 0.98),
    HistoryItemModel(id: '2', scanType: ScanType.file, target: 'politician_speech_altered.mp4', threatLevel: ThreatLevel.high, isSafe: false, scannedAt: now.subtract(const Duration(hours: 1)), confidenceScore: 0.93),
    HistoryItemModel(id: '3', scanType: ScanType.url, target: 'https://google.com', threatLevel: ThreatLevel.safe, isSafe: true, scannedAt: now.subtract(const Duration(hours: 3)), confidenceScore: 0.99),
    HistoryItemModel(id: '4', scanType: ScanType.qr, target: 'https://apple.com/product/123', threatLevel: ThreatLevel.safe, isSafe: true, scannedAt: now.subtract(const Duration(hours: 6)), confidenceScore: 0.97),
    HistoryItemModel(id: '5', scanType: ScanType.file, target: 'report_2024.pdf', threatLevel: ThreatLevel.safe, isSafe: true, scannedAt: now.subtract(const Duration(days: 1)), confidenceScore: 0.95),
    HistoryItemModel(id: '6', scanType: ScanType.url, target: 'https://suspicious-offer.xyz', threatLevel: ThreatLevel.medium, isSafe: false, scannedAt: now.subtract(const Duration(days: 1, hours: 5)), confidenceScore: 0.72),
    HistoryItemModel(id: '7', scanType: ScanType.url, target: 'https://github.com', threatLevel: ThreatLevel.safe, isSafe: true, scannedAt: now.subtract(const Duration(days: 2)), confidenceScore: 0.99),
    HistoryItemModel(id: '8', scanType: ScanType.file, target: 'invoice_jan.xlsx', threatLevel: ThreatLevel.safe, isSafe: true, scannedAt: now.subtract(const Duration(days: 3)), confidenceScore: 0.91),
  ];

  // Apply filter
  var filtered = mockData;
  if (filter == HistoryFilter.safe) {
    filtered = mockData.where((i) => i.isSafe).toList();
  } else if (filter == HistoryFilter.dangerous) {
    filtered = mockData.where((i) => !i.isSafe).toList();
  }

  // Apply search
  if (query.isNotEmpty) {
    filtered = filtered
        .where((i) => i.target.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  return filtered;
});
