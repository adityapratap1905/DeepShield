import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/history_item_model.dart';
import '../../../models/scan_result_model.dart';

/// Stores scan summaries and small local previews on this device.
class HistoryRepository {
  static const int _maxItems = 100;

  Future<List<HistoryItemModel>> getHistory({
    int page = 1,
    int limit = 20,
    String? filter,
    String? query,
  }) async {
    final normalizedFilter = filter?.toLowerCase();
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    var items = _readItems()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    if (normalizedFilter == 'safe') {
      items = items.where((item) => item.isSafe).toList();
    } else if (normalizedFilter == 'dangerous') {
      items = items.where((item) => !item.isSafe).toList();
    }
    if (normalizedQuery.isNotEmpty) {
      items = items
          .where((item) => item.target.toLowerCase().contains(normalizedQuery))
          .toList();
    }

    final start = ((page - 1) * limit).clamp(0, items.length).toInt();
    final end = (start + limit).clamp(start, items.length).toInt();
    return items.sublist(start, end);
  }

  Future<void> addScanResult(
    ScanResultModel result, {
    File? sourceFile,
  }) async {
    final resultId = result.id.trim().isEmpty ? 'scan' : result.id.trim();
    final id = '${resultId}_${result.scannedAt.microsecondsSinceEpoch}';
    final thumbnailPath = await _saveThumbnail(id, sourceFile);
    final item = HistoryItemModel.fromScanResult(
      result,
      id: id,
      thumbnailPath: thumbnailPath,
    );

    final items = _readItems();
    final replaced = items.where((existing) => existing.id == id).toList();
    for (final oldItem in replaced) {
      await _deleteThumbnail(oldItem.thumbnailPath);
    }
    items.removeWhere((existing) => existing.id == id);
    items.insert(0, item);

    final removed = items.skip(_maxItems).toList();
    for (final oldItem in removed) {
      await _deleteThumbnail(oldItem.thumbnailPath);
    }
    await _writeItems(items.take(_maxItems).toList());
  }

  Future<void> deleteHistoryItem(String id) async {
    final items = _readItems();
    final removed = items.where((item) => item.id == id).toList();
    for (final item in removed) {
      await _deleteThumbnail(item.thumbnailPath);
    }
    items.removeWhere((item) => item.id == id);
    await _writeItems(items);
  }

  Future<void> clearAllHistory() async {
    for (final item in _readItems()) {
      await _deleteThumbnail(item.thumbnailPath);
    }
    await StorageService.instance.setString(AppConstants.keyScanHistory, '[]');
  }

  List<HistoryItemModel> _readItems() {
    final raw = StorageService.instance.getString(AppConstants.keyScanHistory);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => HistoryItemModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> _writeItems(List<HistoryItemModel> items) async {
    await StorageService.instance.setString(
      AppConstants.keyScanHistory,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<String?> _saveThumbnail(String id, File? sourceFile) async {
    if (sourceFile == null) return null;

    try {
      if (!await sourceFile.exists()) return null;

      final root = await getApplicationSupportDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}scan_history',
      );
      await directory.create(recursive: true);

      final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final output = File(
        '${directory.path}${Platform.pathSeparator}$safeId.png',
      );
      final codec = await ui.instantiateImageCodec(
        await sourceFile.readAsBytes(),
        targetWidth: 224,
        targetHeight: 224,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final png = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (png == null) return null;
          await output.writeAsBytes(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            flush: true,
          );
          return output.path;
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Keep the result in history even if a preview cannot be generated.
      return null;
    }
  }

  Future<void> _deleteThumbnail(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A missing preview does not prevent history from being updated.
    }
  }
}
