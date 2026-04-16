import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reel.dart';
import '../services/api_service.dart';

/// Manages the global reel state — upload streaming, "solved" (mark-as-seen)
/// tracking, and caching. "Solved" replaces the old like+save concept: the
/// user simply marks a reel as done/understood, and we resume from the next
/// unsolved reel the next time they open the same PDF.
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
  final Set<String> _solvedReels = {};
  bool _prefsLoaded = false;

  static const _solvedKey = 'solved_reels_v1';

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

  bool isSaved(String reelId) => _solvedReels.contains(reelId);
  bool isSolved(String reelId) => _solvedReels.contains(reelId);

  ReelProvider() {
    _loadSolvedFromPrefs();
  }

  Future<void> _loadSolvedFromPrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_solvedKey) ?? [];
      _solvedReels.addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistSolved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_solvedKey, _solvedReels.toList());
    } catch (_) {}
  }

  Future<void> loadReels() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _reels = await ApiService.getReels();
      _loading = false;
      notifyListeners();
    } catch (_) {
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
    } catch (_) {
      _myReelsError = 'Failed to load your reels';
      _loadingMyReels = false;
      notifyListeners();
    }
  }

  Future<void> uploadPdfStreaming(
    String? filePath,
    String fileName,
    String subject, {
    Uint8List? fileBytes,
    String style = 'realistic',
    String? groupId,
    String? explanationStyle,
  }) async {
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
        filePath,
        fileName,
        subject,
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
            _reels.insert(0, reel);
            _myReels.insert(0, reel);
            _generatingDone++;
            _uploadStatus =
                'Generated $_generatingDone reels so far…';
            notifyListeners();
            break;

          case 'done':
            _uploading = false;
            _isGenerating = false;
            _uploadStatus =
                '${event.data['totalReels'] ?? _generatingDone} reels ready!';
            notifyListeners();
            break;

          case 'page_start':
            _currentPage = event.data['pageNumber'] ?? 0;
            _uploadStatus =
                'Page $_currentPage of $_totalPages — ${event.data['conceptCount'] ?? 0} concepts';
            notifyListeners();
            break;

          case 'page_done':
            _currentPage = event.data['pageNumber'] ?? _currentPage;
            _uploadStatus = 'Page $_currentPage done';
            notifyListeners();
            break;

          case 'error':
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

  Future<void> uploadPdf(
      String? filePath, String fileName, String subject,
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
      _uploadStatus = '${result['reelCount']} reels ready!';
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

  /// Toggle the "solved" state for a reel. Persisted locally so that the
  /// user can resume from the next unsolved reel on return.
  Future<void> toggleSave(String reelId) async {
    final wasSolved = _solvedReels.contains(reelId);
    if (wasSolved) {
      _solvedReels.remove(reelId);
    } else {
      _solvedReels.add(reelId);
    }
    notifyListeners();
    await _persistSolved();

    // Best-effort sync with the server save endpoint. Ignore failures —
    // the local state is the source of truth for resume behaviour.
    try {
      await ApiService.toggleSave(reelId);
    } catch (_) {}
  }

  void trackView(String reelId) {
    ApiService.trackView(reelId);
  }
}
