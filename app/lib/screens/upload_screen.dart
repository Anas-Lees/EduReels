import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/reel_provider.dart';
import '../providers/group_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  String? _selectedFile;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String _selectedStyle = 'realistic';
  String? _selectedGroupId;
  final _explanationController = TextEditingController();

  late final AnimationController _pulseController;

  static const _styles = [
    {'id': 'realistic', 'name': 'Realistic', 'icon': Icons.camera_alt},
    {'id': 'anime', 'name': 'Anime', 'icon': Icons.auto_awesome},
    {'id': 'watercolor', 'name': 'Watercolor', 'icon': Icons.brush},
    {'id': '3d', 'name': '3D Render', 'icon': Icons.view_in_ar},
    {'id': 'comic', 'name': 'Comic', 'icon': Icons.burst_mode},
    {'id': 'minimalist', 'name': 'Minimal', 'icon': Icons.crop_square},
    {'id': 'scifi', 'name': 'Sci-Fi', 'icon': Icons.rocket_launch},
  ];

  static const _styleColors = {
    'realistic': [Color(0xFF667eea), Color(0xFF764ba2)],
    'anime': [Color(0xFFf093fb), Color(0xFFf5576c)],
    'watercolor': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    '3d': [Color(0xFFfa709a), Color(0xFFfee140)],
    'comic': [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
    'minimalist': [Color(0xFF89f7fe), Color(0xFF66a6ff)],
    'scifi': [Color(0xFF0c0c1d), Color(0xFF1a1a4e)],
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
    });
  }

  @override
  void dispose() {
    _explanationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.single.path;
        _selectedFileName = result.files.single.name;
        _selectedFileBytes = result.files.single.bytes;
      });
    }
  }

  void _upload() {
    if ((_selectedFile == null && _selectedFileBytes == null) ||
        _selectedGroupId == null) return;

    // Use cleaned PDF name as subject
    final subject = _selectedFileName
            ?.replaceAll('.pdf', '')
            .replaceAll('.PDF', '')
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .trim() ??
        'General';

    // Find the group name for the snackbar
    final groups = context.read<GroupProvider>().groups;
    final groupName = groups.where((g) => g.id == _selectedGroupId).map((g) => g.name).firstOrNull ?? 'group';

    // Start streaming upload (runs in background via provider)
    context.read<ReelProvider>().uploadPdfStreaming(
          _selectedFile,
          _selectedFileName!,
          subject,
          fileBytes: _selectedFileBytes,
          style: _selectedStyle,
          groupId: _selectedGroupId,
          explanationStyle: _explanationController.text.isNotEmpty ? _explanationController.text : null,
        );

    // Show a brief non-blocking snackbar and reset form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating reels in "$groupName"...'),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    // Reset form so user can navigate away
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileBytes = null;
      _explanationController.clear();
      _selectedGroupId = null;
      _selectedStyle = 'realistic';
    });
  }

  bool get _hasFile => _selectedFile != null || _selectedFileBytes != null;

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        title: const Text('Create Reels',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload area
            _buildUploadArea(reelProvider),
            const SizedBox(height: 28),

            // Style picker
            _buildSectionLabel('Visual Style'),
            const SizedBox(height: 4),
            Text(
              'AI-generated backgrounds for each slide',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildStylePicker(),
            const SizedBox(height: 28),

            // Group picker
            _buildSectionLabel('Group'),
            const SizedBox(height: 12),
            _buildGroupPicker(),
            const SizedBox(height: 28),

            // Explanation style
            _buildSectionLabel('Explanation Style (Optional)'),
            const SizedBox(height: 4),
            Text(
              'e.g. "Explain in terms of football" or "Use cooking analogies"',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _explanationController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'How would you like concepts explained?',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF667eea)),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Upload status
            if (reelProvider.uploading || reelProvider.uploadStatus != null)
              _buildUploadStatus(reelProvider),

            // Error
            if (reelProvider.error != null) _buildError(reelProvider),

            // Generate button
            _buildGenerateButton(reelProvider),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'AI generates reels for every page of your PDF',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildUploadArea(ReelProvider reelProvider) {
    return GestureDetector(
      onTap: reelProvider.uploading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: _hasFile
              ? LinearGradient(
                  colors: [
                    const Color(0xFF667eea).withValues(alpha: 0.15),
                    const Color(0xFF764ba2).withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: _hasFile ? null : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hasFile
                ? const Color(0xFF667eea).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: _hasFile ? 2 : 1.5,
          ),
        ),
        child: _hasFile
            ? Row(
                children: [
                  const SizedBox(width: 24),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, size: 28, color: Color(0xFF667eea)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to change file',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.swap_horiz_rounded, color: Colors.white.withValues(alpha: 0.25), size: 22),
                  const SizedBox(width: 20),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_upload_rounded, size: 32, color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tap to select PDF',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF up to 50MB',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStylePicker() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final style = _styles[index];
          final id = style['id'] as String;
          final isSelected = _selectedStyle == id;
          final colors = _styleColors[id] ?? [Colors.grey, Colors.grey];

          return GestureDetector(
            onTap: () => setState(() => _selectedStyle = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? colors
                      : [
                          colors[0].withValues(alpha: 0.3),
                          colors[1].withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    style['icon'] as IconData,
                    color: Colors.white,
                    size: isSelected ? 32 : 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    style['name'] as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupPicker() {
    final groupProvider = context.watch<GroupProvider>();
    final groups = groupProvider.groups;

    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.orange.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create a group first from the Groups tab to upload PDFs.',
                style: TextStyle(color: Colors.orange.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedGroupId,
          isExpanded: true,
          dropdownColor: const Color(0xFF1a1a2e),
          hint: Text('Select a group',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
          items: groups.map((g) => DropdownMenuItem<String?>(
                value: g.id,
                child: Text(g.name, style: const TextStyle(color: Colors.white)),
              )).toList(),
          onChanged: (value) => setState(() => _selectedGroupId = value),
        ),
      ),
    );
  }

  Widget _buildUploadStatus(ReelProvider reelProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (reelProvider.isGenerating && reelProvider.generatingTotal > 0) ...[
            // Animated progress bar
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: reelProvider.generatingTotal > 0
                    ? reelProvider.generatingDone / reelProvider.generatingTotal
                    : 0.0,
              ),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF667eea)),
                    minHeight: 8,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ] else if (reelProvider.totalPages > 0 && reelProvider.uploading) ...[
            // Page processing progress bar
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: reelProvider.totalPages > 0
                    ? reelProvider.currentPage / reelProvider.totalPages
                    : 0.0,
              ),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF43e97b)),
                    minHeight: 6,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Page ${reelProvider.currentPage} of ${reelProvider.totalPages}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ] else if (reelProvider.uploading) ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF667eea),
                    size: 36,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Text(
            reelProvider.uploadStatus ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (reelProvider.isGenerating) ...[
            const SizedBox(height: 8),
            Text(
              'AI images will load as you view each reel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(ReelProvider reelProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reelProvider.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(ReelProvider reelProvider) {
    final canUpload = _hasFile &&
        _selectedGroupId != null &&
        !reelProvider.uploading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: canUpload
              ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)])
              : null,
          color: canUpload ? null : Colors.grey[850],
        ),
        child: ElevatedButton(
          onPressed: canUpload ? _upload : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 20,
                  color: canUpload ? Colors.white : Colors.white38),
              const SizedBox(width: 8),
              Text(
                'Generate Reels',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: canUpload ? Colors.white : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
