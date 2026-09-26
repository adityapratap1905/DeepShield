import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_snackbar.dart';
import '../../../routes/app_router.dart';
import '../providers/scan_provider.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> payload;
  const AnalysisScreen({super.key, required this.payload});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  int _currentStage = 0;
  final List<String> _stages = [
    'Uploading photo',
    'Validating image',
    'Running model analysis',
    'Receiving model result',
    'Finishing',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
      _cycleStages();
    });
  }

  void _startScan() {
    final type = widget.payload['type'];
    final value = widget.payload['value'];

    final notifier = ref.read(scanProvider.notifier);
    if (type == 'url') {
      notifier.scanUrl(value as String);
    } else if (type == 'file') {
      notifier.scanFile(value as File);
    } else if (type == 'qr') {
      notifier.scanQr(value as String);
    } else {
      // Fallback
      showDSSnackbar(context,
          message: 'Invalid scan type', type: DSSnackbarType.error);
      context.pop();
    }
  }

  Future<void> _cycleStages() async {
    while (mounted && _currentStage < _stages.length - 1) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _currentStage++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanProvider, (_, next) {
      if (next is ScanSuccess) {
        // Little delay to let the user see the "Finalizing" stage
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 800));
          if (!context.mounted) return;
          context.pushReplacement(AppRoutes.scanResult, extra: next.result);
        });
      } else if (next is ScanError) {
        showDSSnackbar(context,
            message: next.message, type: DSSnackbarType.error);
        context.pop();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scanner Animation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: primary.withValues(alpha: 0.2), width: 2),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.1),
                      border: Border.all(
                          color: primary.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.analytics_rounded,
                        color: Colors.white, size: 40),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.1, 1.1),
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine)
                      .then()
                      .scale(
                          begin: const Offset(1.1, 1.1),
                          end: const Offset(0.9, 0.9),
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine),

                  // Scanning Ring
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      color: primary,
                      strokeWidth: 2,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .rotate(duration: 2.seconds),
                ],
              ),

              const SizedBox(height: 50),

              // Stage Indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _stages[_currentStage],
                  key: ValueKey(_currentStage),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Stage Progress Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_stages.length, (index) {
                  final isActive = index <= _currentStage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          isActive ? primary : primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: primary.withValues(alpha: 0.5),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                  );
                }),
              )
            ],
          ),
        ),
      ),
    );
  }
}
