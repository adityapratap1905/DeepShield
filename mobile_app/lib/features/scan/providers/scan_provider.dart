import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/scan_result_model.dart';
import '../../history/data/history_repository.dart';
import '../../history/providers/history_provider.dart';
import '../data/scan_repository.dart';

// ── Scan State ─────────────────────────────────────────────────────

abstract class ScanState {}

class ScanIdle extends ScanState {}

class ScanLoading extends ScanState {}

class ScanSuccess extends ScanState {
  final ScanResultModel result;
  ScanSuccess(this.result);
}

class ScanError extends ScanState {
  final String message;
  ScanError(this.message);
}

// ── File Upload Progress ────────────────────────────────────────────

class UploadProgressState {
  final double progress; // 0.0–1.0
  const UploadProgressState(this.progress);
}

final uploadProgressProvider = StateProvider<UploadProgressState>(
  (_) => const UploadProgressState(0),
);

// ── Scan Provider ─────────────────────────────────────────────────

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(DioClient.instance.dio),
);

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(
    ref.read(scanRepositoryProvider),
    ref,
    ref.read(historyRepositoryProvider),
  );
});

class ScanNotifier extends StateNotifier<ScanState> {
  final ScanRepository _repo;
  final Ref _ref;
  final HistoryRepository _historyRepository;

  ScanNotifier(this._repo, this._ref, this._historyRepository)
      : super(ScanIdle());

  Future<void> scanUrl(String url) async {
    state = ScanLoading();
    try {
      final result = await _repo.scanUrl(url);
      state = ScanSuccess(result);
    } on Exception catch (e) {
      state = ScanError(e.toString().replaceAll('Exception: ', ''));
    } catch (_) {
      state = ScanError('An unexpected error occurred.');
    }
  }

  Future<void> scanFile(File file) async {
    state = ScanLoading();
    _ref.read(uploadProgressProvider.notifier).state =
        const UploadProgressState(0);

    try {
      final result = await _repo.scanFile(
        file,
        onProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            _ref.read(uploadProgressProvider.notifier).state =
                UploadProgressState(progress);
          }
        },
      );
      try {
        await _historyRepository.addScanResult(result, sourceFile: file);
        _ref.invalidate(historyProvider);
      } catch (_) {
        // A history write should not discard a completed analysis result.
      }
      state = ScanSuccess(result);
    } on Exception catch (e) {
      state = ScanError(e.toString().replaceAll('Exception: ', ''));
    } catch (_) {
      state = ScanError('File scan failed. Please try again.');
    }
  }

  Future<void> scanQr(String url) async {
    state = ScanLoading();
    try {
      final result = await _repo.scanQr(url);
      state = ScanSuccess(result);
    } on Exception catch (e) {
      state = ScanError(e.toString().replaceAll('Exception: ', ''));
    } catch (_) {
      state = ScanError('QR scan failed. Please try again.');
    }
  }

  void reset() => state = ScanIdle();
}
