import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachPick,
    required this.onVoiceRecord,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback onAttachPick;
  final VoidCallback onVoiceRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Upload Button (Left Side)
            IconButton(
              icon: const Icon(
                Icons.attach_file_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              onPressed: onAttachPick,
              splashRadius: 24,
            ),
            const SizedBox(width: 4),
            
            // Text Input Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  style: const TextStyle(color: AppColors.onPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Ask PocketTutor...',
                    hintStyle: TextStyle(color: AppColors.onSurfaceHint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: onSend,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Mic Button (Right Side)
            GestureDetector(
              onTap: onVoiceRecord,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface, // Background se thoda alag dikhne ke liye
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Send Button
            GestureDetector(
              onTap: () => onSend(controller.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}