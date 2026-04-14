import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../services/api_service.dart';

class ReelProvider extends ChangeNotifier {
  List<Reel> _reels = [];
  List<Reel> _myReels = [];
  bool _loading = false;
  bool _loadingMyReels = false;
  bool _uploading = false;
  bool _isGenerating = false;
  int _generatingTotal = 0;
  int _generatingDone = 0;
  int _currentPage = 0;
  int _totalPages = 0;
  String? _error;
  String? _myReelsError;
  String? _uploadStatus;
  final Set<String> _likedReels = {};
  final Set<String> _savedReels = {};

  List<Reel> get reels => _reels;
  List<Reel> get myReels => _myReels;
  bool get loading => _loading;
  bool get loadingMyReels => _loadingMyReels;
  bool get uploading => _uploading;
  bool get isGenerating => _isGenerating;
  int get generatingTotal => _generatingTotal;
  int get generatingDone => _generatingDone;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String? get error => _error;
  String? get myReelsError => _myReelsError;
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
    _loadingMyReels = true;
    _myReelsError = null;
    notifyListeners();

    try {
      _myReels = await ApiService.getMyReels();
      _loadingMyReels = false;
      notifyListeners();
    } catch (e) {
      _myReelsError = 'Failed to load your reels';
      _loadingMyReels = false;
      notifyListeners();
    }
  }

  // Streaming upload - reels appear one by one
  Future<void> uploadPdfStreaming(String? filePath, String fileName,
      String subject, {Uint8List? fileBytes, String style = 'realistic', String? groupId, String? explanationStyle}) async {
    _uploading = true;
    _isGenerating = false;
    _generatingTotal = 0;
    _generatingDone = 0;
    _currentPage = 0;
    _totalPages = 0;
    _uploadStatus = 'Uploading PDF...';
    _error = null;
    notifyListeners();

    try {
      final stream = ApiService.uploadPdfStream(
        filePath, fileName, subject,
        fileBytes: fileBytes,
        style: style,
        groupId: groupId,
        explanationStyle: explanationStyle,
      );

      await for (final event in stream) {
        switch (event.event) {
          case 'start':
            _isGenerating = true;
            _totalPages = event.data['totalPages'] ?? 0;
            _uploadStatus = 'Processing $_totalPages pages...';
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
                '${event.data['totalReels'] ?? _generatingDone} reels created!';
            notifyListeners();
            break;

          case 'page_start':
            _currentPage = event.data['pageNumber'] ?? 0;
            _uploadStatus = 'Page $_currentPage of $_totalPages — ${event.data['conceptCount'] ?? 0} concepts found';
            notifyListeners();
            break;

          case 'page_done':
            _currentPage = event.data['pageNumber'] ?? _currentPage;
            _uploadStatus = 'Page $_currentPage done';
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
    // Optimistic update — instant UI
    final wasLiked = _likedReels.contains(reelId);
    if (wasLiked) {
      _likedReels.remove(reelId);
    } else {
      _likedReels.add(reelId);
    }
    notifyListeners();

    try {
      final liked = await ApiService.toggleLike(reelId);
      // Sync with server truth
      if (liked) {
        _likedReels.add(reelId);
      } else {
        _likedReels.remove(reelId);
      }
      notifyListeners();
    } catch (e) {
      // Revert on failure
      if (wasLiked) {
        _likedReels.add(reelId);
      } else {
        _likedReels.remove(reelId);
      }
      notifyListeners();
    }
  }

  Future<void> toggleSave(String reelId) async {
    // Optimistic update — instant UI
    final wasSaved = _savedReels.contains(reelId);
    if (wasSaved) {
      _savedReels.remove(reelId);
    } else {
      _savedReels.add(reelId);
    }
    notifyListeners();

    try {
      final saved = await ApiService.toggleSave(reelId);
      if (saved) {
        _savedReels.add(reelId);
      } else {
        _savedReels.remove(reelId);
      }
      notifyListeners();
    } catch (e) {
      // Revert on failure
      if (wasSaved) {
        _savedReels.add(reelId);
      } else {
        _savedReels.remove(reelId);
      }
      notifyListeners();
    }
  }

  void trackView(String reelId) {
    ApiService.trackView(reelId);
  }
}
