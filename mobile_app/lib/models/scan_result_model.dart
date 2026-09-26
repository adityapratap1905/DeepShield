import 'package:equatable/equatable.dart';

/// Threat level enum
enum ThreatLevel { safe, low, medium, high, critical }

extension ThreatLevelExt on ThreatLevel {
  String get label {
    switch (this) {
      case ThreatLevel.safe:
        return 'Likely Authentic';
      case ThreatLevel.low:
        return 'Low Risk';
      case ThreatLevel.medium:
        return 'Medium Risk';
      case ThreatLevel.high:
        return 'High Risk';
      case ThreatLevel.critical:
        return 'Critical';
    }
  }
}

ThreatLevel threatLevelFromString(String s) {
  switch (s.toLowerCase()) {
    case 'safe':
      return ThreatLevel.safe;
    case 'low':
      return ThreatLevel.low;
    case 'medium':
      return ThreatLevel.medium;
    case 'high':
      return ThreatLevel.high;
    case 'critical':
      return ThreatLevel.critical;
    default:
      return ThreatLevel.medium;
  }
}

/// Scan type enum
enum ScanType { url, file, qr }

extension ScanTypeExt on ScanType {
  String get label {
    switch (this) {
      case ScanType.url:
        return 'URL Scan';
      case ScanType.file:
        return 'Photo Scan';
      case ScanType.qr:
        return 'QR Scan';
    }
  }

  String get icon {
    switch (this) {
      case ScanType.url:
        return '🔗';
      case ScanType.file:
        return '📄';
      case ScanType.qr:
        return '📷';
    }
  }
}

ScanType scanTypeFromString(String s) {
  switch (s.toLowerCase()) {
    case 'file':
      return ScanType.file;
    case 'qr':
      return ScanType.qr;
    default:
      return ScanType.url;
  }
}

/// Full scan result returned from the backend
class ScanResultModel extends Equatable {
  final String id;
  final ScanType scanType;
  final String target; // URL or filename
  final ThreatLevel threatLevel;
  // Photo scans use the AI-generation score; face output is in extraData.
  final double confidenceScore;
  final bool isSafe;
  final List<String> reasons;
  final String recommendation;
  final int scanDurationMs;
  final DateTime scannedAt;
  final Map<String, dynamic>? extraData;
  final bool isDemo;

  const ScanResultModel({
    required this.id,
    required this.scanType,
    required this.target,
    required this.threatLevel,
    required this.confidenceScore,
    required this.isSafe,
    required this.reasons,
    required this.recommendation,
    required this.scanDurationMs,
    required this.scannedAt,
    this.extraData,
    this.isDemo = false,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) =>
      ScanResultModel(
        id: json['id'] as String? ?? '',
        scanType: scanTypeFromString(json['scan_type'] as String? ?? 'url'),
        target: json['target'] as String? ?? '',
        threatLevel:
            threatLevelFromString(json['threat_level'] as String? ?? 'safe'),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
        isSafe: json['is_safe'] as bool? ?? true,
        reasons: List<String>.from(json['reasons'] as List? ?? []),
        recommendation: json['recommendation'] as String? ?? '',
        scanDurationMs: json['scan_duration_ms'] as int? ?? 0,
        scannedAt: DateTime.parse(
            json['scanned_at'] as String? ?? DateTime.now().toIso8601String()),
        extraData: json['extra_data'] as Map<String, dynamic>?,
        isDemo: json['is_demo'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scan_type': scanType.name,
        'target': target,
        'threat_level': threatLevel.name,
        'confidence_score': confidenceScore,
        'is_safe': isSafe,
        'reasons': reasons,
        'recommendation': recommendation,
        'scan_duration_ms': scanDurationMs,
        'scanned_at': scannedAt.toIso8601String(),
        'extra_data': extraData,
        'is_demo': isDemo,
      };

  /// Model score as a percentage string.
  String get confidencePercent =>
      '${(confidenceScore * 100).toStringAsFixed(1)}%';

  @override
  List<Object?> get props => [
        id,
        scanType,
        target,
        threatLevel,
        confidenceScore,
        isSafe,
        scannedAt,
        isDemo
      ];
}
