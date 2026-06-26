import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ✅ Sirf ek import — duplicate line 5 wala hata diya
import 'package:pocket_tutor/features/chat/presentation/widgets/quiz.dart'
    show QuizWidget, QuizQuestion;

import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_tool_type.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/chat_tool_tag.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/flash_card.dart';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.imagePath,
    this.messageId,
    this.currentlySpeakingId,
    this.onSpeakToggled,
    this.toolTag,
    this.flashcardQuestion,
    this.flashcardAnswer,
    this.quizQuestions, // ✅ naya parameter
  });

  final String text;
  final bool isUser;
  final String? imagePath;
  final String? messageId;
  final String? currentlySpeakingId;
  final VoidCallback? onSpeakToggled;
  final String? toolTag;
  final String? flashcardQuestion;
  final String? flashcardAnswer;
  final List<QuizQuestion>? quizQuestions; // ✅ naya field

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  Uint8List? _cachedBytes;
  String? _lastDecodedPath;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _decodeImageIfNeeded();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath) {
      _decodeImageIfNeeded();
    }
  }

  void _decodeImageIfNeeded() {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) {
      _cachedBytes = null;
      _lastDecodedPath = null;
      return;
    }
    if (path == _lastDecodedPath) return;

    final isLocalFile = path.startsWith('/') ||
        path.startsWith('C:') ||
        path.contains('\\') ||
        path.startsWith('file://');

    if (!isLocalFile && (path.startsWith('data:') || path.length >= 100)) {
      try {
        String base64Data = path;
        if (path.startsWith('data:')) {
          final match = RegExp(r'^data:(.*?);base64,(.*)$').firstMatch(path);
          if (match != null) base64Data = match.group(2) ?? '';
        }
        _cachedBytes = base64Decode(base64Data);
        _lastDecodedPath = path;
      } catch (_) {
        _cachedBytes = null;
        _lastDecodedPath = null;
      }
    } else {
      _cachedBytes = null;
      _lastDecodedPath = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaking = widget.messageId != null &&
        widget.currentlySpeakingId == widget.messageId;
    final isUser = widget.isUser;
    final hasFlashcard = _hasFlashcard;

    // ✅ Quiz check sabse pehle — agar quiz hai toh seedha quiz widget return karo
    if (_hasQuiz) {
      return _buildQuizFromText(context);
    }

    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width *
              (hasFlashcard ? 0.92 : 0.78),
        ),
        child: hasFlashcard
            ? _buildFlashcardMessage(context)
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser) _aiAvatar(),
                  Flexible(
                    child: _buildBubble(context, isUser, isSpeaking),
                  ),
                ],
              ),
      ),
    );

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }

  bool get _hasFlashcard =>
      !widget.isUser &&
      widget.flashcardQuestion != null &&
      widget.flashcardQuestion!.trim().isNotEmpty &&
      widget.flashcardAnswer != null &&
      widget.flashcardAnswer!.trim().isNotEmpty;

  bool get _hasQuiz =>
      !widget.isUser &&
      ChatToolTypeX.fromStorageKey(widget.toolTag) ==
          ChatToolType.generateQuiz;

  // ✅ Fully fixed — dynamic questions use karta hai
  Widget _buildQuizFromText(BuildContext context) {
    // quizQuestions directly pass hue hain toh use karo
    List<QuizQuestion> questions = widget.quizQuestions ?? [];

    // Fallback: agar questions nahi aaye toh text se JSON parse karne ki koshish
    if (questions.isEmpty && widget.text.trim().isNotEmpty) {
      try {
        var cleaned = widget.text.trim();
        if (cleaned.startsWith('```')) {
          cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
          cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
          cleaned = cleaned.trim();
        }
        final decoded = jsonDecode(cleaned);
        if (decoded is List) {
          questions = decoded.map((item) {
            final m = item as Map<String, dynamic>;
            final opts = (m['options'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            while (opts.length < 4) {
              opts.add('Option ${opts.length + 1}');
            }
            return QuizQuestion(
              question: m['question']?.toString() ?? '',
              options: opts.take(4).toList(),
              correctIndex:
                  int.tryParse(m['correctAnswerIndex'].toString()) ?? 0,
            );
          }).toList();
        }
      } catch (_) {
        // parse nahi hua — empty list rahegi
      }
    }

    // Questions nahi hain — error state dikhao
    if (questions.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            _aiAvatar(),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Quiz load nahi hua. Dobara try karo.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ QuizWidget ko real questions ke saath render karo
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.92,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
          ),
        ),
        child: QuizWidget(questions: questions), // ✅ dynamic questions
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(right: 8, bottom: 2),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
    );
  }

  Widget _buildFlashcardMessage(BuildContext context) {
    final tool = ChatToolTypeX.fromStorageKey(widget.toolTag);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiAvatar(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                  ),
                ),
                child: FlashCard(
                  question: widget.flashcardQuestion!.trim(),
                  explanation: widget.flashcardAnswer!.trim(),
                ),
              ),
              if (tool != null) ...[
                const SizedBox(height: 8),
                ChatToolTag(tool: tool, compact: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, bool isUser, bool isSpeaking) {
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    if (isUser) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: AppColors.userBubbleGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _bubbleContent(context, isUser, isSpeaking),
      );
    } else {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _bubbleContent(context, isUser, isSpeaking),
      );
    }
  }

  Widget _bubbleContent(BuildContext context, bool isUser, bool isSpeaking) {
    final tool = ChatToolTypeX.fromStorageKey(widget.toolTag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.imagePath != null && widget.imagePath!.isNotEmpty) ...[
          _buildAttachmentWidget(context, widget.imagePath!),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: SelectableText(
                widget.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.onSurface,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            if (!isUser && widget.onSpeakToggled != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onSpeakToggled,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSpeaking
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSpeaking
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 17,
                    color: isSpeaking
                        ? AppColors.primaryLight
                        : AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            ],
            if (!isUser) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Copied ✓'),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (tool != null) ...[
          const SizedBox(height: 8),
          ChatToolTag(tool: tool, compact: true),
        ],
      ],
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, String path) {
    final isLocalFile = path.startsWith('/') ||
        path.startsWith('C:') ||
        path.contains('\\') ||
        path.startsWith('file://');

    String extension = '.jpg';
    String fileName = '';

    if (isLocalFile) {
      extension = p.extension(path).toLowerCase();
      fileName = p.basename(path);
    } else if (path.startsWith('data:')) {
      final match = RegExp(r'^data:(.*?);base64,').firstMatch(path);
      if (match != null) {
        final mimeType = match.group(1) ?? '';
        if (mimeType == 'application/pdf') {
          extension = '.pdf';
        } else if (mimeType.contains('word') ||
            mimeType.contains('msword') ||
            mimeType.contains('officedocument')) {
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

    final isImage =
        ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(extension);

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _buildImageWidget(path),
      );
    }

    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.onSurfaceMuted;
    Color iconBg = AppColors.surfaceMuted;
    if (extension == '.pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFFF4757);
      iconBg = const Color(0xFF2A1020);
    } else if (extension == '.docx' || extension == '.doc') {
      iconData = Icons.description_rounded;
      iconColor = const Color(0xFF06B6D4);
      iconBg = const Color(0xFF0A2030);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isNotEmpty ? fileName : 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  extension.replaceAll('.', '').toUpperCase(),
                  style: TextStyle(color: iconColor, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isLocalFile) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
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
              child: Icon(Icons.open_in_new_rounded,
                  color: iconColor, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    final isLocalFile = path.startsWith('/') ||
        path.startsWith('C:') ||
        path.contains('\\') ||
        path.startsWith('file://');

    Widget img;
    if (isLocalFile) {
      img = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => _brokenImage(),
      );
    } else if (_cachedBytes != null) {
      img = Image.memory(
        _cachedBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => _brokenImage(),
      );
    } else {
      img = _brokenImage();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: img,
    );
  }

  Widget _brokenImage() => Container(
        height: 120,
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded, color: AppColors.error),
      );
}