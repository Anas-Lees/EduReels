import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/group.dart';
import '../models/reel.dart';
import '../providers/group_provider.dart';
import '../providers/reel_provider.dart';
import '../widgets/reel_card.dart';
import '../widgets/video_reel_card.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<Reel> _reels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final reels = await context.read<GroupProvider>().getGroupReels(widget.group.id);
      setState(() {
        _reels = reels;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _reels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories, size: 64, color: const Color(0xFF667eea).withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No reels in this group yet',
                          style: TextStyle(color: Colors.white70, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Upload a lecture PDF and select this group',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
                    ],
                  ),
                )
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _reels.length,
                  onPageChanged: (index) {
                    reelProvider.trackView(_reels[index].id);
                  },
                  itemBuilder: (context, index) {
                    final reel = _reels[index];
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
