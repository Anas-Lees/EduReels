import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Centralised Text-to-Speech service. Reads reel narration/slide text
/// aloud with a single shared voice so only one reel speaks at a time.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _muted = false;
  String? _currentOwner;

  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48); // slightly slower — more natural
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() => isSpeaking.value = true);
      _tts.setCompletionHandler(() => isSpeaking.value = false);
      _tts.setCancelHandler(() => isSpeaking.value = false);
      _tts.setErrorHandler((msg) => isSpeaking.value = false);
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Speak [text]. If another caller is currently speaking, it is stopped
  /// first. [owner] is any identifier (e.g. reel id) so a screen can know
  /// if the current speech belongs to it.
  Future<void> speak(String text, {String? owner}) async {
    if (_muted || text.trim().isEmpty) return;
    await _init();
    try {
      await _tts.stop();
      _currentOwner = owner;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      isSpeaking.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking.value = false;
    _currentOwner = null;
  }

  /// Stop only if the current speech belongs to [owner].
  Future<void> stopIfOwner(String owner) async {
    if (_currentOwner == owner) {
      await stop();
    }
  }

  void toggleMute() {
    _muted = !_muted;
    isMuted.value = _muted;
    if (_muted) stop();
  }

  bool get muted => _muted;
}
