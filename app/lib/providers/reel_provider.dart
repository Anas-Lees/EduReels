import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../services/api_service.dart';

class ReelProvider extends ChangeNotifier {
  List<Reel> _reels = [];
  List<Reel> _myReels = [];
  bool _loading = false;
  bool _uploading = false;
  bool _isGenerating = false;
  int _generatingTotal = 0;
  int _generatingDone = 0;
  String? _error;
  String? _uploadStatus;
  final Set<String> _likedReels = {};
  final Set<String> _savedReels = {};

  List<Reel> get reels => _reels;
  List<Reel> get myReels => _myReels;
  bool get loading => _loading;
  bool get uploading => _uploading;
  bool get isGenerating => _isGenerating;
  int get generatingTotal => _generatingTotal;
  int get generatingDone => _generatingDone;
  String? get error => _error;
  String? get uploadStatus => _uploadStatus;

  bool isLiked(String reelId) => _likedReels.contains(reelId);
  bool isSaved(String reelId) => _savedReels.contains(reelId);

  Future<void> loadReels() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _reels = await ApiService.getReels();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load reels';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyReels() async {
    try {
      _myReels = await ApiService.getMyReels();
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  // Streaming upload - reels appear one by one
  Future<void> uploadPdfStreaming(String? filePath, String fileName,
      String subject, {Uint8List? fileBytes}) async {
    _uploading = true;
    _isGenerating = false;
    _generatingTotal = 0;
    _generatingDone = 0;
    _uploadStatus = 'Uploading PDF...';
    _error = null;
    notifyListeners();

    try {
      final stream = ApiService.uploadPdfStream(
        filePath, fileName, subject,
        fileBytes: fileBytes,
      );

      await for (final event in stream) {
        switch (event.event) {
          case 'start':
            _isGenerating = true;
            _generatingTotal = event.data['totalConcepts'] ?? 0;
            _uploadStatus = 'Generating reel 1 of $_generatingTotal...';
            notifyListeners();
            break;

          case 'reel':
            final reel = Reel.fromJson(event.data);
            _reels.insert(0, reel); // Add to top of feed
            _myReels.insert(0, reel);
            _generatingDone++;
            _uploadStatus =
                'Generated $_generatingDone of $_generatingTotal reels';
            notifyListeners();
            break;

          case 'done':
            _uploading = false;
            _isGenerating = false;
            _uploadStatus =
                '${event.data['reelCount']} reels created!';
            notifyListeners();
            break;

          case 'error':
            // Log but continue - don't stop for individual reel errors
            break;
        }
      }
    } catch (e) {
      _error = e.toString();
      _uploadStatus = null;
      _uploading = false;
      _isGenerating = false;
      notifyListeners();
    }
  }

  // Original bulk upload (fallback)
  Future<void> uploadPdf(String? filePath, String fileName, String subject,
      {Uint8List? fileBytes}) async {
    _uploading = true;
    _uploadStatus = 'Uploading PDF...';
    _error = null;
    notifyListeners();

    try {
      _uploadStatus = 'AI is generating reels...';
      notifyListeners();

      final result = await ApiService.uploadPdf(filePath, fileName, subject,
          fileBytes: fileBytes);
      _uploadStatus = '${result['reelCount']} reels created!';
      _uploading = false;
      notifyListeners();

      await loadReels();
      await loadMyReels();
    } catch (e) {
      _error = e.toString();
      _uploadStatus = null;
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String reelId) async {
    try {
      final liked = await ApiService.toggleLike(reelId);
      if (liked) {
        _likedReels.add(reelId);
      } else {
        _likedReels.remove(reelId);
      }
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> toggleSave(String reelId) async {
    try {
      final saved = await ApiService.toggleSave(reelId);
      if (saved) {
        _savedReels.add(reelId);
      } else {
        _savedReels.remove(reelId);
      }
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  void trackView(String reelId) {
    ApiService.trackView(reelId);
  }
}
