// lib/services/class_socket.dart
//
// The live (real-time) connection for the "Join a class" feature.
//
// - One shared connection for the whole app, using your normal login token.
// - Reconnects by itself. After a reconnect it re-joins every class room it
//   was in, and if the login token has expired it refreshes it first.
// - Screens and stores listen to the streams below instead of talking to
//   socket.io directly.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../models/class_models.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL EVENT / RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────

/// Class-level events: member:joined, member:pending, member:updated,
/// member:left, class:updated, class:approved, class:removed, class:archived.
class ClassEvent {
  final String name;
  final String classId;
  final Map<String, dynamic> data;
  const ClassEvent(this.name, this.classId, this.data);
}

class TypingEvent {
  final String classId;
  final String userId;
  final String name;
  final bool isTyping;
  const TypingEvent({
    required this.classId,
    required this.userId,
    required this.name,
    required this.isTyping,
  });
}

/// The server's answer to something we sent (chat message, anonymous post...).
class SocketAck {
  final bool ok;
  final String? error; // a code like RATE_LIMITED, MUTED, OFFLINE ...
  final Map<String, dynamic> data;

  const SocketAck({required this.ok, this.error, this.data = const {}});

  /// A sentence that is safe to show the student.
  String get errorText {
    switch (error) {
      case 'RATE_LIMITED':
        return 'You are sending too fast. Please slow down.';
      case 'MUTED':
        return 'A class admin has muted you.';
      case 'CHAT_LOCKED':
        return 'Only admins can send messages right now.';
      case 'NOT_A_MEMBER':
        return 'You are not a member of this class.';
      case 'CLASS_ARCHIVED':
        return 'This class has been archived.';
      case 'SESSION_CLOSED':
        return 'This anonymous session has closed.';
      case 'BLOCKED':
        return 'You can no longer post in this session.';
      case 'INVALID_TEXT':
        return 'That message is empty or too long.';
      case 'OFFLINE':
        return 'You are offline. Reconnecting...';
      case 'TIMEOUT':
        return 'The server took too long to answer. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  THE CONNECTION
// ─────────────────────────────────────────────────────────────────────────────

class ClassSocket with WidgetsBindingObserver {
  ClassSocket._();
  static final ClassSocket _instance = ClassSocket._();
  factory ClassSocket() => _instance;

  sio.Socket? _socket;
  bool _starting = false;
  bool _recovering = false;

  /// true once we are watching the app going to the background and back
  bool _observing = false;

  /// true while the connection is closed because the app is in the background
  bool _paused = false;

  /// The student the current connection belongs to (from the login token)
  String _socketUser = '';

  /// Classes whose live updates we want. Re-joined after every reconnect.
  final Set<String> _rooms = {};

  /// true while the connection is up. Use it to show an "offline" banner.
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  // ── Streams ────────────────────────────────────────────────────────────────
  final _messageNew = StreamController<ChatMessage>.broadcast();
  final _messageDeleted = StreamController<Map<String, dynamic>>.broadcast();
  final _messagePinned = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _anonOpened = StreamController<AnonSession>.broadcast();
  final _anonClosed = StreamController<AnonSession>.broadcast();
  final _anonNew = StreamController<AnonPost>.broadcast();
  final _anonHidden = StreamController<Map<String, dynamic>>.broadcast();
  final _classEvents = StreamController<ClassEvent>.broadcast();

  Stream<ChatMessage> get onMessageNew => _messageNew.stream;

  /// { id, classId }
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeleted.stream;

  /// { id, classId, pinned }
  Stream<Map<String, dynamic>> get onMessagePinned => _messagePinned.stream;

  Stream<TypingEvent> get onTyping => _typing.stream;
  Stream<AnonSession> get onAnonOpened => _anonOpened.stream;
  Stream<AnonSession> get onAnonClosed => _anonClosed.stream;
  Stream<AnonPost> get onAnonNew => _anonNew.stream;

  /// { id, sessionId, classId }
  Stream<Map<String, dynamic>> get onAnonHidden => _anonHidden.stream;

  Stream<ClassEvent> get onClassEvent => _classEvents.stream;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// The server address without the "/api" part.
  String get _origin => ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is List && v.isNotEmpty) v = v.first;
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  // ── Connect / disconnect ───────────────────────────────────────────────────

  /// The student id inside a login token, or '' if it can't be read. Used only
  /// to notice that a DIFFERENT student logged in; the server still checks the
  /// token itself.
  String _userIdFromToken(String? token) {
    if (token == null) return '';
    final parts = token.split('.');
    if (parts.length != 3) return '';
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload);
      return map is Map ? (map['id'] ?? '').toString() : '';
    } catch (_) {
      return '';
    }
  }

  /// Safe to call many times. Does nothing if already connected for the same
  /// student. If a different student has logged in since (or nobody is logged
  /// in any more), the old connection is dropped first.
  Future<void> connect() async {
    if (_starting) return;
    _starting = true;

    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }

    try {
      final token = await TokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        if (_socket != null) disconnect(); // logged out
        return;
      }

      final user = _userIdFromToken(token);
      if (_socket != null) {
        if (user.isEmpty || user == _socketUser) return; // same student
        disconnect(); // a different student logged in
      }

      _socketUser = user;
      _build(token);
    } finally {
      _starting = false;
    }
  }

  /// Call this when the user logs out.
  void disconnect() {
    _paused = false;
    _socketUser = '';
    _rooms.clear();
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  /// When the app goes to the background, close the live connection. The
  /// server then knows the student is not looking at the class and sends push
  /// notifications instead. When the app comes back, reconnect and rejoin the
  /// classes that were open.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_socket != null) {
        _paused = true;
        _socket?.dispose();
        _socket = null;
        connected.value = false;
      }
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      unawaited(connect());
    }
  }

  void _build(String token) {
    _socket?.dispose();

    final options = sio.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .disableAutoConnect()
        .build();

    // Always open a brand-new connection, so an earlier student's login can
    // never be reused by the library.
    options['forceNew'] = true;

    final s = sio.io(_origin, options);
    _socket = s;

    s.onConnect((_) {
      connected.value = true;
      // Back online: rejoin every class we were watching
      for (final id in _rooms) {
        s.emit('class:join', {'classId': id});
      }
    });

    s.onDisconnect((_) => connected.value = false);

    s.onConnectError((err) {
      connected.value = false;
      final text = err.toString();
      if (text.contains('AUTH_EXPIRED') || text.contains('AUTH_INVALID')) {
        _recoverFromAuthError();
      }
    });

    // ── Chat ─────────────────────────────────────────────────────────────────
    _listen(s, 'message:new', (d) => _messageNew.add(ChatMessage.fromMap(_asMap(d))));
    _listen(s, 'message:deleted', (d) => _messageDeleted.add(_asMap(d)));
    _listen(s, 'message:pinned', (d) => _messagePinned.add(_asMap(d)));
    _listen(s, 'typing', (d) {
      final m = _asMap(d);
      _typing.add(TypingEvent(
        classId: (m['classId'] ?? '') as String,
        userId: (m['userId'] ?? '') as String,
        name: (m['name'] ?? 'Student') as String,
        isTyping: m['isTyping'] == true,
      ));
    });

    // ── Anonymous sessions ───────────────────────────────────────────────────
    _listen(s, 'anon:opened', (d) => _anonOpened.add(AnonSession.fromMap(_asMap(d))));
    _listen(s, 'anon:closed', (d) => _anonClosed.add(AnonSession.fromMap(_asMap(d))));
    _listen(s, 'anon:new', (d) => _anonNew.add(AnonPost.fromMap(_asMap(d))));
    _listen(s, 'anon:hidden', (d) => _anonHidden.add(_asMap(d)));

    // ── Class and member events ──────────────────────────────────────────────
    for (final name in const [
      'member:joined',
      'member:pending',
      'member:updated',
      'member:left',
      'class:updated',
      'class:approved',
      'class:removed',
      'class:archived',
    ]) {
      _listen(s, name, (d) {
        final m = _asMap(d);
        _classEvents.add(ClassEvent(name, (m['classId'] ?? '') as String, m));
      });
    }

    s.connect();
  }

  /// Registers a listener that can never crash the app, even if the server
  /// sends something we don't expect.
  void _listen(sio.Socket s, String event, void Function(dynamic) handler) {
    s.on(event, (data) {
      try {
        handler(data);
      } catch (e) {
        debugPrint('ClassSocket "$event" ignored: $e');
      }
    });
  }

  /// The login token ran out. Refresh it (ApiClient does this automatically
  /// when a normal request gets a 401), then connect again with the new one.
  Future<void> _recoverFromAuthError() async {
    if (_recovering) return;
    _recovering = true;
    try {
      _socket?.dispose();
      _socket = null;

      try {
        await ApiClient().get('/auth/me'); // refreshes the token if needed
      } on UnauthorizedException {
        return; // logged out for real: stay disconnected
      } on ApiException {
        // Server asleep or offline: try again shortly
        await Future.delayed(const Duration(seconds: 5));
      }

      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return;
      _build(token);
    } finally {
      _recovering = false;
    }
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  Future<SocketAck> _emit(String event, Map<String, dynamic> payload) {
    final s = _socket;
    if (s == null || !s.connected) {
      return Future.value(const SocketAck(ok: false, error: 'OFFLINE'));
    }

    final done = Completer<SocketAck>();
    s.emitWithAck(event, payload, ack: (res) {
      if (done.isCompleted) return;
      final m = _asMap(res);
      done.complete(SocketAck(
        ok: m['ok'] == true,
        error: m['error'] as String?,
        data: m,
      ));
    });

    return done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => const SocketAck(ok: false, error: 'TIMEOUT'),
    );
  }

  /// Start receiving live updates for a class. Call when a class screen opens.
  Future<SocketAck> joinRoom(String classId) {
    _rooms.add(classId);
    return _emit('class:join', {'classId': classId});
  }

  /// Stop receiving live updates. Call when the class screen closes.
  void leaveRoom(String classId) {
    _rooms.remove(classId);
    _socket?.emit('class:leave', {'classId': classId});
  }

  /// [clientId] is any unique string. It comes back on the "message:new"
  /// event so the screen can swap its "sending..." bubble for the real one.
  Future<SocketAck> sendMessage({
    required String classId,
    required String text,
    required String clientId,
    String? replyTo,
  }) {
    return _emit('message:send', {
      'classId': classId,
      'text': text,
      'clientId': clientId,
      'replyTo': ?replyTo,
    });
  }

  Future<SocketAck> deleteMessage(String messageId) {
    return _emit('message:delete', {'messageId': messageId});
  }

  /// Fire and forget: no answer is needed.
  void sendTyping(String classId, bool isTyping) {
    final s = _socket;
    if (s == null || !s.connected) return;
    s.emit('typing', {'classId': classId, 'isTyping': isTyping});
  }

  Future<SocketAck> sendAnonPost({
    required String classId,
    required String sessionId,
    required String text,
  }) {
    return _emit('anon:send', {
      'classId': classId,
      'sessionId': sessionId,
      'text': text,
    });
  }
}