import 'package:flutter/material.dart';
import '../models/reel.dart';

class VideoReelCard extends StatefulWidget {
  final Reel reel;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const VideoReelCard({
    super.key,
    required this.reel,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<VideoReelCard> createState() => _VideoReelCardState();
}

class _VideoReelCardState extends State<VideoReelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPaused = false;
  bool _showQuiz = false;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;

  List<ReelScene> get scenes => widget.reel.scenes;

  int get _totalDuration =>
      scenes.fold(0, (sum, s) => sum + s.duration);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalDuration),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.reel.quiz != null) {
          setState(() => _showQuiz = true);
        } else {
          _controller.reset();
          _controller.forward();
        }
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _currentSceneIndex(double progress) {
    double cumulative = 0;
    for (int i = 0; i < scenes.length; i++) {
      cumulative += scenes[i].duration / _totalDuration;
      if (progress < cumulative) return i;
    }
    return scenes.length - 1;
  }

  double _sceneProgress(double progress, int sceneIndex) {
    double start = 0;
    for (int i = 0; i < sceneIndex; i++) {
      start += scenes[i].duration / _totalDuration;
    }
    final sceneFraction = scenes[sceneIndex].duration / _totalDuration;
    return ((progress - start) / sceneFraction).clamp(0.0, 1.0);
  }

  Color _parseHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _controller.stop();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showQuiz) {
      return _buildQuizView();
    }

    return GestureDetector(
      onTap: _togglePause,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final sceneIdx = _currentSceneIndex(progress);
          final scene = scenes[sceneIdx];
          final sProgress = _sceneProgress(progress, sceneIdx);

          final gradient = scene.backgroundGradient;
          final color1 = _parseHex(gradient.isNotEmpty ? gradient[0] : '#667eea');
          final color2 = _parseHex(gradient.length > 1 ? gradient[1] : '#764ba2');

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color1, color2],
              ),
            ),
            child: Stack(
              children: [
                // Scene content
                _buildScene(scene, sProgress),

                // Story-style progress bars at top
                _buildProgressBars(progress),

                // Video badge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 40),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('VIDEO',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              widget.reel.subject,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pause icon
                if (_isPaused)
                  const Center(
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white54, size: 80),
                  ),

                // Right side actions
                Positioned(
                  right: 16,
                  bottom: 140,
                  child: Column(
                    children: [
                      _buildActionButton(
                        icon: widget.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: '${widget.reel.likes}',
                        color: widget.isLiked ? Colors.red : Colors.white,
                        onTap: widget.onLike,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        icon: widget.isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
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
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('#$tag',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScene(ReelScene scene, double progress) {
    // Typewriter text reveal
    final visibleChars = (scene.text.length * progress).floor();
    final displayText = scene.text.substring(
        0, visibleChars.clamp(0, scene.text.length));

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji with scale animation
            TweenAnimationBuilder<double>(
              key: ValueKey(scene.emoji),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Text(scene.emoji,
                      style: const TextStyle(fontSize: 72)),
                );
              },
            ),
            const SizedBox(height: 32),
            // Typewriter text
            Text(
              displayText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars(double overallProgress) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: List.generate(scenes.length, (i) {
              double start = 0;
              for (int j = 0; j < i; j++) {
                start += scenes[j].duration / _totalDuration;
              }
              final sceneFraction = scenes[i].duration / _totalDuration;
              final sceneEnd = start + sceneFraction;

              double barProgress;
              if (overallProgress >= sceneEnd) {
                barProgress = 1.0;
              } else if (overallProgress <= start) {
                barProgress = 0.0;
              } else {
                barProgress = (overallProgress - start) / sceneFraction;
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: barProgress,
                      backgroundColor: Colors.white30,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizView() {
    final quiz = widget.reel.quiz!;
    final lastScene = scenes.last;
    final color1 =
        _parseHex(lastScene.backgroundGradient.isNotEmpty ? lastScene.backgroundGradient[0] : '#667eea');
    final color2 = _parseHex(
        lastScene.backgroundGradient.length > 1 ? lastScene.backgroundGradient[1] : '#764ba2');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧠', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Quick Quiz!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(quiz.question,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center),
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
                        : () => setState(() {
                              _selectedQuizAnswer = i;
                              _quizAnswered = true;
                            }),
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
                          Text('${String.fromCharCode(65 + i)}.',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(option,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16))),
                          if (_quizAnswered && isCorrect)
                            const Icon(Icons.check_circle,
                                color: Colors.white),
                          if (_quizAnswered && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (_quizAnswered) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showQuiz = false;
                      _quizAnswered = false;
                      _selectedQuizAnswer = null;
                    });
                    _controller.reset();
                    _controller.forward();
                  },
                  child: const Text('Replay',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ],
          ),
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
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
