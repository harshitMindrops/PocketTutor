import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_tool_type.dart';

class ChatToolTag extends StatelessWidget {
  const ChatToolTag({
    super.key,
    required this.tool,
    this.onRemove,
    this.compact = false,
  });

  final ChatToolType tool;
  final VoidCallback? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tool) {
      ChatToolType.generateQuiz => (Icons.quiz_outlined, AppColors.primaryLight),
      ChatToolType.generateFlashcard => (
          Icons.style_outlined,
          const Color(0xFF4A90D9),
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            tool.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: compact ? 14 : 16,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget? fromStorageKey(String? key, {bool compact = false}) {
    final tool = ChatToolTypeX.fromStorageKey(key);
    if (tool == null) return null;
    return ChatToolTag(tool: tool, compact: compact);
  }
}
