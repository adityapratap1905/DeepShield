import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deepshield/core/services/storage_service.dart';
import 'package:deepshield/main.dart';
import 'package:deepshield/features/scan/presentation/scan_result_screen.dart';
import 'package:deepshield/features/scan/presentation/file_scanner_screen.dart';
import 'package:deepshield/models/scan_result_model.dart';

void main() {
  testWidgets('DeepShield app smoke test', (WidgetTester tester) async {
    // Initialize mock SharedPreferences for StorageService
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    // Build our app inside a ProviderScope
    await tester.pumpWidget(
      const ProviderScope(child: DeepShieldApp()),
    );

    // Just ensure it builds without throwing
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('scan result hero fits a screenshot-sized phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(610, 1365);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = ScanResultModel(
      id: 'layout-check',
      scanType: ScanType.file,
      target: 'portrait.jpg',
      threatLevel: ThreatLevel.high,
      confidenceScore: 0.1,
      isSafe: false,
      reasons: const ['AI-generation check did not find a strong signal.'],
      recommendation: 'Review the original source.',
      scanDurationMs: 1200,
      scannedAt: DateTime(2026, 10, 28),
      extraData: const {
        'prediction': 'no_ai_generation_signal',
        'face_manipulation_prediction': 'face_manipulation_signal',
        'face_manipulation_probability': 0.92,
        'faces_detected': 1,
        'faces_analyzed': 1,
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: ScanResultScreen(result: result)),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('video result shows sampled-frame details without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(610, 1365);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = ScanResultModel(
      id: 'video-layout-check',
      scanType: ScanType.video,
      target: 'sample clip.mp4',
      threatLevel: ThreatLevel.high,
      confidenceScore: 0.81,
      isSafe: false,
      reasons: const ['A deepfake signal was found in the sampled frames.'],
      recommendation: 'Check the source before sharing.',
      scanDurationMs: 0,
      scannedAt: DateTime(2026, 10, 28),
      extraData: const {
        'prediction': 'FAKE',
        'fake_probability': 0.81,
        'frames_analyzed': 4,
        'no_face_frames': 1,
        'aggregation_method': 'mean',
        'threshold': 0.41,
      },
    );

    await tester
        .pumpWidget(MaterialApp(home: ScanResultScreen(result: result)));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Video frame analysis'), findsOneWidget);
    expect(find.text('4 frames sampled'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull);
  });

  testWidgets('video picker describes supported formats and fits phone width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(610, 1365);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FileScannerScreen(initialVideoMode: true)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Video Deepfake Check'), findsOneWidget);
    expect(find.text('Analyze Video'), findsOneWidget);
    expect(find.textContaining('MP4, MOV, AVI, MKV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
