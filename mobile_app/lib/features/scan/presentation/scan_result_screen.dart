import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../models/scan_result_model.dart';
import '../../../routes/app_router.dart';

/// Displays the estimate returned by the configured analysis service.
class ScanResultScreen extends StatelessWidget {
  final ScanResultModel result;
  const ScanResultScreen({super.key, required this.result});

  bool get _isSafe =>
      !result.isDemo &&
      _aiPrediction == 'no_ai_generation_signal' &&
      _facePrediction == 'no_face_manipulation_signal';

  String? get _aiPrediction => result.extraData?['prediction'] as String?;
  String get _aiCheckStatus => switch (_aiPrediction) {
        'ai_generated' => 'AI-generation signal found',
        'no_ai_generation_signal' => 'No strong AI-generation signal',
        _ => 'AI-generation check unavailable',
      };
  String? get _facePrediction =>
      result.extraData?['face_manipulation_prediction'] as String?;
  double? get _faceManipulationScore =>
      (result.extraData?['face_manipulation_probability'] as num?)?.toDouble();
  int get _facesDetected =>
      (result.extraData?['faces_detected'] as num?)?.toInt() ?? 0;
  int get _facesAnalyzed =>
      (result.extraData?['faces_analyzed'] as num?)?.toInt() ?? 0;

  String get _faceCheckStatus => switch (_facePrediction) {
        'face_manipulation_signal' => 'Face manipulation signal found',
        'no_face_manipulation_signal' =>
          'No strong signal in analyzed face crops',
        'no_face_detected' => 'Not run — no face detected',
        _ => 'Face check unavailable',
      };

  bool get _hasManipulationSignal =>
      _aiPrediction == 'ai_generated' ||
      _facePrediction == 'face_manipulation_signal';

  Color _getPrimaryColor(bool isDark) {
    if (_hasManipulationSignal) {
      return isDark ? AppColors.danger : AppColors.dangerLight;
    }
    if (_isSafe) return isDark ? AppColors.success : AppColors.successLight;
    return isDark ? AppColors.warning : AppColors.warningLight;
  }

  LinearGradient _getGradient(bool isDark) {
    final color = _getPrimaryColor(isDark);
    return LinearGradient(
      colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData get _icon =>
      _hasManipulationSignal ? Icons.gpp_bad_rounded : Icons.analytics_rounded;
  String get _verdict {
    if (result.isDemo) return 'Demo Only — No Analysis';
    final aiSignal = _aiPrediction == 'ai_generated';
    final faceSignal = _facePrediction == 'face_manipulation_signal';
    if (aiSignal && faceSignal) return 'Multiple Manipulation Signals Found';
    if (faceSignal) return 'Face Manipulation Signal Found';
    if (aiSignal) return 'AI-Generated Signal Found';
    if (_facePrediction == 'no_face_detected') {
      return 'Face Check Inconclusive';
    }
    if (_facesAnalyzed > 0) return 'No Strong Manipulation Signal Found';
    return 'No Strong AI-Generation Signal';
  }

  String get _description => result.isDemo
      ? 'No model analysis was performed, so this result says nothing about the image.'
      : 'These model scores are estimates, not proof. The face check only evaluates detected face crops and can miss unfamiliar manipulations.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _getPrimaryColor(isDark);
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky result header ─────────────────────────────────
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: textPrimary),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _ResultHero(
                  isSafe: _isSafe,
                  primaryColor: primaryColor,
                  gradient: _getGradient(isDark),
                  icon: _icon,
                  verdict: _verdict,
                  description: _description,
                  confidenceScore:
                      result.isDemo ? null : result.confidenceScore,
                  isDark: isDark,
                ),
              ),
            ),

            // ── Detail cards ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),

                  // Show the separate AI-generation and face-analysis outputs.
                  if (result.isDemo)
                    const _DemoResultNotice()
                  else
                    _ModelScoreCard(
                      score: result.confidenceScore,
                      aiCheckStatus: _aiCheckStatus,
                      faceScore: _faceManipulationScore,
                      faceCheckStatus: _faceCheckStatus,
                      faceCheckWasSkipped:
                          _facePrediction == 'no_face_detected',
                      facesDetected: _facesDetected,
                      facesAnalyzed: _facesAnalyzed,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideY(begin: 0.2, end: 0, delay: 100.ms),

                  const SizedBox(height: 16),

                  // Threat details
                  _DetailCard(
                    title: 'Scan Details',
                    isDark: isDark,
                    children: [
                      _DetailRow(
                          label: 'Target',
                          value: result.target,
                          isMonospace: true,
                          isDark: isDark),
                      _DetailRow(
                          label: 'Scan Type',
                          value: result.scanType.label,
                          isDark: isDark),
                      _DetailRow(
                          label: 'Model output',
                          value: _verdict,
                          valueColor: _getPrimaryColor(isDark),
                          isDark: isDark),
                      if (!result.isDemo)
                        _DetailRow(
                          label: 'AI-generation check',
                          value: _aiCheckStatus,
                          valueColor: _aiPrediction == 'ai_generated'
                              ? (isDark
                                  ? AppColors.danger
                                  : AppColors.dangerLight)
                              : null,
                          isDark: isDark,
                        ),
                      if (!result.isDemo)
                        _DetailRow(
                          label: 'AI-generation score',
                          value: result.confidencePercent,
                          valueColor: isDark
                              ? AppColors.primary
                              : AppColors.primaryLight,
                          isDark: isDark,
                        ),
                      if (!result.isDemo) ...[
                        _DetailRow(
                          label: 'Face check',
                          value: _faceCheckStatus,
                          valueColor:
                              _facePrediction == 'face_manipulation_signal'
                                  ? (isDark
                                      ? AppColors.danger
                                      : AppColors.dangerLight)
                                  : null,
                          isDark: isDark,
                        ),
                        if (_faceManipulationScore != null)
                          _DetailRow(
                            label: 'Face model score',
                            value:
                                '${(_faceManipulationScore! * 100).toStringAsFixed(1)}% (not calibrated)',
                            isDark: isDark,
                          ),
                        if (_facePrediction != null)
                          _DetailRow(
                            label: 'Faces analyzed',
                            value: _facePrediction == 'no_face_detected'
                                ? 'No face detected; check not run'
                                : 'Analyzed $_facesAnalyzed of $_facesDetected detected faces',
                            isDark: isDark,
                          ),
                      ],
                      _DetailRow(
                          label: 'Scan Time',
                          value: '${result.scanDurationMs}ms',
                          valueColor: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          isDark: isDark),
                      _DetailRow(
                          label: 'Scanned At',
                          value: DateFormat('MMM d, yyyy HH:mm')
                              .format(result.scannedAt),
                          isDark: isDark),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideY(begin: 0.2, end: 0, delay: 200.ms),

                  const SizedBox(height: 16),

                  // Reasons (Explainability)
                  if (result.reasons.isNotEmpty)
                    _ReasonsCard(
                            reasons: result.reasons,
                            primaryColor: primaryColor,
                            isDark: isDark)
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.2, end: 0, delay: 300.ms),

                  const SizedBox(height: 16),

                  // Recommendation
                  _RecommendationCard(
                          recommendation: result.recommendation,
                          primaryColor: primaryColor,
                          isDark: isDark)
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.2, end: 0, delay: 400.ms),

                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'Done',
                          onPressed: () => context.go(AppRoutes.home),
                          variant: DSButtonVariant.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DSButton(
                          label: 'Full Report',
                          onPressed: () =>
                              context.push(AppRoutes.fullReport, extra: result),
                          leadingIcon: Icons.article_rounded,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  final bool isSafe;
  final Color primaryColor;
  final LinearGradient gradient;
  final IconData icon;
  final String verdict;
  final String description;
  final double? confidenceScore;
  final bool isDark;

  const _ResultHero({
    required this.isSafe,
    required this.primaryColor,
    required this.gradient,
    required this.icon,
    required this.verdict,
    required this.description,
    required this.confidenceScore,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.15),
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large icon with glow
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 48),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              Text(
                verdict,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 8),

              Text(
                description,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              if (confidenceScore != null) ...[
                const SizedBox(height: 12),
                Text(
                    'AI-generation score: ${(confidenceScore! * 100).toStringAsFixed(1)}% (not calibrated)',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelScoreCard extends StatelessWidget {
  final double score;
  final String aiCheckStatus;
  final double? faceScore;
  final String faceCheckStatus;
  final bool faceCheckWasSkipped;
  final int facesDetected;
  final int facesAnalyzed;
  final bool isDark;
  final Color primaryColor;

  const _ModelScoreCard({
    required this.score,
    required this.aiCheckStatus,
    required this.faceScore,
    required this.faceCheckStatus,
    required this.faceCheckWasSkipped,
    required this.facesDetected,
    required this.facesAnalyzed,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return DSCard(
      padding: const EdgeInsets.all(20),
      customBorder:
          Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Text('Model Analysis',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AI + FACE CHECKS',
                  style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'AI-generation check: $aiCheckStatus',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _MetricBar(
              label: 'AI-generated image score (not calibrated)',
              score: score,
              isDark: isDark,
              primaryColor: primaryColor),
          const SizedBox(height: 18),
          Text(
            'Face-manipulation check: $faceCheckStatus',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          if (faceScore != null)
            _MetricBar(
              label: 'Face-manipulation score (not calibrated)',
              score: faceScore!,
              isDark: isDark,
              primaryColor: primaryColor,
            )
          else
            Text(
              faceCheckWasSkipped
                  ? 'No face was detected, so this check could not run.'
                  : facesDetected > 0
                      ? 'Analyzed $facesAnalyzed of $facesDetected detected faces.'
                      : 'A face-analysis score was not returned.',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoResultNotice extends StatelessWidget {
  const _DemoResultNotice();

  @override
  Widget build(BuildContext context) => const DSCard(
        child: Text(
          'No image analysis was performed. Connect the pretrained image and face models before using this result.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
      );
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double score;
  final bool isDark;
  final Color primaryColor;

  const _MetricBar({
    required this.label,
    required this.score,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final trackColor = isDark ? Colors.white10 : Colors.black12;

    // Animate the bar width
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text('${(score * 100).toInt()}%',
                  style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width: constraints.maxWidth * score,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withValues(alpha: 0.5),
                        blurRadius: 4),
                  ],
                ),
              ).animate().scaleX(
                  begin: 0,
                  end: 1,
                  duration: 800.ms,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft),
            ],
          ),
        ],
      );
    });
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _DetailCard(
      {required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return DSCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: textPrimary.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: divider, height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMonospace;
  final bool isDark;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isMonospace = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonsCard extends StatelessWidget {
  final List<String> reasons;
  final Color primaryColor;
  final bool isDark;

  const _ReasonsCard(
      {required this.reasons,
      required this.primaryColor,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final icon =
        primaryColor == (isDark ? AppColors.success : AppColors.successLight)
            ? Icons.verified_user_rounded
            : Icons.warning_rounded;

    return DSCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              Text('Key Indicators',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          color: primaryColor, size: 10),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r,
                          style: TextStyle(
                              color: textSecondary, fontSize: 14, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String recommendation;
  final Color primaryColor;
  final bool isDark;

  const _RecommendationCard(
      {required this.recommendation,
      required this.primaryColor,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return DSCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        colors: [primaryColor.withValues(alpha: 0.1), Colors.transparent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      customBorder: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_outlined, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Action Plan',
                    style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(
                  recommendation.isEmpty
                      ? 'No specific action required.'
                      : recommendation,
                  style: TextStyle(
                      color: textSecondary, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
