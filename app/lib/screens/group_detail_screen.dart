import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/reel.dart';
import '../providers/group_provider.dart';
import '../providers/reel_provider.dart';
import '../theme/app_theme.dart';
import 'pdf_reels_screen.dart';

String cleanPdfName(String name) {
  return name
      .replaceAll('.pdf', '')
      .replaceAll('.PDF', '')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ')
      .trim();
}

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<Reel> _reels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final reels = await context
          .read<GroupProvider>()
          .getGroupReels(widget.group.id);
      if (mounted) {
        setState(() {
          _reels = reels;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load reels. Tap to retry.';
        });
      }
    }
  }

  List<MapEntry<String, List<Reel>>> _groupByPdf() {
    final Map<String, List<Reel>> grouped = {};
    for (final reel in _reels) {
      final key = reel.pdfName.isNotEmpty ? reel.pdfName : 'Unknown PDF';
      grouped.putIfAbsent(key, () => []).add(reel);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    }
    return grouped.entries.toList();
  }

  String _pageRangeInfo(List<Reel> reels) {
    final pages = reels
        .map((r) => r.pageNumber)
        .where((p) => p > 0)
        .toSet()
        .toList()
      ..sort();
    if (pages.isEmpty) return '';
    if (pages.length == 1) return 'Page ${pages.first}';
    return 'Pages ${pages.first}-${pages.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          widget.group.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
              ),
            )
          : _error != null
              ? _buildError()
              : _reels.isEmpty
                  ? _buildEmpty()
                  : _buildPdfList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _loading = true;
            _error = null;
          });
          _loadReels();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppTheme.danger),
              ),
              const SizedBox(height: 18),
              Text(
                _error!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap to retry',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                size: 56, color: AppTheme.primary),
          ),
          const SizedBox(height: 18),
          const Text(
            'No PDFs in this group yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a lecture PDF and assign it to this group.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfList() {
    final pdfGroups = _groupByPdf();
    final reelProvider = context.watch<ReelProvider>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: pdfGroups.length,
      itemBuilder: (context, index) {
        final entry = pdfGroups[index];
        final pdfName = entry.key;
        final reels = entry.value;
        final pageRange = _pageRangeInfo(reels);
        final solvedCount =
            reels.where((r) => reelProvider.isSolved(r.id)).length;
        final progress =
            reels.isEmpty ? 0.0 : solvedCount / reels.length;
        final gradient = AppTheme
            .reelGradients[index % AppTheme.reelGradients.length];

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfReelsScreen(
                  pdfName: pdfName,
                  reels: reels,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        boxShadow: AppTheme.glowShadow(gradient[0]),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanPdfName(pdfName),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 13,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${reels.length} reels',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (pageRange.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 12,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pageRange,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: progress,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$solvedCount/${reels.length}',
                      style: TextStyle(
                        color: progress >= 1.0
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
