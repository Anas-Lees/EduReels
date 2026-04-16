import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Centralised Text-to-Speech. Only one owner can be speaking at a time.
/// This version is race-safe:
///  - All speak/stop operations go through a single queued controller so
///    rapid swipes never interleave half-started utterances.
///  - Ownership is checked BEFORE committing the next speak, so a stale
///    speak() (e.g. from a neighbour card that was just built but never
///    became visible) is simply ignored.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _muted = false;

  /// Single-flight serialization for speak/stop. Each call chains onto
  /// the previous one so we never have two in-flight TTS operations.
  Future<void> _pending = Future.value();

  /// Identifier of whatever visible widget is *currently allowed* to speak.
  /// Set via [setActiveOwner] from the host (usually the PageView's
  /// onPageChanged). Any speak() whose owner does not match is dropped.
  String? _activeOwner;
  String? get activeOwner => _activeOwner;

  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<String?> currentOwner = ValueNotifier(null);

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // Fire-and-forget so stop() isn't blocked by a running utterance.
      await _tts.awaitSpeakCompletion(false);

      _tts.setStartHandler(() => isSpeaking.value = true);
      _tts.setCompletionHandler(() => isSpeaking.value = false);
      _tts.setCancelHandler(() => isSpeaking.value = false);
      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        isSpeaking.value = false;
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Announce which owner is now the visible/active one. Any in-flight or
  /// queued speech belonging to a different owner will be cancelled.
  Future<void> setActiveOwner(String? owner) async {
    if (_activeOwner == owner) return;
    _activeOwner = owner;
    currentOwner.value = owner;
    // Stop whatever is speaking since the context changed.
    await _enqueue(() async {
      try {
        await _tts.stop();
      } catch (_) {}
      isSpeaking.value = false;
    });
  }

  /// Speak [text]. The call is dropped silently unless [owner] is null or
  /// equals the currently active owner. This prevents neighbour-card
  /// builds from speaking over the visible card.
  Future<void> speak(String text, {String? owner}) async {
    if (_muted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (owner != null && _activeOwner != null && owner != _activeOwner) {
      return; // not the visible card — ignore
    }
    await _init();
    await _enqueue(() async {
      // Re-check ownership at dequeue time (state might have changed).
      if (owner != null && _activeOwner != null && owner != _activeOwner) {
        return;
      }
      if (_muted) return;
      try {
        await _tts.stop();
        // Small yield so the underlying engine actually flushes the stop
        // before we start a new utterance. Without this the Android TTS
        // engine sometimes ignores the stop and overlaps two utterances.
        await Future.delayed(const Duration(milliseconds: 40));
        await _tts.speak(trimmed);
      } catch (e) {
        debugPrint('TTS speak error: $e');
        isSpeaking.value = false;
      }
    });
  }

  Future<void> stop() async {
    await _enqueue(() async {
      try {
        await _tts.stop();
      } catch (_) {}
      isSpeaking.value = false;
    });
  }

  /// Stop only if the current owner matches [owner].
  Future<void> stopIfOwner(String owner) async {
    if (_activeOwner == owner) {
      await stop();
    }
  }

  void toggleMute() {
    _muted = !_muted;
    isMuted.value = _muted;
    if (_muted) stop();
  }

  bool get muted => _muted;

  /// Serialize tts operations so they never interleave.
  Future<void> _enqueue(Future<void> Function() task) {
    final next = _pending.then((_) => task()).catchError((_) {});
    _pending = next;
    return next;
  }
}
