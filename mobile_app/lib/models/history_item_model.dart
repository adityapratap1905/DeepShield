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

  const HistoryItemModel({
    required this.id,
    required this.scanType,
    required this.target,
    required this.threatLevel,
    required this.isSafe,
    required this.scannedAt,
    required this.confidenceScore,
  });

  factory HistoryItemModel.fromJson(Map<String, dynamic> json) => HistoryItemModel(
        id: json['id'] as String,
        scanType: scanTypeFromString(json['scan_type'] as String? ?? 'url'),
        target: json['target'] as String,
        threatLevel: threatLevelFromString(json['threat_level'] as String? ?? 'safe'),
        isSafe: json['is_safe'] as bool? ?? true,
        scannedAt: DateTime.parse(json['scanned_at'] as String),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      );

  /// Build from full ScanResultModel
  factory HistoryItemModel.fromScanResult(ScanResultModel result) => HistoryItemModel(
        id: result.id,
        scanType: result.scanType,
        target: result.target,
        threatLevel: result.threatLevel,
        isSafe: result.isSafe,
        scannedAt: result.scannedAt,
        confidenceScore: result.confidenceScore,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scan_type': scanType.name,
        'target': target,
        'threat_level': threatLevel.name,
        'is_safe': isSafe,
        'scanned_at': scannedAt.toIso8601String(),
        'confidence_score': confidenceScore,
      };

  @override
  List<Object?> get props =>
      [id, scanType, target, threatLevel, isSafe, scannedAt];
}
