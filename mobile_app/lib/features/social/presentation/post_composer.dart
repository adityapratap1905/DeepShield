import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SocialPostDraft {
  final String body;
  final File? media;

  const SocialPostDraft({required this.body, this.media});
}

Future<SocialPostDraft?> showSocialPostComposer(
  BuildContext context, {
  required String title,
}) async {
  final controller = TextEditingController();
  File? media;
  String? filename;
  String? pickerError;

  try {
    return await showModalBottomSheet<SocialPostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setDialogState) {
          final primary = Theme.of(sheetContext).brightness == Brightness.dark
              ? AppColors.primary
              : AppColors.primaryLight;
          final isVideoAttachment = const {'mp4', 'mov', 'avi', 'mkv', 'webm'}
              .contains(filename?.split('.').last.toLowerCase());
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.94,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      FilledButton(
                        onPressed: () {
                          final body = controller.text.trim();
                          if (body.isEmpty) {
                            setDialogState(() => pickerError =
                                'Add a short caption before publishing.');
                            return;
                          }
                          Navigator.pop(
                            sheetContext,
                            SocialPostDraft(body: body, media: media),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person_outline_rounded,
                              color: primary),
                        ),
                        const SizedBox(width: 11),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your profile',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 3),
                            Text('Community post',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'Share a question or useful safety insight…',
                          alignLabelWithHint: true,
                          border: InputBorder.none,
                        ),
                      ),
                      if (media != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 180,
                            color: primary.withValues(alpha: 0.08),
                            child: isVideoAttachment
                                ? const Center(
                                    child: Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 44))
                                : Image.file(media!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                          child: Text(filename ?? 'Attachment'),
                                        )),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setDialogState(() {
                            media = null;
                            filename = null;
                            pickerError = null;
                          }),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Remove attachment'),
                        ),
                      ],
                      if (pickerError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(pickerError!,
                              style: TextStyle(
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .error)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20,
                      MediaQuery.viewInsetsOf(sheetContext).bottom + 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const [
                              'jpg',
                              'jpeg',
                              'png',
                              'mp4',
                              'mov',
                              'avi',
                              'mkv',
                              'webm'
                            ],
                          );
                          if (result == null || result.files.isEmpty) return;
                          final picked = result.files.single;
                          final path = picked.path;
                          if (path == null) {
                            setDialogState(() => pickerError =
                                'This device did not provide an accessible file path.');
                            return;
                          }
                          final extension =
                              picked.extension?.toLowerCase() ?? '';
                          final isImage =
                              const {'jpg', 'jpeg', 'png'}.contains(extension);
                          final limit =
                              isImage ? 15 * 1024 * 1024 : 50 * 1024 * 1024;
                          final selected = File(path);
                          final size = await selected.length();
                          if (size == 0 || size > limit) {
                            setDialogState(() => pickerError = isImage
                                ? 'Choose an image smaller than 15 MB.'
                                : 'Choose a video smaller than 50 MB.');
                            return;
                          }
                          setDialogState(() {
                            media = selected;
                            filename = picked.name;
                            pickerError = null;
                          });
                        },
                        icon: Icon(Icons.image_outlined, color: primary),
                        label: Text(filename ?? 'Add photo or video'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'One attachment per post. Image limit 15 MB; video limit 50 MB.',
                        style: TextStyle(
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}
