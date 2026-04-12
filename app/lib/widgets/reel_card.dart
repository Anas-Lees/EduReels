import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reel.dart';

class ReelCard extends StatefulWidget {
  final Reel reel;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const ReelCard({
    super.key,
    required this.reel,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;
  bool _showHeart = false;

  late AnimationController _kenBurnsController;
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  static const List<List<Color>> _gradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFF43e97b), Color(0xFF38f9d7)],
    [Color(0xFFfa709a), Color(0xFFfee140)],
    [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
    [Color(0xFFfccb90), Color(0xFFd57eeb)],
    [Color(0xFF6991c7), Color(0xFFA3BDED)],
  ];

  List<Color> get _gradient {
    final index = widget.reel.title.hashCode.abs() % _gradients.length;
    return _gradients[index];
  }

  int get _totalPages =>
      widget.reel.slides.length + (widget.reel.quiz != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _kenBurnsController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.isLiked) widget.onLike();
    setState(() => _showHeart = true);
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        children: [
          // Background - gradient fallback
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradient,
              ),
            ),
          ),

          // Slide content
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (i) => setState(() => _currentSlide = i),
            itemBuilder: (context, index) {
              if (index < widget.reel.slides.length) {
                return _buildSlide(widget.reel.slides[index], index);
              } else {
                return _buildQuizSlide();
              }
            },
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(widget.reel.subject,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${_currentSlide + 1}/$_totalPages',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Page indicator
          Positioned(
            bottom: 120, left: 0, right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _totalPages,
                effect: const ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  expansionFactor: 3,
                  spacing: 5,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white38,
                ),
              ),
            ),
          ),

          // Right side actions
          Positioned(
            right: 12, bottom: 140,
            child: Column(
              children: [
                _buildActionButton(
                  icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.reel.likes}',
                  color: widget.isLiked ? Colors.redAccent : Colors.white,
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: 'Save',
                  color: widget.isSaved ? Colors.amber : Colors.white,
                  onTap: widget.onSave,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: Colors.white,
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),

          // Bottom info
          Positioned(
            bottom: 30, left: 20, right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.reel.title,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                  )),
                const SizedBox(height: 4),
                Text('From: ${widget.reel.pdfName}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black26)]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: widget.reel.tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('#$tag', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  )).toList(),
                ),
              ],
            ),
          ),

          // Double-tap heart overlay
          if (_showHeart)
            Center(
              child: AnimatedBuilder(
                animation: _heartScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartScale.value,
                    child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(ReelSlide slide, int index) {
    final hasImage = slide.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // AI image background with Ken Burns
        if (hasImage)
          AnimatedBuilder(
            animation: _kenBurnsController,
            builder: (context, child) {
              final scale = 1.0 + (_kenBurnsController.value * 0.12);
              final dx = (_kenBurnsController.value - 0.5) * 20;
              final dy = (_kenBurnsController.value - 0.5) * 10;
              return Transform(
                transform: Matrix4.identity()
                  ..scale(scale)
                  ..translate(dx, dy),
                alignment: Alignment.center,
                child: child,
              );
            },
            child: CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradient),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradient),
                ),
              ),
            ),
          ),

        // Dark overlay for text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: hasImage ? 0.3 : 0.0),
                Colors.black.withValues(alpha: hasImage ? 0.5 : 0.0),
                Colors.black.withValues(alpha: hasImage ? 0.7 : 0.0),
              ],
            ),
          ),
        ),

        // Content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slide.emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 20),
                Text(
                  slide.heading,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    slide.content,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 17, height: 1.5,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizSlide() {
    if (widget.reel.quiz == null) return const SizedBox();
    final quiz = widget.reel.quiz!;

    // Use last slide's image as quiz background
    final lastSlide = widget.reel.slides.isNotEmpty ? widget.reel.slides.last : null;
    final hasImage = lastSlide != null && lastSlide.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          CachedNetworkImage(
            imageUrl: lastSlide!.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(),
            errorWidget: (_, __, ___) => const SizedBox(),
          ),
        Container(color: Colors.black.withValues(alpha: hasImage ? 0.65 : 0.0)),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧠', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                const Text('Quick Quiz!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text(quiz.question,
                  style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
                  textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ...quiz.options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final option = entry.value;
                  final isCorrect = i == quiz.answer;
                  final isSelected = _selectedQuizAnswer == i;

                  Color bgColor = Colors.white.withValues(alpha: 0.12);
                  Color borderColor = Colors.white.withValues(alpha: 0.2);
                  if (_quizAnswered) {
                    if (isCorrect) {
                      bgColor = Colors.green.withValues(alpha: 0.4);
                      borderColor = Colors.greenAccent;
                    } else if (isSelected) {
                      bgColor = Colors.red.withValues(alpha: 0.4);
                      borderColor = Colors.redAccent;
                    }
                  } else if (isSelected) {
                    bgColor = Colors.white.withValues(alpha: 0.25);
                    borderColor = Colors.white;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: _quizAnswered ? null : () {
                        setState(() {
                          _selectedQuizAnswer = i;
                          _quizAnswered = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              child: Center(
                                child: Text('${String.fromCharCode(65 + i)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15)),
                            ),
                            if (_quizAnswered && isCorrect)
                              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                            if (_quizAnswered && isSelected && !isCorrect)
                              const Icon(Icons.cancel, color: Colors.redAccent, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation after answering
                if (_quizAnswered && quiz.explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _quizAnswered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(quiz.explanation,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black38)])),
        ],
      ),
    );
  }
}
