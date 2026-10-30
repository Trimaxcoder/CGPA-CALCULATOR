// lib/services/voice_player.dart
//
// Plays voice notes. There is one player for the whole app, so starting a new
// voice note stops the one that was playing, like in WhatsApp.
//
// Voice bubbles listen to [VoicePlayer.instance] to show play / pause and the
// progress bar.

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class VoicePlayer extends ChangeNotifier {
  VoicePlayer._() {
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      if (_playing) _loading = false;
      notifyListeners();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _duration = d;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      _playing = false;
      _finished = true;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  static final VoicePlayer instance = VoicePlayer._();

  final AudioPlayer _player = AudioPlayer();

  String? _url;
  bool _playing = false;
  bool _loading = false;
  bool _finished = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool isCurrent(String url) => _url == url;
  bool isPlaying(String url) => _url == url && _playing;
  bool isLoading(String url) => _url == url && _loading;
  Duration positionOf(String url) => _url == url ? _position : Duration.zero;

  /// The real length once the file has loaded, otherwise [fallback].
  Duration durationOf(String url, Duration fallback) =>
      _url == url && _duration > Duration.zero ? _duration : fallback;

  /// Play, pause or resume this voice note. Throws if it can not be played.
  Future<void> toggle(String url, {Duration? knownDuration}) async {
    if (_url == url && !_finished) {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    _url = url;
    _finished = false;
    _position = Duration.zero;
    _duration = knownDuration ?? Duration.zero;
    _loading = true;
    notifyListeners();

    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      _loading = false;
      _playing = false;
      _url = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Jump to a point in the current voice note (0 = start, 1 = end).
  Future<void> seekTo(String url, double fraction) async {
    if (_url != url || _duration == Duration.zero) return;
    final f = fraction.clamp(0.0, 1.0);
    await _player.seek(_duration * f);
  }

  Future<void> stop() async {
    if (_url == null) return;
    _url = null;
    _playing = false;
    _loading = false;
    _position = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
    } catch (_) {
      // already stopped
    }
  }
}