import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/reel.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'source_viewer_sheet.dart';

class VideoReelCard extends StatefulWidget {
  final Reel reel;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const VideoReelCard({
    super.key,
    required this.reel,
    required this.isSaved,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<VideoReelCard> createState() => _VideoReelCardState();
}

class _VideoReelCardState extends State<VideoReelCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  bool _isPaused = false;
  bool _showQuiz = false;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;
  int _prevSceneIndex = -1;

  late List<_Particle> _particles;
  final _random = Random();

  List<ReelScene> get scenes => widget.reel.scenes;
  int get _totalDuration => scenes.fold(0, (sum, s) => sum + s.duration);

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

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particles = List.generate(12, (_) => _Particle.random(_random));

    // Speak narration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.reel.narration.isNotEmpty) {
        TtsService.instance.speak(widget.reel.narration, owner: widget.reel.id);
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stopIfOwner(widget.reel.id);
    _controller.dispose();
    _particleController.dispose();
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
    HapticFeedback.selectionClick();
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

  void _toggleTts() {
    HapticFeedback.lightImpact();
    TtsService.instance.toggleMute();
    if (!TtsService.instance.muted && widget.reel.narration.isNotEmpty) {
      TtsService.instance.speak(widget.reel.narration, owner: widget.reel.id);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_showQuiz) return _buildQuizView();

    return GestureDetector(
      onTap: _togglePause,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _particleController]),
        builder: (context, child) {
          final progress = _controller.value;
          final sceneIdx = _currentSceneIndex(progress);
          final scene = scenes[sceneIdx];
          final sProgress = _sceneProgress(progress, sceneIdx);

          if (sceneIdx != _prevSceneIndex) _prevSceneIndex = sceneIdx;

          final gradient = scene.backgroundGradient;
          final color1 =
              _parseHex(gradient.isNotEmpty ? gradient[0] : '#667eea');
          final color2 =
              _parseHex(gradient.length > 1 ? gradient[1] : '#764ba2');

          final hasImage = scene.imageUrl.isNotEmpty;
          final scale = 1.05 + (sProgress * 0.15);
          final panX = sin(sProgress * pi) * 20;
          final panY = cos(sProgress * pi * 0.5) * 10;

          double sceneOpacity = 1.0;
          if (sProgress < 0.15) {
            sceneOpacity = (sProgress / 0.15).clamp(0.0, 1.0);
          } else if (sProgress > 0.9) {
            sceneOpacity = ((1.0 - sProgress) / 0.1).clamp(0.0, 1.0);
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color1, color2],
                  ),
                ),
              ),
              if (hasImage)
                Opacity(
                  opacity: sceneOpacity,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..scaleByDouble(scale, scale, 1.0, 1.0)
                      ..translateByDouble(panX, panY, 0.0, 0.0),
                    alignment: Alignment.center,
                    child: CachedNetworkImage(
                      imageUrl: scene.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      httpHeaders: const {'User-Agent': 'EduReels/1.0'},
                      fadeInDuration: const Duration(milliseconds: 400),
                      placeholder: (context, url) =>
                          _buildShimmer([color1, color2]),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color1, color2]),
                        ),
                      ),
                    ),
                  ),
                ),

              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.6),
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
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              IgnorePointer(child: Stack(children: _buildParticles())),

              _buildCinematicScene(scene, sProgress, sceneOpacity),

              _buildProgressBars(progress),

              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Row(
                      children: [
                        _glassChip(
                          icon: Icons.play_circle_fill_rounded,
                          label: 'VIDEO',
                          tint: AppTheme.accent,
                        ),
                        const SizedBox(width: 8),
                        _glassChip(
                          icon: Icons.auto_awesome_rounded,
                          label: widget.reel.subject.isEmpty
                              ? 'Study'
                              : widget.reel.subject,
                        ),
                        const Spacer(),
                        ValueListenableBuilder<bool>(
                          valueListenable: TtsService.instance.isMuted,
                          builder: (context, muted, _) => _glassIconButton(
                            icon: muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            onTap: _toggleTts,
                            tint:
                                muted ? Colors.white70 : AppTheme.accentWarm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isPaused)
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        boxShadow:
                            AppTheme.glowShadow(Colors.white),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),

              // Right action rail
              Positioned(
                right: 12, bottom: 120,
                child: Column(
                  children: [
                    _buildActionButton(
                      icon: widget.isSaved
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      label: widget.isSaved ? 'Solved' : 'Mark',
                      color: widget.isSaved
                          ? AppTheme.success
                          : Colors.white,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onSave();
                      },
                    ),
                    const SizedBox(height: 22),
                    _buildActionButton(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      color: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onShare();
                      },
                    ),
                    const SizedBox(height: 22),
                    _buildActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Source',
                      color: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SourceViewerSheet.show(
                          context,
                          sourceQuote: widget.reel.sourceQuote,
                          pageNumber: widget.reel.pageNumber,
                          reelTitle: widget.reel.title,
                        );
                      },
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 36, left: 20, right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.reel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54)
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.reel.pdfName.isEmpty
                                ? 'Study reel'
                                : widget.reel.pdfName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (widget.reel.pageNumber > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'p.${widget.reel.pageNumber}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCinematicScene(
      ReelScene scene, double progress, double opacity) {
    final words = scene.text.split(' ');
    final visibleWords =
        (words.length * progress * 1.3).ceil().clamp(0, words.length);

    final emojiScale = progress < 0.15
        ? Curves.elasticOut.transform((progress / 0.15).clamp(0.0, 1.0))
        : 1.0;

    final floatY = sin(progress * pi * 2) * 3;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, floatY),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 80, 28, 180),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: emojiScale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      boxShadow: AppTheme.glowShadow(AppTheme.accent),
                    ),
                    alignment: Alignment.center,
                    child: Text(scene.emoji,
                        style: const TextStyle(fontSize: 56)),
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: List.generate(words.length, (i) {
                            final isVisible = i < visibleWords;
                            final isLatest =
                                i == visibleWords - 1 && progress < 0.85;

                            return TextSpan(
                              text: '${words[i]} ',
                              style: TextStyle(
                                color: isVisible
                                    ? Colors.white
                                    : Colors.transparent,
                                fontSize: 22,
                                fontWeight: isLatest
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                height: 1.45,
                                shadows: isVisible
                                    ? [
                                        const Shadow(
                                            blurRadius: 10,
                                            color: Colors.black54),
                                        if (isLatest)
                                          Shadow(
                                            blurRadius: 20,
                                            color: AppTheme.accent
                                                .withValues(alpha: 0.4),
                                          ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scene ${_currentSceneIndex(_controller.value) + 1} of ${scenes.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final t = _particleController.value;
    final screenSize = MediaQuery.sizeOf(context);
    return _particles.map((p) {
      final x = p.x + sin((t + p.phase) * pi * 2) * p.drift;
      final y = (p.y - t * p.speed * 0.3) % 1.0;
      final opacity =
          (sin((t + p.phase) * pi * 2) * 0.5 + 0.5) * p.maxOpacity;

      return Positioned(
        left: x * screenSize.width,
        top: y * screenSize.height,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.white
                    .withValues(alpha: (opacity * 0.5).clamp(0.0, 1.0)),
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
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
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barProgress,
                      backgroundColor: Colors.white24,
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
    if (widget.reel.quiz == null) return const SizedBox();
    final quiz = widget.reel.quiz!;
    final lastScene = scenes.isNotEmpty ? scenes.last : null;
    final hasImage = lastScene != null && lastScene.imageUrl.isNotEmpty;
    final color1 = _parseHex(
        lastScene?.backgroundGradient.isNotEmpty == true
            ? lastScene!.backgroundGradient[0]
            : '#667eea');
    final color2 = _parseHex(lastScene?.backgroundGradient.length == 2
        ? lastScene!.backgroundGradient[1]
        : '#764ba2');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          CachedNetworkImage(
            imageUrl: lastScene.imageUrl,
            fit: BoxFit.cover,
            httpHeaders: const {'User-Agent': 'EduReels/1.0'},
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (context, url) => _buildShimmer([color1, color2]),
            errorWidget: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color1, color2]),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color1, color2],
              ),
            ),
          ),

        Container(color: Colors.black.withValues(alpha: hasImage ? 0.7 : 0.0)),

        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 160),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppTheme.accent.withValues(alpha: 0.35),
                      Colors.transparent,
                    ]),
                  ),
                  child: const Text('🧠', style: TextStyle(fontSize: 44)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quick Quiz!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  quiz.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...quiz.options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final option = entry.value;
                  final isCorrect = i == quiz.answer;
                  final isSelected = _selectedQuizAnswer == i;

                  Color bgColor = Colors.white.withValues(alpha: 0.1);
                  Color borderColor = Colors.white.withValues(alpha: 0.2);
                  if (_quizAnswered) {
                    if (isCorrect) {
                      bgColor = AppTheme.success.withValues(alpha: 0.35);
                      borderColor = AppTheme.success;
                    } else if (isSelected) {
                      bgColor = AppTheme.danger.withValues(alpha: 0.3);
                      borderColor = AppTheme.danger;
                    }
                  } else if (isSelected) {
                    bgColor = Colors.white.withValues(alpha: 0.2);
                    borderColor = Colors.white;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: _quizAnswered
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _selectedQuizAnswer = i;
                                _quizAnswered = true;
                              });
                              TtsService.instance.speak(
                                i == quiz.answer
                                    ? 'Correct! ${quiz.explanation}'
                                    : 'Not quite. ${quiz.explanation}',
                                owner: widget.reel.id,
                              );
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(option,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15)),
                            ),
                            if (_quizAnswered && isCorrect)
                              const Icon(Icons.check_circle,
                                  color: AppTheme.success, size: 22),
                            if (_quizAnswered && isSelected && !isCorrect)
                              const Icon(Icons.cancel,
                                  color: AppTheme.danger, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_quizAnswered && quiz.explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb,
                                color: AppTheme.accentWarm, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(quiz.explanation,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (_quizAnswered) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showQuiz = false;
                        _quizAnswered = false;
                        _selectedQuizAnswer = null;
                        _prevSceneIndex = -1;
                      });
                      _controller.reset();
                      _controller.forward();
                    },
                    icon: const Icon(Icons.replay_rounded,
                        color: Colors.white70, size: 18),
                    label: const Text('Replay',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 15)),
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
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              )),
        ],
      ),
    );
  }

  Widget _buildShimmer(List<Color> colors) {
    return Shimmer.fromColors(
      baseColor: colors[0].withValues(alpha: 0.4),
      highlightColor: colors[1].withValues(alpha: 0.6),
      period: const Duration(milliseconds: 1500),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_rounded,
            size: 72, color: Colors.white24),
      ),
    );
  }

  Widget _glassChip(
      {required IconData icon,
      required String label,
      Color tint = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tint, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton(
      {required IconData icon,
      required VoidCallback onTap,
      Color tint = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, size, speed, phase, drift, maxOpacity;

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
