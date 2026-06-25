import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
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
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sendBtnCtrl;
  late final Animation<double> _sendBtnScale;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _sendBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..value = 1.0;
    _sendBtnScale = CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.easeOut);
    widget.controller.addListener(_onTextChange);
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _handleSend() async {
    await _sendBtnCtrl.reverse();
    _sendBtnCtrl.forward();
    widget.onSend(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _sendBtnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            _CircleIconBtn(
              icon: Icons.attach_file_rounded,
              color: AppColors.primaryLight,
              onTap: widget.onAttachPick,
            ),
            const SizedBox(width: 8),

            // Text field pill
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _hasText
                        ? AppColors.primaryLight.withValues(alpha: 0.5)
                        : AppColors.glassBorder,
                  ),
                  boxShadow: _hasText
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: 5,
                  minLines: 1,
                  style: const TextStyle(color: AppColors.onPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Ask anything... ✨',
                    hintStyle: TextStyle(color: AppColors.onSurfaceHint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  onSubmitted: widget.onSend,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Mic button
            _CircleIconBtn(
              icon: Icons.mic_none_rounded,
              color: AppColors.secondary,
              onTap: widget.onVoiceRecord,
            ),
            const SizedBox(width: 8),

            // Send button with scale animation
            ScaleTransition(
              scale: _sendBtnScale,
              child: GestureDetector(
                onTap: _handleSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _hasText
                        ? AppColors.userBubbleGradient
                        : const LinearGradient(
                            colors: [Color(0xFF2A2A50), Color(0xFF2A2A50)],
                          ),
                    boxShadow: _hasText
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}