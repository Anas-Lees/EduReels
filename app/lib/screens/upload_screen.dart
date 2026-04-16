import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/reel_provider.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';

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
    {'id': 'realistic', 'name': 'Realistic', 'icon': Icons.camera_alt_rounded},
    {'id': 'anime', 'name': 'Anime', 'icon': Icons.auto_awesome_rounded},
    {'id': 'watercolor', 'name': 'Watercolor', 'icon': Icons.brush_rounded},
    {'id': '3d', 'name': '3D Render', 'icon': Icons.view_in_ar_rounded},
    {'id': 'comic', 'name': 'Comic', 'icon': Icons.burst_mode_rounded},
    {'id': 'minimalist', 'name': 'Minimal', 'icon': Icons.crop_square_rounded},
    {'id': 'scifi', 'name': 'Sci-Fi', 'icon': Icons.rocket_launch_rounded},
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
    HapticFeedback.selectionClick();
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

    HapticFeedback.mediumImpact();

    final subject = _selectedFileName
            ?.replaceAll('.pdf', '')
            .replaceAll('.PDF', '')
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .trim() ??
        'General';

    final groups = context.read<GroupProvider>().groups;
    final groupName = groups
            .where((g) => g.id == _selectedGroupId)
            .map((g) => g.name)
            .firstOrNull ??
        'group';

    context.read<ReelProvider>().uploadPdfStreaming(
          _selectedFile,
          _selectedFileName!,
          subject,
          fileBytes: _selectedFileBytes,
          style: _selectedStyle,
          groupId: _selectedGroupId,
          explanationStyle: _explanationController.text.isNotEmpty
              ? _explanationController.text
              : null,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Generating reels in "$groupName"…'),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );

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
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(),
              const SizedBox(height: 24),
              _buildUploadArea(reelProvider),
              const SizedBox(height: 28),
              _buildSectionLabel('Visual style',
                  subtitle: 'Pick a look for AI-generated backgrounds'),
              const SizedBox(height: 12),
              _buildStylePicker(),
              const SizedBox(height: 28),
              _buildSectionLabel('Save into group',
                  subtitle: 'Reels are added to this group'),
              const SizedBox(height: 12),
              _buildGroupPicker(),
              const SizedBox(height: 28),
              _buildSectionLabel('Explain like…',
                  subtitle:
                      'Optional — e.g. "Explain using cooking analogies"'),
              const SizedBox(height: 12),
              TextField(
                controller: _explanationController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'How would you like concepts explained?',
                ),
              ),
              const SizedBox(height: 28),
              if (reelProvider.uploading || reelProvider.uploadStatus != null)
                _buildUploadStatus(reelProvider),
              if (reelProvider.error != null) _buildError(reelProvider),
              _buildGenerateButton(reelProvider),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'AI reels · narrated · page-by-page',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'Create reels',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Drop a PDF, pick a style, and we\'ll turn it into scrollable study reels.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadArea(ReelProvider reelProvider) {
    return GestureDetector(
      onTap: reelProvider.uploading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _hasFile
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.22),
                    AppTheme.accent.withValues(alpha: 0.18),
                  ],
                )
              : null,
          color: _hasFile ? null : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _hasFile
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: _hasFile ? 1.5 : 1,
          ),
          boxShadow: _hasFile
              ? AppTheme.glowShadow(AppTheme.primary)
              : null,
        ),
        child: _hasFile ? _buildFileRow() : _buildDropRow(),
      ),
    );
  }

  Widget _buildFileRow() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.glowShadow(AppTheme.accent),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              size: 28, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedFileName ?? '',
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
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppTheme.success),
                  const SizedBox(width: 4),
                  const Text(
                    'Ready — tap to change',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.swap_horiz_rounded, color: AppTheme.textMuted),
      ],
    );
  }

  Widget _buildDropRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(Icons.cloud_upload_rounded,
                size: 38, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to pick a PDF',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Works best with lectures, notes, slides',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStylePicker() {
    return SizedBox(
      height: 118,
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
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedStyle = id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 94,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? colors
                      : [
                          colors[0].withValues(alpha: 0.25),
                          colors[1].withValues(alpha: 0.25),
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.05),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(style['icon'] as IconData,
                      color: Colors.white,
                      size: isSelected ? 30 : 24),
                  const SizedBox(height: 8),
                  Text(
                    style['name'] as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 20,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
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
          color: AppTheme.accentWarm.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.accentWarm.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.accentWarm, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Create a group first, then upload PDFs into it.',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedGroupId,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceHigh,
          hint: const Text('Select a group',
              style: TextStyle(color: AppTheme.textMuted)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary),
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          items: groups
              .map((g) => DropdownMenuItem<String?>(
                    value: g.id,
                    child: Row(
                      children: [
                        const Icon(Icons.folder_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 10),
                        Text(g.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _selectedGroupId = value);
          },
        ),
      ),
    );
  }

  Widget _buildUploadStatus(ReelProvider reelProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (reelProvider.isGenerating &&
              reelProvider.generatingTotal > 0) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: reelProvider.generatingTotal > 0
                    ? reelProvider.generatingDone /
                        reelProvider.generatingTotal
                    : 0.0,
              ),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (reelProvider.totalPages > 0 &&
              reelProvider.uploading) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: reelProvider.totalPages > 0
                    ? reelProvider.currentPage / reelProvider.totalPages
                    : 0.0,
              ),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.success),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Page ${reelProvider.currentPage} of ${reelProvider.totalPages}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ] else if (reelProvider.uploading) ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.12),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            reelProvider.uploadStatus ?? '',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (reelProvider.isGenerating) ...[
            const SizedBox(height: 6),
            const Text(
              'Reels unlock as each page is processed',
              style: TextStyle(
                color: AppTheme.textMuted,
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
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reelProvider.error!,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
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
      height: 58,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: canUpload ? AppTheme.primaryGradient : null,
          color: canUpload ? null : AppTheme.surfaceHigh,
          boxShadow:
              canUpload ? AppTheme.glowShadow(AppTheme.primary) : null,
        ),
        child: ElevatedButton(
          onPressed: canUpload ? _upload : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppTheme.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 20,
                  color:
                      canUpload ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                'Generate reels',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: canUpload ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
