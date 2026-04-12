import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/reel_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  final _subjectController = TextEditingController();
  String? _selectedFile;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String _selectedStyle = 'realistic';

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

  final List<String> _subjects = [
    'Math', 'Physics', 'Chemistry', 'Biology',
    'Computer Science', 'History', 'Literature',
    'Economics', 'Psychology', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _subjectController.dispose();
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
        _subjectController.text.isEmpty) return;

    context.read<ReelProvider>().uploadPdfStreaming(
          _selectedFile,
          _selectedFileName!,
          _subjectController.text,
          fileBytes: _selectedFileBytes,
          style: _selectedStyle,
        );
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

            // Subject picker
            _buildSectionLabel('Subject'),
            const SizedBox(height: 12),
            _buildSubjectPicker(),
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
            const SizedBox(height: 32),

            // Upload status
            if (reelProvider.uploading || reelProvider.uploadStatus != null)
              _buildUploadStatus(reelProvider),

            // Error
            if (reelProvider.error != null) _buildError(reelProvider),

            // Generate button
            _buildGenerateButton(reelProvider),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'AI generates 5-8 reels with unique visual backgrounds',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildUploadArea(ReelProvider reelProvider) {
    return GestureDetector(
      onTap: reelProvider.uploading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          gradient: _hasFile
              ? LinearGradient(
                  colors: [
                    const Color(0xFF667eea).withValues(alpha: 0.2),
                    const Color(0xFF764ba2).withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: _hasFile ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hasFile
                ? const Color(0xFF667eea).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasFile ? Icons.picture_as_pdf_rounded : Icons.cloud_upload_rounded,
              size: 48,
              color: _hasFile ? const Color(0xFF667eea) : Colors.white30,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFileName ?? 'Tap to select PDF',
              style: TextStyle(
                color: _hasFile ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: _hasFile ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (!_hasFile) ...[
              const SizedBox(height: 4),
              Text(
                'PDF up to 50MB',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _subjects.map((subject) {
        final isSelected = _subjectController.text == subject;
        return GestureDetector(
          onTap: () => setState(() => _subjectController.text = subject),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF667eea)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF667eea)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              subject,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
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
        _subjectController.text.isNotEmpty &&
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
