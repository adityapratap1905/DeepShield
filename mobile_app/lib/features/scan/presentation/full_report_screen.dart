import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../models/scan_result_model.dart';
import '../../../routes/app_router.dart';
import 'dart:convert';

/// Full technical report for the image model result.
class FullReportScreen extends StatelessWidget {
  final ScanResultModel result;

  const FullReportScreen({super.key, required this.result});

  String get _aiCheckSummary => switch (result.extraData?['prediction']) {
        'ai_generated' => 'AI-generation signal found',
        'no_ai_generation_signal' => 'No strong AI-generation signal',
        _ => 'Unavailable',
      };

  String get _status {
    if (result.isDemo) return 'Not analyzed (demo)';
    final aiSignal = _aiCheckSummary == 'AI-generation signal found';
    final faceResult =
        result.extraData?['face_manipulation_prediction'] as String?;
    final faceSignal = faceResult == 'face_manipulation_signal';
    if (aiSignal && faceSignal) {
      return 'AI-generation and face-manipulation signals found';
    }
    if (faceSignal) return 'Face-manipulation signal found (model estimate)';
    if (aiSignal) return 'AI-generation signal found (model estimate)';
    if (faceResult == 'no_face_detected') {
      return 'No strong AI-generation signal; face check inconclusive';
    }
    if (faceResult == 'no_face_manipulation_signal') {
      return 'No strong signal in either model (model estimates)';
    }
    return 'No strong AI-generation signal (model estimate)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text(result.isDemo ? 'Demo Scan Details' : 'Scan Report',
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: textPrimary),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            DSCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('REPORT ID',
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      Text(
                          DateFormat('MMM d, yyyy HH:mm:ss')
                              .format(result.scannedAt),
                          style: TextStyle(color: textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      result.id.isEmpty
                          ? 'REQ-${DateTime.now().millisecondsSinceEpoch}'
                          : result.id,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Divider(color: divider, height: 1),
                  const SizedBox(height: 16),
                  _InfoRow('Target', result.target, isDark),
                  _InfoRow('Type', result.scanType.label, isDark),
                  _InfoRow('Status', _status, isDark),
                  if (!result.isDemo)
                    _InfoRow('AI-generation check', _aiCheckSummary, isDark),
                  if (!result.isDemo)
                    _InfoRow(
                        'AI-generation score (not calibrated)',
                        '${(result.confidenceScore * 100).toStringAsFixed(2)}%',
                        isDark,
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryLight),
                  if (!result.isDemo &&
                      result.extraData?['face_manipulation_prediction'] != null)
                    _InfoRow(
                      'Face check',
                      _faceCheckSummary,
                      isDark,
                      color: result
                                  .extraData?['face_manipulation_prediction'] ==
                              'face_manipulation_signal'
                          ? (isDark ? AppColors.danger : AppColors.dangerLight)
                          : null,
                    ),
                  if (!result.isDemo &&
                      result.extraData?['face_manipulation_probability'] is num)
                    _InfoRow(
                      'Face model score (not calibrated)',
                      '${((result.extraData!['face_manipulation_probability'] as num).toDouble() * 100).toStringAsFixed(2)}%',
                      isDark,
                    ),
                  if (!result.isDemo &&
                      result.extraData?['face_manipulation_prediction'] != null)
                    _InfoRow(
                      'Faces analyzed',
                      '${result.extraData?['faces_analyzed'] ?? 0} of ${result.extraData?['faces_detected'] ?? 0} detected',
                      isDark,
                    ),
                  _InfoRow('Latency', '${result.scanDurationMs} ms', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (result.isDemo)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'This demo contains no model output or forensic metadata.'),
              )
            else ...[
              Text('ANALYSIS DATA',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppColors.cardBorderDark
                          : AppColors.cardBorderLight),
                ),
                child: Text(
                  _formatAnalysisData(),
                  style: TextStyle(
                    color: isDark ? AppColors.success : AppColors.successLight,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            DSButton(
              label: 'Done',
              onPressed: () => context.go(AppRoutes.home),
              isFullWidth: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatAnalysisData() {
    return const JsonEncoder.withIndent('  ').convert(
      result.extraData ?? <String, dynamic>{},
    );
  }

  String get _faceCheckSummary {
    final prediction =
        result.extraData?['face_manipulation_prediction'] as String?;
    return switch (prediction) {
      'face_manipulation_signal' => 'Face manipulation signal found',
      'no_face_manipulation_signal' =>
        'No strong signal in analyzed face crops',
      'no_face_detected' => 'Not run — no face detected',
      _ => 'Unavailable',
    };
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? color;

  const _InfoRow(this.label, this.value, this.isDark, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: color ??
                      (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
