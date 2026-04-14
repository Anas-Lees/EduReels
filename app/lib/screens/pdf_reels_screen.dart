import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel.dart';
import '../providers/reel_provider.dart';
import '../widgets/reel_card.dart';
import '../widgets/video_reel_card.dart';
import 'group_detail_screen.dart' show cleanPdfName;

class PdfReelsScreen extends StatefulWidget {
  final String pdfName;
  final List<Reel> reels;

  const PdfReelsScreen({
    super.key,
    required this.pdfName,
    required this.reels,
  });

  @override
  State<PdfReelsScreen> createState() => _PdfReelsScreenState();
}

class _PdfReelsScreenState extends State<PdfReelsScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.reels.isNotEmpty) {
        final provider = context.read<ReelProvider>();
        provider.trackView(widget.reels[0].id);
        _preloadImages(0);
      }
    });
  }

  void _preloadImages(int currentIndex) {
    for (int i = currentIndex + 1; i <= currentIndex + 5 && i < widget.reels.length; i++) {
      final reel = widget.reels[i];
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          cleanPdfName(widget.pdfName),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
      ),
      body: widget.reels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories, size: 64, color: const Color(0xFF667eea).withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No reels available', style: TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.reels.length,
              onPageChanged: (index) {
                reelProvider.trackView(widget.reels[index].id);
                _preloadImages(index);
              },
              itemBuilder: (context, index) {
                final reel = widget.reels[index];

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
    );
  }
}
