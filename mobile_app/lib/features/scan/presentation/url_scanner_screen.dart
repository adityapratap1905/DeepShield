import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_text_field.dart';
import '../../../routes/app_router.dart';
import '../providers/scan_provider.dart';
/// URL Scanner screen — paste URL, validate, scan, navigate to result
class UrlScannerScreen extends ConsumerStatefulWidget {
  const UrlScannerScreen({super.key});

  @override
  ConsumerState<UrlScannerScreen> createState() => _UrlScannerScreenState();
}

class _UrlScannerScreenState extends ConsumerState<UrlScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(() => setState(() => _hasInput = _urlCtrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    ref.read(scanProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _scan() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    
    // Pass to Analysis Screen instead of handling inline
    context.push(AppRoutes.analysis, extra: {
      'type': 'url',
      'value': _urlCtrl.text.trim(),
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlCtrl.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('URL Scanner',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textSecondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(Icons.link_rounded, color: primary, size: 38),
                    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 24),

                    // Title / status
                    Text(
                      'Enter URL to Scan',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paste or type a URL below to detect deepfakes or AI-generated content',
                      style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 36),

                    // URL Input
                    DSTextField(
                      label: 'URL',
                      hint: 'https://example.com',
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      prefixIcon: Icons.language_rounded,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _scan(),
                      suffix: TextButton(
                        onPressed: _paste,
                        child: Text('Paste', style: TextStyle(color: primary, fontSize: 13)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter a URL';
                        final url = v.trim();
                        // Allow http/https or bare domains
                        final withScheme = url.startsWith('http') ? url : 'https://$url';
                        if (!AppConstants.urlRegex.hasMatch(withScheme)) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 28),

                    DSButton(
                      label: 'Scan URL',
                      onPressed: !_hasInput ? null : _scan,
                      isFullWidth: true,
                      leadingIcon: Icons.radar_rounded,
                    ).animate().fadeIn(delay: 300.ms),

                    // Example URLs
                    const SizedBox(height: 28),
                    _ExampleUrls(onTap: (url) {
                      _urlCtrl.text = url;
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleUrls extends StatelessWidget {
  final void Function(String) onTap;
  const _ExampleUrls({required this.onTap});

  static const _examples = [
    'https://news.com/viral-video',
    'http://social-media/post-123',
    'https://youtube.com/watch?v=123',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Try an example',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _examples.map((url) => GestureDetector(
            onTap: () => onTap(url),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorderDark),
              ),
              child: Text(
                url.replaceAll('https://', '').replaceAll('http://', ''),
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
            ),
          )).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}
