import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';

/// Scan entry screen for image and video analysis.
class ScanHubScreen extends StatefulWidget {
  const ScanHubScreen({super.key});

  @override
  State<ScanHubScreen> createState() => _ScanHubScreenState();
}

class _ScanHubScreenState extends State<ScanHubScreen> {
  bool _videoMode = false;

  void _openScanner() =>
      context.push(AppRoutes.scanFile, extra: _videoMode ? 'video' : null);

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
      final file = File(captured.path);
      final size = await file.length();
      if (!mounted) return;
      final maxBytes = (_videoMode ? 200 : 15) * 1024 * 1024;
      if (size == 0 || size > maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(size == 0
              ? 'The captured media is empty.'
              : 'This media exceeds the ${_videoMode ? 200 : 15} MB limit.'),
        ));
        return;
      }
      if (!mounted) return;
      context.push(AppRoutes.analysis,
          extra: {'type': _videoMode ? 'video' : 'file', 'value': file});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_videoMode
            ? 'Video capture is unavailable. Check camera permission.'
            : 'Camera capture is unavailable. Check camera permission.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    final canvas =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final border =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        centerTitle: true,
        title: Text('Scan',
            style: TextStyle(
                color: foreground, fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Scan history',
            onPressed: () => context.push(AppRoutes.history),
            icon: Icon(Icons.history_rounded, color: foreground),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Image')),
                ButtonSegment(value: true, label: Text('Video')),
              ],
              selected: {_videoMode},
              onSelectionChanged: (selection) =>
                  setState(() => _videoMode = selection.first),
            ),
            const SizedBox(height: 18),
            Material(
              color: card,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _openScanner,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 244),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _videoMode
                            ? Icons.video_library_outlined
                            : Icons.image_outlined,
                        size: 40,
                        color: accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _videoMode ? 'Upload a video' : 'Upload an image',
                        style: TextStyle(
                            color: foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _videoMode
                            ? 'MP4, MOV, AVI, MKV, WebM · up to 200 MB'
                            : 'JPG or PNG · up to 15 MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Choose from gallery'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: secondary)),
                ),
                Expanded(child: Divider(color: border)),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _captureFromCamera,
              icon: Icon(_videoMode
                  ? Icons.videocam_outlined
                  : Icons.camera_alt_outlined),
              label: Text(_videoMode ? 'Record a video' : 'Take a photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: border),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _videoMode
                          ? 'Use a clear clip with visible faces. The service samples frames, so brief edits may be missed.'
                          : 'Use a clear, original image when possible. A missing face means the face check cannot run.',
                      style: TextStyle(
                          color: secondary, fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
