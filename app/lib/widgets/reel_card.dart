import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../models/reel.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'source_viewer_sheet.dart';

class ReelCard extends StatefulWidget {
  final Reel reel;
  final bool isSaved;
  final bool isActive;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const ReelCard({
    super.key,
    required this.reel,
    required this.isSaved,
    required this.onSave,
    required this.onShare,
    this.isActive = true,
  });

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  int? _selectedQuizAnswer;
  bool _quizAnswered = false;
  bool _autoAdvance = true;

  late AnimationController _kenBurnsController;
  late AnimationController _slideTimerController;
  late AnimationController _particleController;

  late List<_Particle> _particles;
  final _random = Random();

  List<Color> get _gradient {
    final index =
        widget.reel.title.hashCode.abs() % AppTheme.reelGradients.length;
    return AppTheme.reelGradients[index];
  }

  int get _totalPages =>
      widget.reel.slides.length + (widget.reel.quiz != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _slideTimerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _slideTimerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _autoAdvance && mounted) {
        _advanceSlide();
      }
    });
    _slideTimerController.forward();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particles = List.generate(10, (_) => _Particle.random(_random));

    // Only speak if this card is actually the visible/active one.
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
    } else {
      // Pause auto-advance until this card is visible.
      _slideTimerController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // became active — start speaking current slide and resume timer
        _slideTimerController.forward();
        _speakCurrent();
      } else {
        // left the viewport — stop timers and our speech
        _slideTimerController.stop();
        TtsService.instance.stopIfOwner(widget.reel.id);
      }
    }
  }

  void _speakCurrent() {
    if (!widget.isActive) return;
    if (_currentSlide < widget.reel.slides.length) {
      final slide = widget.reel.slides[_currentSlide];
      TtsService.instance.speak(
        '${slide.heading}. ${slide.content}',
        owner: widget.reel.id,
      );
    }
  }

  void _replay() {
    HapticFeedback.lightImpact();
    _speakCurrent();
  }

  void _advanceSlide() {
    if (_currentSlide < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    TtsService.instance.stopIfOwner(widget.reel.id);
    _pageController.dispose();
    _kenBurnsController.dispose();
    _slideTimerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSlide = i;
      _autoAdvance = i < widget.reel.slides.length;
    });
    _slideTimerController.reset();
    if (_autoAdvance) _slideTimerController.forward();
    _speakCurrent();
  }

  void _toggleTts() {
    HapticFeedback.lightImpact();
    TtsService.instance.toggleMute();
    if (!TtsService.instance.muted && widget.isActive) {
      _speakCurrent();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient fallback
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
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            if (index < widget.reel.slides.length) {
              return _buildSlide(widget.reel.slides[index], index);
            } else {
              return _buildQuizSlide();
            }
          },
        ),

        // Floating particles
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => Stack(
              children: _buildParticles(),
            ),
          ),
        ),

        // Progress bars at top (Instagram-story style)
        if (_autoAdvance && _currentSlide < widget.reel.slides.length)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: List.generate(_totalPages, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _slideTimerController,
                          builder: (context, _) {
                            double progress;
                            if (i < _currentSlide) {
                              progress = 1.0;
                            } else if (i == _currentSlide) {
                              progress = _slideTimerController.value;
                            } else {
                              progress = 0.0;
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 3,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

        // Top bar: subject chip + TTS toggle + counter
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                children: [
                  _glassChip(
                    icon: Icons.auto_awesome_rounded,
                    label: widget.reel.subject.isEmpty
                        ? 'Study'
                        : widget.reel.subject,
                  ),
                  const Spacer(),
                  _glassIconButton(
                    icon: Icons.replay_rounded,
                    onTap: _replay,
                    tint: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<bool>(
                    valueListenable: TtsService.instance.isMuted,
                    builder: (context, muted, _) => _glassIconButton(
                      icon: muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleTts,
                      tint: muted ? Colors.white70 : AppTheme.accentWarm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _glassChip(
                    label: '${_currentSlide + 1}/$_totalPages',
                    small: true,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Page dots indicator
        Positioned(
          bottom: 96, left: 0, right: 0,
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

        // Right side action rail
        Positioned(
          right: 12, bottom: 120,
          child: Column(
            children: [
              _buildActionButton(
                icon: widget.isSaved
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                label: widget.isSaved ? 'Solved' : 'Mark',
                color: widget.isSaved ? AppTheme.success : Colors.white,
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

        // PDF + page footer
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
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
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
  }

  Widget _buildSlide(ReelSlide slide, int index) {
    final hasImage = slide.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          AnimatedBuilder(
            animation: _kenBurnsController,
            builder: (context, child) {
              final t = _kenBurnsController.value;
              final scale = 1.05 + (t * 0.15);
              final dx = sin(t * pi) * 20;
              final dy = cos(t * pi * 0.7) * 10;
              return Transform(
                transform: Matrix4.identity()
                  ..scaleByDouble(scale, scale, 1.0, 1.0)
                  ..translateByDouble(dx, dy, 0.0, 0.0),
                alignment: Alignment.center,
                child: child,
              );
            },
            child: CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              httpHeaders: const {'User-Agent': 'EduReels/1.0'},
              fadeInDuration: const Duration(milliseconds: 400),
              placeholder: (context, url) => _buildShimmer(),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradient,
                  ),
                ),
              ),
            ),
          ),

        // Cinematic dark vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Colors.black.withValues(alpha: hasImage ? 0.15 : 0.0),
                Colors.black.withValues(alpha: hasImage ? 0.55 : 0.0),
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
                Colors.black.withValues(alpha: hasImage ? 0.35 : 0.0),
                Colors.transparent,
                Colors.black.withValues(alpha: hasImage ? 0.75 : 0.0),
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),

        // Slide content
        TweenAnimationBuilder<double>(
          key: ValueKey('slide_$index'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 80, 28, 180),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji with glow halo
                  TweenAnimationBuilder<double>(
                    key: ValueKey('emoji_$index'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, _) => Transform.scale(
                      scale: value,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          boxShadow: AppTheme.glowShadow(AppTheme.accent),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slide.emoji,
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    slide.heading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      shadows: [
                        Shadow(blurRadius: 14, color: Colors.black54),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  _glassPanel(
                    child: Text(
                      slide.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.5,
                        shadows: [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizSlide() {
    if (widget.reel.quiz == null) return const SizedBox();
    final quiz = widget.reel.quiz!;
    final lastSlide =
        widget.reel.slides.isNotEmpty ? widget.reel.slides.last : null;
    final hasImage = lastSlide != null && lastSlide.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          CachedNetworkImage(
            imageUrl: lastSlide.imageUrl,
            fit: BoxFit.cover,
            httpHeaders: const {'User-Agent': 'EduReels/1.0'},
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (context, url) => _buildShimmer(),
            errorWidget: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradient),
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
                              child: Text(
                                option,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
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
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: _glassPanel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb,
                              color: AppTheme.accentWarm, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quiz.explanation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
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

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: _gradient[0].withValues(alpha: 0.4),
      highlightColor: _gradient[1].withValues(alpha: 0.6),
      period: const Duration(milliseconds: 1500),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradient,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_rounded,
          size: 72,
          color: Colors.white24,
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Glass helpers ----------
  Widget _glassChip(
      {IconData? icon, required String label, bool small = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 14,
            vertical: small ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  Widget _glassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
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

  factory _Particle.random(Random r) => _Particle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: r.nextDouble() * 3 + 1,
        speed: r.nextDouble() * 0.5 + 0.2,
        phase: r.nextDouble(),
        drift: r.nextDouble() * 0.03 + 0.01,
        maxOpacity: r.nextDouble() * 0.25 + 0.05,
      );
}
