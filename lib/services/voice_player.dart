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
      if (_playing) {
        _loading = false;
        _loadTimer?.cancel();
      }
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
  Timer? _loadTimer;

  /// A voice note recorded in a web browser is a .webm (Opus) file, and many
  /// Android phones cannot play that. Cloudinary can hand the same recording
  /// out as an .mp3 just by changing the ending of the link, which every
  /// phone and browser can play. Links that are already fine are left alone.
  static String playableUrl(String url) {
    final m = RegExp(
      r'^(.*/video/upload/.+)\.(webm|ogg|oga|opus)(\?.*)?$',
      caseSensitive: false,
    ).firstMatch(url);
    if (m == null) return url;
    return '${m.group(1)}.mp3${m.group(3) ?? ''}';
  }

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

    final source = playableUrl(url);

    try {
      await _player.stop();
      await _player.play(UrlSource(source));
    } catch (e) {
      debugPrint('VoicePlayer: could not play $source: $e');
      _loadTimer?.cancel();
      _loading = false;
      _playing = false;
      _url = null;
      notifyListeners();
      rethrow;
    }

    // Some phones never report an error for a file they cannot play, they just
    // stay "loading". After 20 seconds, give the button back.
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 20), () {
      if (_loading && !_playing) {
        debugPrint('VoicePlayer: still loading after 20 s: $source');
        _loading = false;
        _url = null;
        notifyListeners();
      }
    });
  }

  /// Jump to a point in the current voice note (0 = start, 1 = end).
  Future<void> seekTo(String url, double fraction) async {
    if (_url != url || _duration == Duration.zero) return;
    final f = fraction.clamp(0.0, 1.0);
    await _player.seek(_duration * f);
  }

  Future<void> stop() async {
    if (_url == null) return;
    _loadTimer?.cancel();
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