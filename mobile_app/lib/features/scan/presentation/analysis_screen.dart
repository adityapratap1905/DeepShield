import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../routes/app_router.dart';
import '../providers/scan_provider.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> payload;

  const AnalysisScreen({super.key, required this.payload});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  String? _errorMessage;

  bool get _isPhotoScan => widget.payload['type'] == 'file';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(scanProvider.notifier).reset();
      ref.read(uploadProgressProvider.notifier).state =
          const UploadProgressState(0);
      _startScan();
    });
  }

  void _startScan() {
    final type = widget.payload['type'];
    final value = widget.payload['value'];
    final notifier = ref.read(scanProvider.notifier);

    setState(() => _errorMessage = null);
    if (type == 'url' && value is String) {
      notifier.scanUrl(value);
    } else if (type == 'file' && value is File) {
      notifier.scanFile(value);
    } else if (type == 'qr' && value is String) {
      notifier.scanQr(value);
    } else {
      setState(() {
        _errorMessage =
            'This scan could not be started. Return to the photo scanner and choose a JPG or PNG image.';
      });
    }
  }

  void _retry() {
    ref.read(scanProvider.notifier).reset();
    ref.read(uploadProgressProvider.notifier).state =
        const UploadProgressState(0);
    _startScan();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanProvider, (_, next) {
      if (next is ScanSuccess) {
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 650));
          if (!context.mounted) return;
          context.pushReplacement(AppRoutes.scanResult, extra: next.result);
        });
      } else if (next is ScanError) {
        setState(() => _errorMessage = next.message);
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final scanState = ref.watch(scanProvider);
    final progress =
        ref.watch(uploadProgressProvider).progress.clamp(0.0, 1.0).toDouble();
    final errorMessage =
        _errorMessage ?? (scanState is ScanError ? scanState.message : null);

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: errorMessage == null
                    ? _LoadingContent(
                        primary: primary,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        scanState: scanState,
                        isPhotoScan: _isPhotoScan,
                        progress: progress,
                      )
                    : _ErrorContent(
                        message: errorMessage,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        canRetry: _isPhotoScan,
                        onRetry: _retry,
                        onBack: () => context.pop(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final ScanState scanState;
  final bool isPhotoScan;
  final double progress;

  const _LoadingContent({
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.scanState,
    required this.isPhotoScan,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final stageIndex = scanState is ScanSuccess
        ? 3
        : scanState is ScanLoading
            ? (isPhotoScan && progress >= 1 ? 2 : 1)
            : 0;
    final stageLabel = scanState is ScanSuccess
        ? 'Analysis complete'
        : scanState is ScanLoading
            ? isPhotoScan
                ? (progress >= 1 ? 'Analyzing photo' : 'Uploading photo')
                : 'Checking source'
            : 'Preparing analysis';
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget pulse = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.1),
        border: Border.all(color: primary.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 40),
    );

    Widget ring = SizedBox(
      width: 160,
      height: 160,
      child: CircularProgressIndicator(color: primary, strokeWidth: 2),
    );

    if (reduceMotion) {
      ring = Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primary.withValues(alpha: 0.35), width: 2),
        ),
      );
    } else {
      pulse = pulse
          .animate(onPlay: (controller) => controller.repeat())
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.1, 1.1),
            duration: 1000.ms,
            curve: Curves.easeInOutSine,
          )
          .then()
          .scale(
            begin: const Offset(1.1, 1.1),
            end: const Offset(0.9, 0.9),
            duration: 1000.ms,
            curve: Curves.easeInOutSine,
          );
      ring = ring
          .animate(onPlay: (controller) => controller.repeat())
          .rotate(duration: 2.seconds);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            pulse,
            ring,
          ],
        ),
        const SizedBox(height: 50),
        Semantics(
          liveRegion: true,
          label: stageLabel,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              stageLabel,
              key: ValueKey(stageLabel),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Semantics(
          label: 'Analysis stage ${stageIndex + 1} of 4',
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isActive = index <= stageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? primary : primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),
        if (isPhotoScan && scanState is ScanLoading) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              value: progress >= 1 ? null : progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: primary.withValues(alpha: 0.15),
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress >= 1
                ? 'Upload complete · analyzing image'
                : '${(progress * 100).round()}% uploaded',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorContent({
    required this.message,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.canRetry,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final danger = isDark ? AppColors.danger : AppColors.dangerLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: danger.withValues(alpha: 0.12),
            border: Border.all(color: danger.withValues(alpha: 0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: danger.withValues(alpha: 0.15),
                blurRadius: 30,
              ),
            ],
          ),
          child: Icon(Icons.cloud_off_rounded, color: danger, size: 42),
        ),
        const SizedBox(height: 28),
        Text(
          canRetry ? 'Analysis didn’t finish' : 'This scan isn’t available',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        DSButton(
          label: canRetry ? 'Try again' : 'Back to scanner',
          onPressed: canRetry ? onRetry : onBack,
          isFullWidth: true,
          leadingIcon:
              canRetry ? Icons.refresh_rounded : Icons.arrow_back_rounded,
        ),
        if (canRetry) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onBack,
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
        ],
      ],
    );
  }
}
