// lib/services/call_service.dart
//
// Voice and video calls between friends (private chats only).
//
// The server (socket/calls.js) decides who may call whom and rings the other
// person; the audio and video go through Agora. This class:
//   - asks for the microphone / camera,
//   - starts a call (call:invite) and opens the call screen,
//   - listens for incoming calls and opens the incoming-call screen,
//   - opens the incoming-call screen when a "call" push is tapped.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/class_models.dart';
import '../screens/call_screen.dart';
import 'api_service.dart';
import 'class_socket.dart';
import 'navigation_service.dart';

enum CallKind { voice, video }

CallKind callKindFrom(String? s) => s == 'video' ? CallKind.video : CallKind.voice;

/// Who is calling whom, as the call screens need it.
class CallInfo {
  final String callId;
  final String classId;
  final String peerName;
  final CallKind kind;
  final bool isCaller;

  const CallInfo({
    required this.callId,
    required this.classId,
    required this.peerName,
    required this.kind,
    required this.isCaller,
  });
}

/// What Agora needs to put this phone into the call.
class CallJoin {
  final String appId;
  final String channel;
  final int uid;
  final String token;

  const CallJoin({
    required this.appId,
    required this.channel,
    required this.uid,
    required this.token,
  });

  factory CallJoin.fromAck(Map<String, dynamic> m) => CallJoin(
        appId: (m['appId'] ?? '') as String,
        channel: (m['channel'] ?? '') as String,
        uid: (m['uid'] as num).toInt(),
        token: (m['token'] ?? '') as String,
      );
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final _socket = ClassSocket();
  StreamSubscription<CallEvent>? _sub;

  /// The call this phone is in (or ringing for) right now. One at a time.
  String? _activeCallId;
  bool get busy => _activeCallId != null;

  void setActive(String? callId) => _activeCallId = callId;

  /// Calls work on the phone apps only.
  static bool get supported => !kIsWeb;

  /// Starts listening for incoming calls. Safe to call many times.
  Future<void> start() async {
    if (!supported) return;
    await _socket.connect();
    _sub ??= _socket.onCallEvent.listen(_onEvent);
  }

  void _onEvent(CallEvent e) {
    if (e.name != 'call:incoming') return;

    final callId = (e.data['callId'] ?? '') as String;
    if (callId.isEmpty) return;

    // Already on a call: tell them I am busy
    if (busy) {
      _socket.callRequest('call:decline', {'callId': callId});
      return;
    }

    final from = e.data['from'];
    final name = from is Map ? (from['name'] ?? 'Someone').toString() : 'Someone';

    _openIncoming(CallInfo(
      callId: callId,
      classId: (e.data['classId'] ?? '') as String,
      peerName: name,
      kind: callKindFrom(e.data['kind'] as String?),
      isCaller: false,
    ));
  }

  void _openIncoming(CallInfo info) {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) return;
    _activeCallId = info.callId;
    nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(info: info),
      ),
    );
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  /// Asks for the microphone (and camera for video). Returns a sentence to
  /// show if something was refused, or null when everything is allowed.
  Future<String?> ensurePermissions(CallKind kind) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mic.isPermanentlyDenied) await openAppSettings();
      return 'Allow the microphone in Settings to make calls.';
    }
    if (kind == CallKind.video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (cam.isPermanentlyDenied) await openAppSettings();
        return 'Allow the camera in Settings to make video calls.';
      }
    }
    return null;
  }

  static String errorText(String? code, String peerName) {
    switch (code) {
      case 'BUSY':
        return '$peerName is on another call.';
      case 'BUSY_SELF':
        return 'You are already on a call.';
      case 'LIMIT_REACHED':
        return "You have used today's call time. Try again tomorrow.";
      case 'NOT_CONFIGURED':
        return 'Calls are not set up yet.';
      case 'NOT_ALLOWED':
        return 'You can only call friends.';
      case 'RATE_LIMITED':
        return 'Too many call attempts. Wait a minute and try again.';
      case 'CALL_ENDED':
        return 'The call has ended.';
      case 'OFFLINE':
      case 'TIMEOUT':
        return 'No connection. Check your internet and try again.';
      default:
        return 'Could not start the call. Please try again.';
    }
  }

  // ── Calling out ────────────────────────────────────────────────────────────

  /// Rings the friend in [room]. Returns a sentence to show if the call could
  /// not start, or null when the call screen opened.
  Future<String?> startCall(BuildContext context, ClassRoom room, CallKind kind) async {
    if (!supported) return 'Calls work in the phone app.';
    if (busy) return 'You are already on a call.';

    final denied = await ensurePermissions(kind);
    if (denied != null) return denied;

    if (!await _socket.waitConnected()) return errorText('OFFLINE', room.name);

    final ack = await _socket.callRequest(
      'call:invite',
      {'classId': room.id, 'kind': kind == CallKind.video ? 'video' : 'voice'},
      timeout: const Duration(seconds: 12),
    );
    if (!ack.ok) return errorText(ack.error, room.name);

    final info = CallInfo(
      callId: (ack.data['callId'] ?? '') as String,
      classId: room.id,
      peerName: room.name,
      kind: kind,
      isCaller: true,
    );
    _activeCallId = info.callId;

    if (!context.mounted) {
      _socket.callRequest('call:cancel', {'callId': info.callId});
      _activeCallId = null;
      return null;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(info: info, join: CallJoin.fromAck(ack.data)),
      ),
    );
    return null;
  }

  // ── From a push notification ───────────────────────────────────────────────

  /// Opened the app by tapping an "incoming call" notification. Shows the
  /// answer screen if the call is still ringing, otherwise the chat.
  Future<void> openFromPush(String callId) async {
    if (!supported || callId.isEmpty || busy) return;
    try {
      final data = await ApiClient().get('/calls/$callId');
      final call = data['call'] as Map<String, dynamic>;
      final peer = call['peer'] as Map<String, dynamic>;

      if (call['status'] == 'ringing' && call['isCallee'] == true) {
        await start(); // make sure the live connection is coming up
        _openIncoming(CallInfo(
          callId: callId,
          classId: (call['classId'] ?? '') as String,
          peerName: (peer['name'] ?? 'Someone') as String,
          kind: callKindFrom(call['kind'] as String?),
          isCaller: false,
        ));
      }
    } catch (_) {
      // The call is gone or there is no connection: nothing to answer
    }
  }
}