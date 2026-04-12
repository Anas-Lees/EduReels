import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reel_provider.dart';
import '../widgets/reel_card.dart';
import '../widgets/video_reel_card.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelProvider>().loadReels();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    if (reelProvider.loading && reelProvider.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading reels...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (reelProvider.reels.isEmpty && !reelProvider.isGenerating) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories,
                size: 80,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              const Text(
                'No reels yet!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a PDF to generate your first reels',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reelProvider.reels.length,
            onPageChanged: (index) {
              reelProvider.trackView(reelProvider.reels[index].id);
            },
            itemBuilder: (context, index) {
              final reel = reelProvider.reels[index];

              if (reel.type == 'video' && reel.scenes.isNotEmpty) {
                return VideoReelCard(
                  reel: reel,
                  isLiked: reelProvider.isLiked(reel.id),
                  isSaved: reelProvider.isSaved(reel.id),
                  onLike: () => reelProvider.toggleLike(reel.id),
                  onSave: () => reelProvider.toggleSave(reel.id),
                  onShare: () {
                    Share.share(
                        'Check out this reel: ${reel.title} on EduReels!');
                  },
                );
              }

              return ReelCard(
                reel: reel,
                isLiked: reelProvider.isLiked(reel.id),
                isSaved: reelProvider.isSaved(reel.id),
                onLike: () => reelProvider.toggleLike(reel.id),
                onSave: () => reelProvider.toggleSave(reel.id),
                onShare: () {
                  Share.share(
                      'Check out this reel: ${reel.title} on EduReels!');
                },
              );
            },
          ),

          // Generating indicator
          if (reelProvider.isGenerating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generating ${reelProvider.generatingDone}/${reelProvider.generatingTotal} reels...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
}
