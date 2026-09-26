import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides internet connectivity status as a Riverpod stream.
///
/// Usage:
/// ```dart
/// final isOnline = ref.watch(connectivityProvider);
/// ```
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

/// Simple one-shot check (non-reactive)
class ConnectivityService {
  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
