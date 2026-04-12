import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/reel_provider.dart';
import '../widgets/reel_card.dart';
import '../widgets/video_reel_card.dart';

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
      return Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        body: _buildShimmerLoading(),
      );
    }

    if (reelProvider.reels.isEmpty && !reelProvider.isGenerating) {
      return Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories, size: 64, color: Color(0xFF667eea)),
              ),
              const SizedBox(height: 24),
              const Text('No reels yet!',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Upload a PDF to generate your first reels',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
            ],
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
                  onShare: () => Share.share('Check out this reel: ${reel.title} on EduReels!'),
                );
              }

              return ReelCard(
                reel: reel,
                isLiked: reelProvider.isLiked(reel.id),
                isSaved: reelProvider.isSaved(reel.id),
                onLike: () => reelProvider.toggleLike(reel.id),
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
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[700]!,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 32),
              Container(
                width: 200, height: 24,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 16),
              Container(
                width: 280, height: 16,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(height: 8),
              Container(
                width: 240, height: 16,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity, height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
