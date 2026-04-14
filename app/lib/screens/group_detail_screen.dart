import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/reel.dart';
import '../providers/group_provider.dart';
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
      final reels = await context.read<GroupProvider>().getGroupReels(widget.group.id);
      if (mounted) {
        setState(() {
          _reels = reels;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load reels. Tap to retry.';
        });
      }
    }
  }

  /// Group reels by pdfName and return a sorted list of entries
  List<MapEntry<String, List<Reel>>> _groupByPdf() {
    final Map<String, List<Reel>> grouped = {};
    for (final reel in _reels) {
      final key = reel.pdfName.isNotEmpty ? reel.pdfName : 'Unknown PDF';
      grouped.putIfAbsent(key, () => []).add(reel);
    }
    // Sort each group by pageNumber
    for (final list in grouped.values) {
      list.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    }
    return grouped.entries.toList();
  }

  String _pageRangeInfo(List<Reel> reels) {
    final pages = reels.map((r) => r.pageNumber).where((p) => p > 0).toSet().toList()..sort();
    if (pages.isEmpty) return '';
    if (pages.length == 1) return 'Page ${pages.first}';
    return 'Pages ${pages.first}-${pages.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _error != null
              ? Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() { _loading = true; _error = null; });
                      _loadReels();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : _reels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories, size: 64, color: const Color(0xFF667eea).withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No PDFs in this group yet',
                              style: TextStyle(color: Colors.white70, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Upload a lecture PDF and select this group',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
                        ],
                      ),
                    )
                  : _buildPdfList(),
    );
  }

  Widget _buildPdfList() {
    final pdfGroups = _groupByPdf();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pdfGroups.length,
      itemBuilder: (context, index) {
        final entry = pdfGroups[index];
        final pdfName = entry.key;
        final reels = entry.value;
        final pageRange = _pageRangeInfo(reels);

        return GestureDetector(
          onTap: () {
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFf093fb).withValues(alpha: 0.2),
                        const Color(0xFF667eea).withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFf093fb), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanPdfName(pdfName),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 14, color: const Color(0xFF667eea).withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text('${reels.length} reels',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                          if (pageRange.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.menu_book_rounded, size: 13, color: Colors.white.withValues(alpha: 0.25)),
                            const SizedBox(width: 4),
                            Text(pageRange,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.15), size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}
