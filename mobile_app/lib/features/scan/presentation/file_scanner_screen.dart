import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_snackbar.dart';
import '../../../routes/app_router.dart';

/// Photo scanner screen — file picker and analysis handoff.
class FileScannerScreen extends StatefulWidget {
  final bool initialVideoMode;
  const FileScannerScreen({super.key, this.initialVideoMode = false});

  @override
  State<FileScannerScreen> createState() => _FileScannerScreenState();
}

class _FileScannerScreenState extends State<FileScannerScreen> {
  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  late bool _videoMode = widget.initialVideoMode;

  static const _photoExtensions = ['jpg', 'jpeg', 'png'];
  static const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
  int get _maxSizeMB => _videoMode ? 200 : 15;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _videoMode ? _videoExtensions : _photoExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null || !mounted) {
        return;
      }

      await _selectMedia(
        File(result.files.single.path!),
        result.files.single.name,
      );
    } catch (_) {
      if (!mounted) return;
      showDSSnackbar(context,
          message: 'Could not open that media file. Please try again.',
          type: DSSnackbarType.error);
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final picker = ImagePicker();
      final captured = _videoMode
          ? await picker.pickVideo(source: ImageSource.camera)
          : await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 4096,
              maxHeight: 4096,
              imageQuality: 100,
            );
      if (captured == null || !mounted) return;
      await _selectMedia(File(captured.path), captured.name);
    } catch (_) {
      if (!mounted) return;
      showDSSnackbar(
        context,
        message:
            'Camera capture is unavailable. Check camera permission and try again.',
        type: DSSnackbarType.error,
      );
    }
  }

  Future<void> _selectMedia(File file, String name) async {
    final size = await file.length();
    if (!mounted) return;
    if (size == 0 || size > _maxSizeMB * 1024 * 1024) {
      showDSSnackbar(context,
          message: size == 0
              ? 'The selected media file is empty.'
              : 'File exceeds $_maxSizeMB MB limit.',
          type: DSSnackbarType.error);
      return;
    }

    setState(() {
      _selectedFile = file;
      _fileName = name;
      _fileSize = size;
    });
  }

  void _scan() {
    final file = _selectedFile;
    if (file == null) return;
    context.push(AppRoutes.analysis,
        extra: {'type': _videoMode ? 'video' : 'file', 'value': file});
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
        title: Text(
            _videoMode ? 'Video Deepfake Check' : 'Photo Manipulation Check',
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.image_outlined),
                    label: Text('Photo'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.movie_outlined),
                    label: Text('Video'),
                  ),
                ],
                selected: {_videoMode},
                onSelectionChanged: (selection) => setState(() {
                  _videoMode = selection.first;
                  _selectedFile = null;
                  _fileName = null;
                  _fileSize = null;
                }),
              ),
              const SizedBox(height: 20),
              _FileDropZone(
                file: _selectedFile,
                fileName: _fileName,
                fileSize: _fileSize,
                isDark: isDark,
                isVideo: _videoMode,
                onTap: _pickFile,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _captureFromCamera,
                icon: Icon(_videoMode
                    ? Icons.videocam_outlined
                    : Icons.camera_alt_outlined),
                label: Text(_videoMode ? 'Record a video' : 'Take a photo'),
              ),
              const SizedBox(height: 24),
              _MediaQualityNotice(isDark: isDark, isVideo: _videoMode),
              const SizedBox(height: 24),
              _SupportedTypes(isVideo: _videoMode)
                  .animate()
                  .fadeIn(delay: 200.ms),
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
            label: _videoMode ? 'Analyze Video' : 'Analyze Photo',
            onPressed: _selectedFile == null ? null : _scan,
            isFullWidth: true,
            leadingIcon: Icons.radar_rounded,
          ).animate().fadeIn(delay: 300.ms),
        ),
      ),
    );
  }
}

class _MediaQualityNotice extends StatelessWidget {
  final bool isDark;
  final bool isVideo;

  const _MediaQualityNotice({required this.isDark, required this.isVideo});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: textColor, size: 18),
              const SizedBox(width: 8),
              Text(
                isVideo ? 'Choose a useful clip' : 'Get a clearer check',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isVideo
                ? 'Use a clear clip with visible faces and minimal blur. The detector samples a few frames, so very brief edits may be missed. Its estimate is not proof of authenticity.'
                : 'Use an original, sharp, well-lit photo with the face unobstructed. Heavy compression or filters can reduce useful detail. If no face is detected, the face check is skipped; that does not mean the image is authentic. Model scores are estimates, not proof.',
            style: TextStyle(color: textColor, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _FileDropZone extends StatelessWidget {
  final File? file;
  final String? fileName;
  final int? fileSize;
  final bool isDark;
  final bool isVideo;
  final VoidCallback onTap;

  const _FileDropZone({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.isDark,
    required this.isVideo,
    required this.onTap,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _fileIcon => isVideo ? Icons.movie_rounded : Icons.image_rounded;

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
          ? 'Selected ${isVideo ? 'video' : 'photo'}: $fileName. Tap to choose another.'
          : 'Tap to select a ${isVideo ? 'video' : 'JPG or PNG photo'}',
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
                        child: isVideo || file == null
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
                      Text(
                          'Tap to choose a different ${isVideo ? 'video' : 'photo'}',
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
  final bool isVideo;
  const _SupportedTypes({required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final types = isVideo
        ? [
            (
              'Videos: MP4, MOV, AVI, MKV, WebM',
              Icons.movie_rounded,
              AppColors.warning
            )
          ]
        : [('Photos: JPG, PNG', Icons.image_rounded, AppColors.warning)];

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
