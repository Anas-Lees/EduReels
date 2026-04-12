import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
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

class _ReelCardState extends State<ReelCard> {
  late PageController _pageController;
  int _currentSlide = 0;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;

  // Gradient colors for different reels
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

  int get _totalPages => widget.reel.slides.length + (widget.reel.quiz != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
      ),
      child: Stack(
        children: [
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

          // Top bar: title + subject
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.reel.subject,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentSlide + 1}/$_totalPages',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Page indicator
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _totalPages,
                effect: const WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 6,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white38,
                ),
              ),
            ),
          ),

          // Right side actions
          Positioned(
            right: 16,
            bottom: 140,
            child: Column(
              children: [
                _buildActionButton(
                  icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.reel.likes}',
                  color: widget.isLiked ? Colors.red : Colors.white,
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
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.white,
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),

          // Bottom info
          Positioned(
            bottom: 40,
            left: 20,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reel.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'From: ${widget.reel.pdfName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: widget.reel.tags
                      .take(3)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(ReelSlide slide, int index) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slide.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 24),
            Text(
              slide.heading,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              slide.content,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSlide() {
    final quiz = widget.reel.quiz!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Quick Quiz!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              quiz.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...quiz.options.asMap().entries.map((entry) {
              final i = entry.key;
              final option = entry.value;
              final isCorrect = i == quiz.answer;
              final isSelected = _selectedQuizAnswer == i;

              Color bgColor = Colors.white.withValues(alpha: 0.15);
              if (_quizAnswered) {
                if (isCorrect) {
                  bgColor = Colors.green.withValues(alpha: 0.5);
                } else if (isSelected && !isCorrect) {
                  bgColor = Colors.red.withValues(alpha: 0.5);
                }
              } else if (isSelected) {
                bgColor = Colors.white.withValues(alpha: 0.3);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: _quizAnswered
                      ? null
                      : () {
                          setState(() {
                            _selectedQuizAnswer = i;
                            _quizAnswered = true;
                          });
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${String.fromCharCode(65 + i)}.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_quizAnswered && isCorrect)
                          const Icon(Icons.check_circle, color: Colors.white),
                        if (_quizAnswered && isSelected && !isCorrect)
                          const Icon(Icons.cancel, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
