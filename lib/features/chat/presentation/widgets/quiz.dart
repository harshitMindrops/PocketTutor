import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL  — category hataya, correctIndex use karo (gemini_service se match)
// ─────────────────────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN QUIZ WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class QuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final VoidCallback? onDone;
  final VoidCallback? onReview;

  const QuizWidget({
    super.key,
    required this.questions, // ✅ required — koi default nahi
    this.onDone,
    this.onReview,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> with TickerProviderStateMixin {
  int _current = 0;
  int? _selected;
  late List<int?> _answers; // ✅ late — initState mein dynamic size set hogi
  bool _showResult = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null); // ✅ dynamic size

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _animateIn() {
    _slideCtrl.reset();
    _fadeCtrl.reset();
    _slideCtrl.forward();
    _fadeCtrl.forward();
  }

  void _next() {
    if (_selected == null) return;
    _answers[_current] = _selected;

    if (_current == widget.questions.length - 1) {
      setState(() => _showResult = true);
      _animateIn();
      return;
    }
    setState(() {
      _current++;
      _selected = null;
    });
    _animateIn();
  }

  int get _correctCount => _answers.asMap().entries.where((e) {
        if (e.key >= widget.questions.length) return false;
        return e.value == widget.questions[e.key].correctIndex;
      }).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1221),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: _showResult
              ? _ResultPanel(
                  correct: _correctCount,
                  total: widget.questions.length,
                  onDone: widget.onDone ?? () {},
                  onReview: widget.onReview ?? () {},
                )
              : _QuestionPanel(
                  question: widget.questions[_current],
                  index: _current,
                  total: widget.questions.length,
                  selected: _selected,
                  onSelect: (i) => setState(() => _selected = i),
                  onNext: _next,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final QuizQuestion question;
  final int index;
  final int total;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  const _QuestionPanel({
    required this.question,
    required this.index,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / total;

    return SafeArea(
      child: Container(
        height: 600,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar row
            Row(
              children: [
                Text(
                  'QUESTION ${index + 1} OF $total',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF7C5CFC)),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Question text — category hata diya
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.45,
                ),
                children: _buildQuestionSpans(question.question),
              ),
            ),

            const SizedBox(height: 28),

            // Options
            ...List.generate(question.options.length, (i) {
              return _OptionTile(
                label: String.fromCharCode(65 + i), // A B C D
                text: question.options[i],
                state: selected == null
                    ? _OptionState.idle
                    : selected == i
                        ? _OptionState.selected
                        : _OptionState.dimmed,
                onTap: () => onSelect(i),
              );
            }),

            const Spacer(),

            // Next button
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                opacity: selected != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: selected != null ? onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    disabledBackgroundColor: const Color(0xFF7C5CFC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildQuestionSpans(String text) {
    final regex = RegExp(r'\[\[(.*?)\]\]');
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(color: Color(0xFF9B7FFF)),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────────────────────────────────────

enum _OptionState { idle, selected, dimmed }

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state == _OptionState.selected;
    final isDimmed = state == _OptionState.dimmed;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C5CFC).withOpacity(0.18)
              : const Color(0xFF1A1F35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C5CFC) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF7C5CFC) : Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isDimmed ? Colors.white38 : Colors.white,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF7C5CFC), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _ResultPanel extends StatefulWidget {
  final int correct;
  final int total;
  final VoidCallback onDone;
  final VoidCallback onReview;

  const _ResultPanel({
    required this.correct,
    required this.total,
    required this.onDone,
    required this.onReview,
  });

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut);
    _ringCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  String get _title {
    final pct = widget.correct / widget.total;
    if (pct >= 0.9) return 'Outstanding, Researcher!';
    if (pct >= 0.7) return 'Great job, Researcher!';
    if (pct >= 0.5) return 'Good effort, Researcher!';
    return 'Keep practising, Researcher!';
  }

  int get _masteryLevel {
    final pct = widget.correct / widget.total;
    if (pct >= 0.9) return 5;
    if (pct >= 0.75) return 4;
    if (pct >= 0.6) return 3;
    if (pct >= 0.4) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.correct / widget.total;
    final pctInt = (pct * 100).round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Circular ring
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ..._buildSparkles(),
                  AnimatedBuilder(
                    animation: _ringAnim,
                    builder: (_, __) => CustomPaint(
                      size: const Size(180, 180),
                      painter:
                          _RingPainter(progress: _ringAnim.value * pct),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: pctInt),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOut,
                        builder: (_, val, __) => Text(
                          '$val%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.correct}/${widget.total} CORRECT',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You completed the quiz with ${widget.correct} out of ${widget.total} correct answers.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            // Stats card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.quiz_outlined,
                    iconColor: const Color(0xFF4A90D9),
                    label: 'QUESTIONS',
                    value: '${widget.total}',
                    badge: 'TOTAL',
                    badgeColor: const Color(0xFF7C5CFC),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _StatRow(
                    icon: Icons.track_changes_outlined,
                    iconColor: const Color(0xFFE07B39),
                    label: 'ACCURACY',
                    value: pct >= 0.7
                        ? 'High'
                        : pct >= 0.4
                            ? 'Medium'
                            : 'Low',
                    badge: 'STABLE',
                    badgeColor: const Color(0xFF4A90D9),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Topic mastery
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOPIC MASTERY',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Level $_masteryLevel',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _masteryLevel / 5),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF7C5CFC),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFC),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onReview,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Review Answers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    final positions = [
      const Offset(20, 30),
      const Offset(150, 20),
      const Offset(165, 100),
      const Offset(10, 130),
      const Offset(80, 170),
      const Offset(140, 160),
    ];
    return positions
        .map((p) => Positioned(left: p.dx, top: p.dy, child: _SparkleBox()))
        .toList();
  }
}

class _SparkleBox extends StatefulWidget {
  @override
  State<_SparkleBox> createState() => _SparkleBoxState();
}

class _SparkleBoxState extends State<_SparkleBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (6 + Random().nextInt(6)).toDouble();
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF7C5CFC).withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.1)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RING PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: const [Color(0xFF7C5CFC), Color(0xFFB57BFF)],
      stops: [progress, progress],
    );

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}