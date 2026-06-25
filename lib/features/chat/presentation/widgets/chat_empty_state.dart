import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/app/theme/app_decorations.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 50,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'How can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _PromptCard(
            text: 'Explain Quantum Entanglement like I\'m five.',
            onTap: () => onPromptSelected(
              'Explain Quantum Entanglement like I\'m five.',
            ),
          ),
          const SizedBox(height: 16),
          _PromptCard(
            text: 'Summarize my last lecture on Microeconomics.',
            onTap: () => onPromptSelected(
              'Summarize my last lecture on Microeconomics.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.onSurfaceMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
