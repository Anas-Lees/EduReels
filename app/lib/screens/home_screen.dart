import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/reel.dart';
import '../providers/reel_provider.dart';
import '../services/tts_service.dart';
import '../widgets/reel_card.dart';
import '../widgets/video_reel_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ReelProvider>();
      await provider.loadReels();
      if (mounted && provider.reels.isNotEmpty) {
        _preloadImages(provider.reels, 0);
        TtsService.instance.setActiveOwner(provider.reels[0].id);
      }
    });
  }

  void _preloadImages(List<Reel> reels, int currentIndex) {
    for (int i = currentIndex + 1; i <= currentIndex + 5 && i < reels.length; i++) {
      final reel = reels[i];
      if (reel.type == 'video' && reel.scenes.isNotEmpty) {
        for (final scene in reel.scenes) {
          try {
            precacheImage(CachedNetworkImageProvider(scene.imageUrl), context);
          } catch (_) {}
        }
      } else {
        for (final slide in reel.slides) {
          try {
            precacheImage(CachedNetworkImageProvider(slide.imageUrl), context);
          } catch (_) {}
        }
      }
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    if (reelProvider.loading && reelProvider.reels.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        body: _buildShimmerLoading(),
      );
    }

    if (reelProvider.reels.isEmpty && !reelProvider.isGenerating) {
      return Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF667eea).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, size: 56, color: Color(0xFF667eea)),
                ),
                const SizedBox(height: 28),
                const Text('No reels yet',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 10),
                Text('Upload a PDF to generate your first reels',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 15, height: 1.4)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_up_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text('Swipe through reels once created',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: reelProvider.reels.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
              reelProvider.trackView(reelProvider.reels[index].id);
              _preloadImages(reelProvider.reels, index);
              TtsService.instance
                  .setActiveOwner(reelProvider.reels[index].id);
            },
            itemBuilder: (context, index) {
              final reel = reelProvider.reels[index];
              final isActive = index == _activeIndex;

              if (reel.type == 'video' && reel.scenes.isNotEmpty) {
                return VideoReelCard(
                  key: ValueKey('v_${reel.id}'),
                  reel: reel,
                  isSaved: reelProvider.isSaved(reel.id),
                  isActive: isActive,
                  onSave: () => reelProvider.toggleSave(reel.id),
                  onShare: () => Share.share('Check out this reel: ${reel.title} on EduReels!'),
                );
              }

              return ReelCard(
                key: ValueKey('r_${reel.id}'),
                reel: reel,
                isSaved: reelProvider.isSaved(reel.id),
                isActive: isActive,
                onSave: () => reelProvider.toggleSave(reel.id),
                onShare: () => Share.share('Check out this reel: ${reel.title} on EduReels!'),
              );
            },
          ),

          // Generating indicator
          if (reelProvider.isGenerating)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF667eea).withValues(alpha: 0.4), blurRadius: 12)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generating ${reelProvider.generatingDone}/${reelProvider.generatingTotal} reels...',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1a1a2e),
      highlightColor: const Color(0xFF2a2a4e),
      child: SafeArea(
        child: Stack(
          children: [
            // Background image placeholder
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),

            // Bottom-left: title and description skeleton
            Positioned(
              left: 20,
              right: 80,
              bottom: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60, height: 14,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 220, height: 20,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 280, height: 14,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200, height: 14,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
            ),

            // Right side: action buttons skeleton
            Positioned(
              right: 16,
              bottom: 140,
              child: Column(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),

            // Top center: subject chip skeleton
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 100, height: 28,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
