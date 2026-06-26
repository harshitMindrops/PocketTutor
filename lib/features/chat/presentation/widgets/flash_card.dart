import 'dart:math';
import 'package:flutter/material.dart';

class FlashCard extends StatefulWidget {
  final String question;
  final String explanation;
  final String? detailedReview;

  const FlashCard({
    super.key,
    required this.question,
    required this.explanation,
    this.detailedReview,
  });

  @override
  State<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<FlashCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          // 0.0 - 0.5 → front visible, 0.5 - 1.0 → back visible
          final showBack = _anim.value >= 0.5;
          final angle = _anim.value * pi;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _BackFace(
                      explanation: widget.explanation,
                      detailedReview: widget.detailedReview,
                    ),
                  )
                : _FrontFace(question: widget.question),
          );
        },
      ),
    );
  }
}

// ─── Front Face ──────────────────────────────────────────────────────────────

class _FrontFace extends StatelessWidget {
  final String question;
  const _FrontFace({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tag
          Row(
            children: const [
              Icon(Icons.help_outline_rounded,
                  color: Color(0xFF7C5CFC), size: 14),
              SizedBox(width: 6),
              Text(
                'QUESTION',
                style: TextStyle(
                  color: Color(0xFF7C5CFC),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Question text
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),

          const Spacer(),

          // Tap to flip
          Column(
            children: const [
              Icon(Icons.flip_camera_android_rounded,
                  color: Colors.white38, size: 22),
              SizedBox(height: 6),
              Text(
                'Tap to flip',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Back Face ───────────────────────────────────────────────────────────────

class _BackFace extends StatefulWidget {
  final String explanation;
  final String? detailedReview;
  const _BackFace({required this.explanation, this.detailedReview});

  @override
  State<_BackFace> createState() => _BackFaceState();
}

class _BackFaceState extends State<_BackFace> {
  bool _reviewExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7C5CFC).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF7C5CFC), size: 14),
              SizedBox(width: 6),
              Text(
                'AI EXPLANATION',
                style: TextStyle(
                  color: Color(0xFF7C5CFC),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Explanation with bold highlights
          _HighlightedText(text: widget.explanation),

          const SizedBox(height: 20),

          // Detailed Review accordion
          if (widget.detailedReview != null) ...[
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _reviewExpanded = !_reviewExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detailed Review',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _reviewExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white54),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _reviewExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        widget.detailedReview!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Highlighted Text (bold keywords) ────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  const _HighlightedText({required this.text});

  @override
  Widget build(BuildContext context) {
    // Bold words wrapped in **word**
    final parts = text.split(RegExp(r'(\*\*.*?\*\*)'));
    final spans = parts.map((part) {
      if (part.startsWith('**') && part.endsWith('**')) {
        return TextSpan(
          text: part.replaceAll('**', ''),
          style: const TextStyle(
            color: Color(0xFF9B7FFF),
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.6,
          ),
        );
      }
      return TextSpan(
        text: part,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }).toList();

    return RichText(text: TextSpan(children: spans));
  }
}