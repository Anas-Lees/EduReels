import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel.dart';
import '../providers/reel_provider.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
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
  late final PageController _pageController;
  late final List<Reel> _sortedReels;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();

    // Sort reels by page number ascending, then by creation order (stable)
    _sortedReels = List<Reel>.from(widget.reels)
      ..sort((a, b) {
        final byPage = a.pageNumber.compareTo(b.pageNumber);
        if (byPage != 0) return byPage;
        return a.createdAt.compareTo(b.createdAt);
      });

    // Find first unsolved reel to resume from
    final provider = context.read<ReelProvider>();
    int startIndex = _sortedReels.indexWhere((r) => !provider.isSaved(r.id));
    if (startIndex == -1) startIndex = 0; // all solved → start from beginning

    _activeIndex = startIndex;
    _pageController = PageController(initialPage: startIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sortedReels.isNotEmpty) {
        provider.trackView(_sortedReels[startIndex].id);
        _preloadImages(startIndex);
        TtsService.instance.setActiveOwner(_sortedReels[startIndex].id);
      }
    });
  }

  void _preloadImages(int currentIndex) {
    for (int i = currentIndex + 1;
        i <= currentIndex + 5 && i < _sortedReels.length;
        i++) {
      final reel = _sortedReels[i];
      if (reel.type == 'video' && reel.scenes.isNotEmpty) {
        for (final scene in reel.scenes) {
          try {
            precacheImage(
                CachedNetworkImageProvider(scene.imageUrl), context);
          } catch (_) {}
        }
      } else {
        for (final slide in reel.slides) {
          try {
            precacheImage(
                CachedNetworkImageProvider(slide.imageUrl), context);
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
    final solvedCount =
        _sortedReels.where((r) => reelProvider.isSaved(r.id)).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cleanPdfName(widget.pdfName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (_sortedReels.isNotEmpty)
              Text(
                '$solvedCount of ${_sortedReels.length} solved',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
      ),
      body: _sortedReels.isEmpty
          ? _buildEmpty()
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _sortedReels.length,
                  onPageChanged: (index) {
                    setState(() => _activeIndex = index);
                    reelProvider.trackView(_sortedReels[index].id);
                    _preloadImages(index);
                    TtsService.instance
                        .setActiveOwner(_sortedReels[index].id);
                  },
                  itemBuilder: (context, index) {
                    final reel = _sortedReels[index];
                    final isActive = index == _activeIndex;

                    if (reel.type == 'video' && reel.scenes.isNotEmpty) {
                      return VideoReelCard(
                        key: ValueKey('v_${reel.id}'),
                        reel: reel,
                        isSaved: reelProvider.isSaved(reel.id),
                        isActive: isActive,
                        onSave: () => reelProvider.toggleSave(reel.id),
                        onShare: () => Share.share(
                            'Check out this reel: ${reel.title} on EduReels!'),
                      );
                    }

                    return ReelCard(
                      key: ValueKey('r_${reel.id}'),
                      reel: reel,
                      isSaved: reelProvider.isSaved(reel.id),
                      isActive: isActive,
                      onSave: () => reelProvider.toggleSave(reel.id),
                      onShare: () => Share.share(
                          'Check out this reel: ${reel.title} on EduReels!'),
                    );
                  },
                ),
                // Thin top progress bar for overall "solved" progress
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: LinearProgressIndicator(
                        value: solvedCount / _sortedReels.length,
                        minHeight: 2,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.success,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_rounded,
              size: 72, color: AppTheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No reels yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          const Text(
            'Upload a PDF to generate reels for this group.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
