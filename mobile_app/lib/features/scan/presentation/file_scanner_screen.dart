import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_snackbar.dart';
import '../../../routes/app_router.dart';

/// Photo scanner screen — file picker and analysis handoff.
class FileScannerScreen extends StatefulWidget {
  const FileScannerScreen({super.key});

  @override
  State<FileScannerScreen> createState() => _FileScannerScreenState();
}

class _FileScannerScreenState extends State<FileScannerScreen> {
  File? _selectedFile;
  String? _fileName;
  int? _fileSize;

  static const _supportedExtensions = ['jpg', 'jpeg', 'png'];
  static const _maxSizeMB = 15;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null || !mounted) {
        return;
      }

      final file = File(result.files.single.path!);
      final size = await file.length();
      if (!mounted) return;

      if (size > _maxSizeMB * 1024 * 1024) {
        showDSSnackbar(context,
            message: 'File exceeds $_maxSizeMB MB limit.',
            type: DSSnackbarType.error);
        return;
      }

      setState(() {
        _selectedFile = file;
        _fileName = result.files.single.name;
        _fileSize = size;
      });
    } catch (_) {
      if (!mounted) return;
      showDSSnackbar(context,
          message: 'Could not open that photo. Please try again.',
          type: DSSnackbarType.error);
    }
  }

  void _scan() {
    final file = _selectedFile;
    if (file == null) return;
    context.push(AppRoutes.analysis, extra: {'type': 'file', 'value': file});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('Image Manipulation Check',
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _FileDropZone(
                file: _selectedFile,
                fileName: _fileName,
                fileSize: _fileSize,
                isDark: isDark,
                onTap: _pickFile,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              _PhotoPrototypeNotice(isDark: isDark),
              const SizedBox(height: 24),
              const _SupportedTypes().animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: DSButton(
            label: 'Analyze Photo',
            onPressed: _selectedFile == null ? null : _scan,
            isFullWidth: true,
            leadingIcon: Icons.radar_rounded,
          ).animate().fadeIn(delay: 300.ms),
        ),
      ),
    );
  }
}

class _PhotoPrototypeNotice extends StatelessWidget {
  final bool isDark;

  const _PhotoPrototypeNotice({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.warning : AppColors.warningLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Photos are checked for AI-generation signals and face manipulations such as swaps. Model scores are estimates, not proof; the face check needs a detectable face.',
        style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _FileDropZone extends StatelessWidget {
  final File? file;
  final String? fileName;
  final int? fileSize;
  final bool isDark;
  final VoidCallback onTap;

  const _FileDropZone({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.isDark,
    required this.onTap,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _fileIcon => Icons.image_rounded;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final cardBorder =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final primaryContainer =
        isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;

    return Semantics(
      button: true,
      label: hasFile
          ? 'Selected photo: $fileName. Tap to choose a different photo.'
          : 'Tap to select a JPG or PNG photo',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: hasFile ? cardBg : background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasFile
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : cardBorder,
                width: hasFile ? 1.5 : 1,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: hasFile
                  ? [
                      BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          blurRadius: 20)
                    ]
                  : null,
            ),
            child: hasFile
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: file == null
                            ? Icon(_fileIcon,
                                color: AppColors.warning, size: 30)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(
                                  file!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  cacheWidth: 180,
                                  cacheHeight: 180,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(_fileIcon,
                                          color: AppColors.warning, size: 30),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fileName!,
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(_formatSize(fileSize ?? 0),
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      Text('Tap to choose a different photo',
                          style: TextStyle(color: primary, fontSize: 13)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primaryContainer.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBorder),
                        ),
                        child: Icon(Icons.upload_file_rounded,
                            color: primary, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text('Tap to select a file',
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('JPG and PNG · up to 15 MB',
                          style: TextStyle(color: textTertiary, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SupportedTypes extends StatelessWidget {
  const _SupportedTypes();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const types = [
      ('Photos: JPG, PNG', Icons.image_rounded, AppColors.warning),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supported file types',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types
              .map((type) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: type.$3.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: type.$3.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.$2, size: 14, color: type.$3),
                        const SizedBox(width: 6),
                        Text(type.$1,
                            style: TextStyle(
                                color: type.$3,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
