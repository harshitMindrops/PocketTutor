import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

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
            // Image Preview (if present)
            if (imagePath != null && imagePath!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageWidget(imagePath!),
              ),
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
        final decodedBytes = base64Decode(path);
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
