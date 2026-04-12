import 'dart:math';
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _heartController;
  late AnimationController _particleController;
  late Animation<double> _heartScale;
  bool _isPaused = false;
  bool _showQuiz = false;
  bool _showHeart = false;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;
  int _prevSceneIndex = -1;

  // Particle system
  late List<_Particle> _particles;
  final _random = Random();

  List<ReelScene> get scenes => widget.reel.scenes;
  int get _totalDuration => scenes.fold(0, (sum, s) => sum + s.duration);

  @override
  void initState() {
    super.initState();

    // Main timeline controller
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

    // Heart animation
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartController);

    // Particle system controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate floating particles
    _particles = List.generate(15, (_) => _Particle.random(_random));
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.isLiked) widget.onLike();
    setState(() => _showHeart = true);
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
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
        _particleController.stop();
      } else {
        _controller.forward();
        _particleController.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showQuiz) return _buildQuizView();

    return GestureDetector(
      onTap: _togglePause,
      onDoubleTap: _handleDoubleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _particleController]),
        builder: (context, child) {
          final progress = _controller.value;
          final sceneIdx = _currentSceneIndex(progress);
          final scene = scenes[sceneIdx];
          final sProgress = _sceneProgress(progress, sceneIdx);

          // Detect scene change for transition
          final isNewScene = sceneIdx != _prevSceneIndex;
          if (isNewScene) _prevSceneIndex = sceneIdx;

          final gradient = scene.backgroundGradient;
          final color1 = _parseHex(gradient.isNotEmpty ? gradient[0] : '#667eea');
          final color2 = _parseHex(gradient.length > 1 ? gradient[1] : '#764ba2');

          final hasImage = scene.imageUrl.isNotEmpty;

          // Cinematic Ken Burns — pan and zoom
          final scale = 1.05 + (sProgress * 0.15);
          final panX = sin(sProgress * pi) * 20;
          final panY = cos(sProgress * pi * 0.5) * 10;

          // Scene transition opacity (fade in first 15%, fade out last 10%)
          double sceneOpacity = 1.0;
          if (sProgress < 0.15) {
            sceneOpacity = (sProgress / 0.15).clamp(0.0, 1.0);
          } else if (sProgress > 0.9) {
            sceneOpacity = ((1.0 - sProgress) / 0.1).clamp(0.0, 1.0);
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient (always visible as base)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color1, color2],
                  ),
                ),
              ),

              // AI image background with Ken Burns
              if (hasImage)
                Opacity(
                  opacity: sceneOpacity,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..scale(scale, scale)
                      ..translate(panX, panY),
                    alignment: Alignment.center,
                    child: Image.network(
                      scene.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox.expand();
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.expand(),
                    ),
                  ),
                ),

              // Cinematic dark vignette overlay
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // Floating particles
              ..._buildParticles(),

              // Scene content with cinematic animations
              _buildCinematicScene(scene, sProgress, sceneOpacity),

              // Story progress bars
              _buildProgressBars(progress),

              // Top bar: VIDEO badge + subject
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF416C).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16)),
                          child: Text(widget.reel.subject,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pause overlay
              if (_isPaused)
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
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
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black45)])),
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
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                        child: Text('#$tag', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      )).toList(),
                    ),
                  ],
                ),
              ),

              // Double-tap heart
              if (_showHeart)
                Center(
                  child: AnimatedBuilder(
                    animation: _heartScale,
                    builder: (context, child) => Transform.scale(
                      scale: _heartScale.value,
                      child: Icon(Icons.favorite, color: Colors.white.withValues(alpha: 0.9), size: 100,
                        shadows: const [Shadow(blurRadius: 30, color: Colors.redAccent)]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Cinematic scene with word-by-word text reveal and animated emoji
  Widget _buildCinematicScene(ReelScene scene, double progress, double opacity) {
    // Word-by-word reveal
    final words = scene.text.split(' ');
    final visibleWords = (words.length * progress * 1.3).ceil().clamp(0, words.length);

    // Emoji bounce timing
    final emojiScale = progress < 0.15
        ? Curves.elasticOut.transform((progress / 0.15).clamp(0.0, 1.0))
        : 1.0;

    // Subtle floating motion for content
    final floatY = sin(progress * pi * 2) * 3;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, floatY),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated emoji with glow
                Transform.scale(
                  scale: emojiScale,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(scene.emoji, style: const TextStyle(fontSize: 64)),
                  ),
                ),
                const SizedBox(height: 28),

                // Word-by-word text with highlight on latest word
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: List.generate(words.length, (i) {
                        final isVisible = i < visibleWords;
                        final isLatest = i == visibleWords - 1 && progress < 0.85;

                        return TextSpan(
                          text: '${words[i]} ',
                          style: TextStyle(
                            color: isVisible
                                ? (isLatest ? Colors.white : Colors.white.withValues(alpha: 0.95))
                                : Colors.transparent,
                            fontSize: 22,
                            fontWeight: isLatest ? FontWeight.w900 : FontWeight.bold,
                            height: 1.5,
                            shadows: isVisible
                                ? [
                                    const Shadow(blurRadius: 10, color: Colors.black54),
                                    if (isLatest)
                                      Shadow(blurRadius: 20, color: Colors.white.withValues(alpha: 0.3)),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Scene counter
                const SizedBox(height: 20),
                Text(
                  'Scene ${_currentSceneIndex(_controller.value) + 1} of ${scenes.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Floating particles for cinematic feel
  List<Widget> _buildParticles() {
    final t = _particleController.value;
    return _particles.map((p) {
      final x = p.x + sin((t + p.phase) * pi * 2) * p.drift;
      final y = (p.y - t * p.speed * 0.3) % 1.0;
      final opacity = (sin((t + p.phase) * pi * 2) * 0.5 + 0.5) * p.maxOpacity;

      return Positioned(
        left: x * MediaQuery.of(context).size.width,
        top: y * MediaQuery.of(context).size.height,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: (opacity * 0.5).clamp(0.0, 1.0)),
                blurRadius: p.size * 2,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildProgressBars(double overallProgress) {
    return Positioned(
      top: 0, left: 0, right: 0,
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
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
    if (widget.reel.quiz == null) return const SizedBox();
    final quiz = widget.reel.quiz!;

    final lastScene = scenes.isNotEmpty ? scenes.last : null;
    final hasImage = lastScene != null && lastScene.imageUrl.isNotEmpty;
    final color1 = _parseHex(lastScene?.backgroundGradient.isNotEmpty == true ? lastScene!.backgroundGradient[0] : '#667eea');
    final color2 = _parseHex(lastScene?.backgroundGradient.length == 2 ? lastScene!.backgroundGradient[1] : '#764ba2');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.network(
            lastScene!.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color1, color2]))),
          )
        else
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color1, color2]))),

        Container(color: Colors.black.withValues(alpha: hasImage ? 0.65 : 0.0)),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧠', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                const Text('Quick Quiz!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text(quiz.question, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ...quiz.options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final option = entry.value;
                  final isCorrect = i == quiz.answer;
                  final isSelected = _selectedQuizAnswer == i;

                  Color bgColor = Colors.white.withValues(alpha: 0.12);
                  Color borderColor = Colors.white.withValues(alpha: 0.2);
                  if (_quizAnswered) {
                    if (isCorrect) { bgColor = Colors.green.withValues(alpha: 0.4); borderColor = Colors.greenAccent; }
                    else if (isSelected) { bgColor = Colors.red.withValues(alpha: 0.4); borderColor = Colors.redAccent; }
                  } else if (isSelected) { bgColor = Colors.white.withValues(alpha: 0.25); borderColor = Colors.white; }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: _quizAnswered ? null : () => setState(() { _selectedQuizAnswer = i; _quizAnswered = true; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
                              child: Center(child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15))),
                            if (_quizAnswered && isCorrect) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                            if (_quizAnswered && isSelected && !isCorrect) const Icon(Icons.cancel, color: Colors.redAccent, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (_quizAnswered && quiz.explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
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
                        Expanded(child: Text(quiz.explanation, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4))),
                      ],
                    ),
                  ),
                ],

                if (_quizAnswered) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() { _showQuiz = false; _quizAnswered = false; _selectedQuizAnswer = null; _prevSceneIndex = -1; });
                      _controller.reset();
                      _controller.forward();
                    },
                    icon: const Icon(Icons.replay, color: Colors.white70, size: 18),
                    label: const Text('Replay', style: TextStyle(color: Colors.white70, fontSize: 15)),
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
            decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
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

// Particle data for floating light effects
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  final double drift;
  final double maxOpacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.drift,
    required this.maxOpacity,
  });

  factory _Particle.random(Random r) {
    return _Particle(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: r.nextDouble() * 3 + 1,
      speed: r.nextDouble() * 0.5 + 0.2,
      phase: r.nextDouble(),
      drift: r.nextDouble() * 0.03 + 0.01,
      maxOpacity: r.nextDouble() * 0.3 + 0.05,
    );
  }
}
