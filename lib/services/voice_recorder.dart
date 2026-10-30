// lib/services/voice_recorder.dart
//
// Records a voice note from the microphone.
//
//   final rec = VoiceRecorder();
//   await rec.start();                 // false if microphone access was refused
//   final voice = await rec.stop();    // null if it was shorter than 1 second
//   await rec.cancel();                // throw it away
//
// While recording, [elapsed] and [levels] (a rolling list of loudness values
// from 0 to 1, for the little wave) update the screen through notifyListeners.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'attachment_service.dart';

/// A finished recording, ready to be sent.
class RecordedVoice {
  final PickedAttachment attachment;
  final int seconds;
  const RecordedVoice({required this.attachment, required this.seconds});
}

class VoiceRecorder extends ChangeNotifier {
  VoiceRecorder({this.onLimit});

  /// Called once when the 5 minute limit is reached, so the screen can send.
  final VoidCallback? onLimit;

  static const Duration maxLength = Duration(minutes: 5);
  static const Duration minLength = Duration(seconds: 1);

  final AudioRecorder _rec = AudioRecorder();
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  StreamSubscription<Amplitude>? _ampSub;

  bool _recording = false;
  bool _busy = false;
  bool _limitFired = false;
  final List<double> _levels = [];
  String _ext = 'm4a';

  bool get isRecording => _recording;
  Duration get elapsed => _clock.elapsed;
  List<double> get levels => List.unmodifiable(_levels);

  /// Starts recording. Returns false if the student did not allow microphone
  /// access. Throws [UploadException] if recording could not start.
  Future<bool> start() async {
    if (_recording) return true;
    if (_busy) return false;
    _busy = true;

    Object? lastError;
    try {
      if (!await _rec.hasPermission()) return false;

      // Try the compact format first, then plain WAV if the device refuses it
      final encoders = kIsWeb
          ? [AudioEncoder.opus, AudioEncoder.wav]
          : [AudioEncoder.aacLc, AudioEncoder.wav];

      var started = false;
      for (final encoder in encoders) {
        try {
          final ext = switch (encoder) {
            AudioEncoder.wav => 'wav',
            AudioEncoder.opus => 'webm',
            _ => 'm4a',
          };

          var path = '';
          if (!kIsWeb) {
            final dir = await getTemporaryDirectory();
            path =
                '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
          }

          await _rec.start(
            RecordConfig(
              encoder: encoder,
              bitRate: 48000,
              sampleRate: encoder == AudioEncoder.wav ? 16000 : 44100,
              numChannels: 1,
            ),
            path: path,
          );
          _ext = ext;
          started = true;
          break;
        } catch (e) {
          lastError = e;
          debugPrint('VoiceRecorder: $encoder failed: $e');
        }
      }

      if (!started) throw lastError ?? StateError('recording did not start');

      _levels.clear();
      _limitFired = false;
      _clock
        ..reset()
        ..start();
      _recording = true;

      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((a) {
        // a.current is in decibels, about -60 (silence) to 0 (very loud)
        final level = ((a.current + 50) / 50).clamp(0.0, 1.0).toDouble();
        _levels.add(level);
        if (_levels.length > 60) _levels.removeAt(0);
      });

      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_limitFired && _clock.elapsed >= maxLength) {
          _limitFired = true;
          onLimit?.call();
        }
        notifyListeners();
      });

      notifyListeners();
      return true;
    } catch (e) {
      _reset();
      debugPrint('VoiceRecorder: could not start: $e');
      if (e is MissingPluginException) {
        throw const UploadException(
          'Voice recording is not loaded yet. Stop the app completely and run '
          'it again (a hot restart is not enough after adding a new package).',
        );
      }
      final detail = e.toString().replaceAll('\n', ' ');
      throw UploadException(
        kDebugMode
            ? 'Could not start recording: ${detail.length > 140 ? detail.substring(0, 140) : detail}'
            : 'Could not start recording.',
      );
    } finally {
      _busy = false;
    }
  }

  /// Stops and returns the recording. Returns null if it was too short.
  Future<RecordedVoice?> stop() async {
    if (!_recording) return null;

    final length = _clock.elapsed;
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {
      path = null;
    }
    _reset();

    if (path == null || path.isEmpty) {
      throw const UploadException('The recording failed. Please try again.');
    }
    if (length < minLength) return null;

    final bytes = await XFile(path).readAsBytes();
    final name = 'voice-${DateTime.now().millisecondsSinceEpoch}.$_ext';
    final picked = AttachmentService().validate(
      name: name,
      bytes: bytes,
      forceKind: 'audio',
    );

    final secs = length.inSeconds < 1
        ? 1
        : (length.inSeconds > 300 ? 300 : length.inSeconds);
    return RecordedVoice(attachment: picked, seconds: secs);
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    if (!_recording) return;
    try {
      await _rec.cancel();
    } catch (_) {
      // nothing to clean up
    }
    _reset();
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
    _clock
      ..stop()
      ..reset();
    _recording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    unawaited(_rec.dispose());
    super.dispose();
  }
}