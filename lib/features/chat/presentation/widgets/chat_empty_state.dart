import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

class ChatEmptyState extends StatefulWidget {
  const ChatEmptyState({super.key, required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  @override
  State<ChatEmptyState> createState() => _ChatEmptyStateState();
}

class _ChatEmptyStateState extends State<ChatEmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFloat;
  late final List<AnimationController> _cardCtrls;

  static const _prompts = [
    (
      icon: '⚡',
      label: 'Explain Quantum Entanglement like I\'m 5',
      color: Color(0xFF7C3AED),
    ),
    (
      icon: '📚',
      label: 'Summarize my Microeconomics lecture',
      color: Color(0xFF06B6D4),
    ),
    (
      icon: '🧮',
      label: 'Solve this Math problem step-by-step',
      color: Color(0xFF10B981),
    ),
    (
      icon: '✍️',
      label: 'Help me write an essay outline',
      color: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoFloat = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _cardCtrls = List.generate(
      _prompts.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    for (var i = 0; i < _prompts.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _cardCtrls[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Floating logo
          AnimatedBuilder(
            animation: _logoFloat,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _logoFloat.value),
              child: child,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset("assets/images/logo.png", fit: BoxFit.fill),
            ),
          ),

          const SizedBox(height: 28),

          // Greeting
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.heroGradient.createShader(bounds),
            child: const Text(
              "What's the vibe today? 🧠",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Pick a prompt or type your question below',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
          ),

          const SizedBox(height: 36),

          // Prompt cards
          ...List.generate(_prompts.length, (i) {
            final prompt = _prompts[i];
            return AnimatedBuilder(
              animation: _cardCtrls[i],
              builder: (_, child) {
                final t = CurvedAnimation(
                  parent: _cardCtrls[i],
                  curve: Curves.easeOutCubic,
                ).value;
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - t)),
                  child: Opacity(opacity: t, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PromptCard(
                  icon: prompt.icon,
                  text: prompt.label,
                  accentColor: prompt.color,
                  onTap: () => widget.onPromptSelected(prompt.label),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PromptCard extends StatefulWidget {
  const _PromptCard({
    required this.icon,
    required this.text,
    required this.accentColor,
    required this.onTap,
  });

  final String icon;
  final String text;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: _pressed ? 0.5 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(
                  alpha: _pressed ? 0.2 : 0.07,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: widget.accentColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
