import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/reel_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _subjectController = TextEditingController();
  String? _selectedFile;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  final List<String> _subjects = [
    'Math',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'History',
    'Literature',
    'Economics',
    'Psychology',
    'Other',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
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
        );
  }

  @override
  Widget build(BuildContext context) {
    final reelProvider = context.watch<ReelProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('Upload PDF'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload area
            GestureDetector(
              onTap: reelProvider.uploading ? null : _pickFile,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      (_selectedFile != null || _selectedFileBytes != null)
                          ? Icons.picture_as_pdf
                          : Icons.cloud_upload_outlined,
                      size: 56,
                      color: (_selectedFile != null || _selectedFileBytes != null)
                          ? const Color(0xFF667eea)
                          : Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFileName ?? 'Tap to select PDF',
                      style: TextStyle(
                        color: (_selectedFile != null || _selectedFileBytes != null)
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 16,
                        fontWeight: (_selectedFile != null || _selectedFileBytes != null)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (_selectedFile == null && _selectedFileBytes == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Max 10MB',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Subject picker
            const Text(
              'Subject',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjects.map((subject) {
                final isSelected = _subjectController.text == subject;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _subjectController.text = subject),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF667eea)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF667eea)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      subject,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Upload status
            if (reelProvider.uploading || reelProvider.uploadStatus != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (reelProvider.isGenerating &&
                        reelProvider.generatingTotal > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: reelProvider.generatingTotal > 0
                              ? reelProvider.generatingDone /
                                  reelProvider.generatingTotal
                              : 0.0,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF667eea)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (reelProvider.uploading) ...[
                      const CircularProgressIndicator(
                        color: Color(0xFF667eea),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      reelProvider.uploadStatus ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Error
            if (reelProvider.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reelProvider.error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedFile != null || _selectedFileBytes != null) &&
                        _subjectController.text.isNotEmpty &&
                        !reelProvider.uploading
                    ? _upload
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Generate Reels',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'AI will create 5-8 educational reels from your PDF',
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
}
