// lib/screens/call_screen.dart
//
// CallScreen          – the call itself (voice or video), for both people
// IncomingCallScreen  – "X is calling you", with Answer and Decline

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/call_service.dart';
import '../services/class_socket.dart';
import '../widgets/snackBar.dart';

const _bgTop = Color(0xFF0D47A1);
const _bgBottom = Color(0xFF06142E);

String _clock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _endedText(String? reason) {
  switch (reason) {
    case 'declined':
      return 'Call declined';
    case 'missed':
      return 'No answer';
    case 'cancelled':
      return 'Call cancelled';
    case 'time_limit':
      return 'Call time limit reached';
    case 'answered_elsewhere':
      return 'Answered on another device';
    default:
      return 'Call ended';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.size = 110});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 72.0 : 58.0;
    final bg = color ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final fg = color != null ? Colors.white : (active ? _bgBottom : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: fg, size: big ? 32 : 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  THE CALL
// ═════════════════════════════════════════════════════════════════════════════

enum _Phase { ringing, connecting, connected, ended }

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.info, required this.join});

  final CallInfo info;
  final CallJoin join;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _socket = ClassSocket();

  RtcEngine? _engine;
  StreamSubscription<CallEvent>? _sub;
  Timer? _ticker;

  // The caller rings first; the person who answered is already connecting
  late _Phase _phase = widget.info.isCaller ? _Phase.ringing : _Phase.connecting;
  String _endedMessage = '';
  int? _remoteUid;
  int _seconds = 0;

  bool _muted = false;
  late bool _speaker = widget.info.kind == CallKind.video;
  bool _cameraOff = false;
  bool _closing = false;

  bool get _video => widget.info.kind == CallKind.video;

  @override
  void initState() {
    super.initState();
    CallService.instance.setActive(widget.info.callId);
    _sub = _socket.onCallEvent.listen(_onSocket);
    _startEngine();
  }

  // ── Server events ──────────────────────────────────────────────────────────

  void _onSocket(CallEvent e) {
    if ((e.data['callId'] ?? '') != widget.info.callId) return;

    if (e.name == 'call:accepted') {
      if (_phase == _Phase.ringing && mounted) setState(() => _phase = _Phase.connecting);
    } else if (e.name == 'call:ended') {
      _finish(_endedText(e.data['reason'] as String?));
    }
  }

  // ── Agora ──────────────────────────────────────────────────────────────────

  Future<void> _startEngine() async {
    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(RtcEngineContext(
        appId: widget.join.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            _phase = _Phase.connected;
          });
          _startTimer();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          // The other phone left the call
          _hangUp(text: 'Call ended');
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora error: $err $msg');
        },
      ));

      await engine.enableAudio();
      if (_video) {
        await engine.enableVideo();
        await engine.startPreview();
      }
      await engine.setEnableSpeakerphone(_speaker);

      await engine.joinChannel(
        token: widget.join.token,
        channelId: widget.join.channel,
        uid: widget.join.uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: _video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: _video,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Call could not start: $e');
      _hangUp(text: 'Could not connect the call');
    }
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  // ── Ending ─────────────────────────────────────────────────────────────────

  /// I pressed hang up (or the other phone left).
  Future<void> _hangUp({String? text}) async {
    if (_closing) return;
    final ringing = _phase == _Phase.ringing;
    _socket.callRequest(
      ringing && widget.info.isCaller ? 'call:cancel' : 'call:end',
      {'callId': widget.info.callId},
    );
    await _finish(text ?? (ringing ? 'Call cancelled' : 'Call ended'));
  }

  /// Leaves the call, shows a short message, and closes the screen.
  Future<void> _finish(String text) async {
    if (_closing) return;
    _closing = true;
    _ticker?.cancel();
    await _releaseEngine();
    CallService.instance.setActive(null);

    if (!mounted) return;
    setState(() {
      _phase = _Phase.ended;
      _endedMessage = text;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    if (!_closing) {
      // Closed some other way: make sure the other person is not left ringing
      _socket.callRequest(
        _phase == _Phase.ringing && widget.info.isCaller ? 'call:cancel' : 'call:end',
        {'callId': widget.info.callId},
      );
    }
    CallService.instance.setActive(null);
    _releaseEngine();
    super.dispose();
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine?.muteLocalAudioStream(_muted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speaker = !_speaker);
    await _engine?.setEnableSpeakerphone(_speaker);
  }

  Future<void> _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    await _engine?.muteLocalVideoStream(_cameraOff);
  }

  Future<void> _flipCamera() async {
    await _engine?.switchCamera();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  String get _statusText {
    switch (_phase) {
      case _Phase.ringing:
        return 'Calling…';
      case _Phase.connecting:
        return 'Connecting…';
      case _Phase.connected:
        return _clock(_seconds);
      case _Phase.ended:
        return _endedMessage;
    }
  }

  Widget _videoLayer() {
    final engine = _engine;
    if (!_video || engine == null) return const SizedBox.shrink();

    return Stack(
      children: [
        if (_remoteUid != null)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.join.channel),
              ),
            ),
          ),
        if (!_cameraOff)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            width: 110,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showVideo = _video && _remoteUid != null && _phase != _Phase.ended;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: Stack(
            children: [
              _videoLayer(),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    if (!showVideo) ...[
                      const SizedBox(height: 40),
                      _Avatar(widget.info.peerName),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      widget.info.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                    const Spacer(),
                    if (_phase != _Phase.ended)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _RoundButton(
                                  icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                  label: _muted ? 'Unmute' : 'Mute',
                                  active: _muted,
                                  onTap: _toggleMute,
                                ),
                                _RoundButton(
                                  icon: _speaker
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_down_rounded,
                                  label: 'Speaker',
                                  active: _speaker,
                                  onTap: _toggleSpeaker,
                                ),
                                if (_video) ...[
                                  _RoundButton(
                                    icon: _cameraOff
                                        ? Icons.videocam_off_rounded
                                        : Icons.videocam_rounded,
                                    label: _cameraOff ? 'Camera on' : 'Camera off',
                                    active: _cameraOff,
                                    onTap: _toggleCamera,
                                  ),
                                  _RoundButton(
                                    icon: Icons.cameraswitch_rounded,
                                    label: 'Flip',
                                    onTap: _cameraOff ? null : _flipCamera,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 28),
                            _RoundButton(
                              icon: Icons.call_end_rounded,
                              label: 'End',
                              color: Colors.red,
                              big: true,
                              onTap: () => _hangUp(),
                            ),
                          ],
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  INCOMING CALL
// ═════════════════════════════════════════════════════════════════════════════

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.info});

  final CallInfo info;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _socket = ClassSocket();
  StreamSubscription<CallEvent>? _sub;
  Timer? _ring;
  Timer? _giveUp;

  bool _answering = false;
  bool _done = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    CallService.instance.setActive(widget.info.callId);
    _sub = _socket.onCallEvent.listen((e) {
      if ((e.data['callId'] ?? '') != widget.info.callId) return;
      if (e.name == 'call:ended') _close(_endedText(e.data['reason'] as String?));
    });

    // Buzz and beep until answered
    _buzz();
    _ring = Timer.periodic(const Duration(milliseconds: 1800), (_) => _buzz());

    // The server stops ringing after 45 seconds; this is only a safety net
    _giveUp = Timer(const Duration(seconds: 55), () => _close('Missed call'));
  }

  void _buzz() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ring?.cancel();
    _giveUp?.cancel();
    if (!_answering) CallService.instance.setActive(null);
    super.dispose();
  }

  Future<void> _close(String text) async {
    if (_done) return;
    _done = true;
    _ring?.cancel();
    if (!_answering) CallService.instance.setActive(null);
    if (!mounted) return;
    setState(() => _message = text);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _decline() async {
    if (_done || _answering) return;
    _socket.callRequest('call:decline', {'callId': widget.info.callId});
    await _close('Call declined');
  }

  Future<void> _answer() async {
    if (_done || _answering) return;
    setState(() => _answering = true);
    _ring?.cancel();

    final denied = await CallService.instance.ensurePermissions(widget.info.kind);
    if (denied != null) {
      if (mounted) AppSnackBar.auto(context, denied);
      _socket.callRequest('call:decline', {'callId': widget.info.callId});
      _answering = false;
      await _close('Call declined');
      return;
    }

    if (!await _socket.waitConnected()) {
      if (mounted) AppSnackBar.auto(context, CallService.errorText('OFFLINE', widget.info.peerName));
      _answering = false;
      await _close('No connection');
      return;
    }

    final ack = await _socket.callRequest(
      'call:accept',
      {'callId': widget.info.callId},
      timeout: const Duration(seconds: 12),
    );

    if (!ack.ok) {
      if (mounted) {
        AppSnackBar.auto(context, CallService.errorText(ack.error, widget.info.peerName));
      }
      _answering = false;
      await _close(ack.error == 'CALL_ENDED' ? 'Call ended' : 'Could not answer');
      return;
    }

    if (!mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          info: CallInfo(
            callId: widget.info.callId,
            classId: widget.info.classId,
            peerName: widget.info.peerName,
            kind: widget.info.kind,
            isCaller: false,
          ),
          join: CallJoin.fromAck(ack.data),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.info.kind == CallKind.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 90),
                Text(
                  video ? 'Incoming video call' : 'Incoming voice call',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 34),
                _Avatar(widget.info.peerName, size: 130),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.info.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _message.isNotEmpty
                      ? _message
                      : (_answering ? 'Connecting…' : 'SchoolLife'),
                  style: const TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const Spacer(),
                if (_message.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundButton(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          color: Colors.red,
                          big: true,
                          onTap: _answering ? null : _decline,
                        ),
                        _RoundButton(
                          icon: video ? Icons.videocam_rounded : Icons.call_rounded,
                          label: 'Answer',
                          color: const Color(0xFF2E9E5B),
                          big: true,
                          onTap: _answering ? null : _answer,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}