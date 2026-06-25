import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.imagePath,
    this.messageId,
    this.currentlySpeakingId,
    this.onSpeakToggled,
  });

  final String text;
  final bool isUser;
  final String? imagePath;
  final String? messageId;
  final String? currentlySpeakingId;
  final VoidCallback? onSpeakToggled;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = messageId != null && currentlySpeakingId == messageId;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment Preview (if present)
            if (imagePath != null && imagePath!.isNotEmpty) ...[
              _buildAttachmentWidget(context, imagePath!),
              const SizedBox(height: 8),
            ],
            // Text and Speaker Row
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (onSpeakToggled != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      isSpeaking
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: isSpeaking
                          ? AppColors.primaryAccent
                          : AppColors.onSurface,
                      size: 20,
                    ),
                    onPressed: onSpeakToggled,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, String path) {
    final isLocalFile =
        path.startsWith('/') ||
        path.startsWith('C:') ||
        path.contains('\\') ||
        path.startsWith('file://');

    String extension = '.jpg';
    String fileName = '';

    if (isLocalFile) {
      extension = p.extension(path).toLowerCase();
      fileName = p.basename(path);
    } else {
      // It is a base64 string
      if (path.startsWith('data:')) {
        final match = RegExp(r'^data:(.*?);base64,').firstMatch(path);
        if (match != null) {
          final mimeType = match.group(1) ?? '';
          if (mimeType == 'application/pdf') {
            extension = '.pdf';
          } else if (mimeType.contains('word') || mimeType.contains('msword') || mimeType.contains('officedocument')) {
            extension = '.docx';
          } else if (mimeType == 'image/png') {
            extension = '.png';
          } else if (mimeType == 'image/webp') {
            extension = '.webp';
          } else if (mimeType == 'image/gif') {
            extension = '.gif';
          }
          fileName = 'Document$extension';
        }
      }
    }

    final isImage = extension == '.jpg' || extension == '.jpeg' || extension == '.png' || extension == '.webp' || extension == '.gif';

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImageWidget(path),
      );
    }

    // It is a PDF or Word document! Build a beautiful attachment card.
    IconData iconData = Icons.insert_drive_file;
    Color iconColor = Colors.grey;
    if (extension == '.pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (extension == '.docx' || extension == '.doc') {
      iconData = Icons.description;
      iconColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isNotEmpty ? fileName : 'Attachment File',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  extension.replaceAll('.', '').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isLocalFile) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryAccent, size: 20),
              onPressed: () async {
                try {
                  await OpenFilex.open(path);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open file: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    final isLocalFile =
        path.startsWith('/') ||
        path.startsWith('C:') ||
        path.contains('\\') ||
        path.startsWith('file://');

    if (isLocalFile) {
      final file = File(path);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.background,
            height: 150,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_rounded,
              color: AppColors.error,
            ),
          );
        },
      );
    } else {
      // Decode base64
      try {
        String base64Data = path;
        if (path.startsWith('data:')) {
          final match = RegExp(r'^data:(.*?);base64,(.*)$').firstMatch(path);
          if (match != null) {
            base64Data = match.group(2) ?? '';
          }
        }
        final decodedBytes = base64Decode(base64Data);
        return Image.memory(
          decodedBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.background,
              height: 150,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_rounded,
                color: AppColors.error,
              ),
            );
          },
        );
      } catch (_) {
        return Container(
          color: AppColors.background,
          height: 150,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_rounded, color: AppColors.error),
        );
      }
    }
  }
}
