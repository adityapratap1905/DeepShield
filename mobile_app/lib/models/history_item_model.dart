import 'package:equatable/equatable.dart';
import 'scan_result_model.dart';

/// A single item in the scan history list
class HistoryItemModel extends Equatable {
  final String id;
  final ScanType scanType;
  final String target;
  final ThreatLevel threatLevel;
  final bool isSafe;
  final DateTime scannedAt;
  final double confidenceScore;
  final String? thumbnailPath;
  final Map<String, dynamic>? resultData;

  const HistoryItemModel({
    required this.id,
    required this.scanType,
    required this.target,
    required this.threatLevel,
    required this.isSafe,
    required this.scannedAt,
    required this.confidenceScore,
    this.thumbnailPath,
    this.resultData,
  });

  factory HistoryItemModel.fromJson(Map<String, dynamic> json) =>
      HistoryItemModel(
        id: json['id'] as String? ?? '',
        scanType: scanTypeFromString(json['scan_type'] as String? ?? 'url'),
        target: json['target'] as String? ?? '',
        threatLevel:
            threatLevelFromString(json['threat_level'] as String? ?? 'safe'),
        isSafe: json['is_safe'] as bool? ?? true,
        scannedAt: DateTime.tryParse(json['scanned_at'] as String? ?? '') ??
            DateTime.now(),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
        thumbnailPath: json['thumbnail_path'] as String?,
        resultData: json['result_data'] is Map
            ? Map<String, dynamic>.from(json['result_data'] as Map)
            : null,
      );

  /// Build from full ScanResultModel
  factory HistoryItemModel.fromScanResult(
    ScanResultModel result, {
    String? id,
    String? thumbnailPath,
  }) {
    final imageChecksFoundNoStrongSignals = !result.isDemo &&
        result.extraData?['model_task'] == 'ai_generated_image_detection' &&
        result.extraData?['face_model_task'] == 'face_manipulation_detection' &&
        result.extraData?['prediction'] == 'no_ai_generation_signal' &&
        result.extraData?['face_manipulation_prediction'] ==
            'no_face_manipulation_signal';
    final isSafe = switch (result.scanType) {
      ScanType.file => imageChecksFoundNoStrongSignals,
      ScanType.video => false,
      _ => result.isSafe,
    };

    return HistoryItemModel(
      id: id ?? result.id,
      scanType: result.scanType,
      target: result.target,
      threatLevel: result.threatLevel,
      isSafe: isSafe,
      scannedAt: result.scannedAt,
      confidenceScore: result.confidenceScore,
      thumbnailPath: thumbnailPath,
      resultData: result.toJson(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scan_type': scanType.name,
        'target': target,
        'threat_level': threatLevel.name,
        'is_safe': isSafe,
        'scanned_at': scannedAt.toIso8601String(),
        'confidence_score': confidenceScore,
        'thumbnail_path': thumbnailPath,
        'result_data': resultData,
      };

  @override
  List<Object?> get props =>
      [id, scanType, target, threatLevel, isSafe, scannedAt, thumbnailPath];
}
