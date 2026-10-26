// lib/stores/class_chat_store.dart
//
// The state of ONE open class space: chat messages, pinned messages, the open
// anonymous session, who is typing, and the class settings.
//
// A screen creates one of these when it opens and disposes it when it closes:
//
//   final store = ClassChatStore(classId);
//   store.init();        // connects, joins the live room, loads the first page
//   ...
//   store.dispose();     // leaves the room
//
// Messages you send appear instantly (status "sending"), then switch to the
// real message when the server confirms. If sending fails, the message stays
// in the list as "failed" so the student can retry or discard it.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/class_models.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';

class ClassChatStore extends ChangeNotifier {
  ClassChatStore(this.classId, {ClassRoom? initialRoom}) : _room = initialRoom;

  final String classId;
  final _service = ClassService();
  final _socket = ClassSocket();
  final _random = Random();

  // ── State ──────────────────────────────────────────────────────────────────
  ClassRoom? _room;
  AnonSession? _activeSession;
  List<ChatMessage> _pinned = [];
  final List<ChatMessage> _messages = []; // oldest first
  final Map<String, String> _failReasons = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _removed = false;
  bool _disposed = false;

  String _myId = '';
  String _myName = 'You';

  // typing (other people)
  final Map<String, String> _typingNames = {}; // userId -> name
  final Map<String, Timer> _typingTimers = {};

  // typing (me)
  bool _iAmTyping = false;
  Timer? _stopTypingTimer;

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _wasOnline = false;

  // ── Read-only view for the screen ──────────────────────────────────────────
  ClassRoom? get room => _room;
  AnonSession? get activeSession => _activeSession;
  List<ChatMessage> get pinned => List.unmodifiable(_pinned);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// true after an admin removed me from the class: the screen should close.
  bool get removed => _removed;

  /// false while the live connection is down: show an "offline" banner.
  bool get online => _socket.connected.value;

  List<String> get typingNames => _typingNames.values.toList();

  /// Is this message mine? (Messages still sending or failed are always mine.)
  bool isMine(ChatMessage m) =>
      m.sendState != SendState.sent ||
      (_myId.isNotEmpty && m.senderId == _myId);

  /// Why a failed message failed, in words the student can read.
  String? failReason(String messageId) => _failReasons[messageId];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  START / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _socket.connect();
    _wasOnline = _socket.connected.value;
    _socket.connected.addListener(_onConnectionChanged);

    _subs
      ..add(_socket.onMessageNew.listen(_onNew))
      ..add(_socket.onMessageDeleted.listen(_onDeleted))
      ..add(_socket.onMessagePinned.listen(_onPinned))
      ..add(_socket.onTyping.listen(_onTyping))
      ..add(_socket.onAnonOpened.listen(_onAnonOpened))
      ..add(_socket.onAnonClosed.listen(_onAnonClosed))
      ..add(_socket.onClassEvent.listen(_onClassEvent));

    // Join the live room first so nothing is missed while the page loads.
    // If we are offline right now, ClassSocket joins as soon as it connects.
    unawaited(_socket.joinRoom(classId));

    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    userStoppedTyping();
    for (final s in _subs) {
      s.cancel();
    }
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _stopTypingTimer?.cancel();
    _socket.connected.removeListener(_onConnectionChanged);
    _socket.leaveRoom(classId);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOADING
  // ══════════════════════════════════════════════════════════════════════════

  /// First load, or "Try again" after an error.
  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();

    // Run the three requests at the same time
    final detailsF = _service.details(classId)..ignore();
    final pageF = _service.messages(classId)..ignore();
    final meF = _loadMe();

    try {
      final details = await detailsF;
      final page = await pageF;
      await meF;

      _room = details.room;
      _activeSession = details.activeSession;
      _pinned = details.pinned;
      _hasMore = page.hasMore;
      _merge(page.messages);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Who am I? Needed to put my messages on the right side.
  Future<void> _loadMe() async {
    if (_myId.isNotEmpty) return;
    try {
      final me = await AuthService().getMe();
      _myId = (me['_id'] ?? me['id'] ?? '').toString();
      final profile = me['profile'];
      if (profile is Map) {
        final name = (profile['name'] ?? '').toString().trim();
        if (name.isNotEmpty) _myName = name;
      }
    } catch (_) {
      // Not fatal: _myId is also learned from the first message we send
    }
  }

  /// Loads the next older page when the student scrolls to the top.
  Future<void> loadOlder() async {
    if (_loadingMore || !_hasMore) return;

    ChatMessage? oldest;
    for (final m in _messages) {
      if (m.sendState == SendState.sent) {
        oldest = m;
        break;
      }
    }
    if (oldest == null) return;

    _loadingMore = true;
    _notify();
    try {
      final page = await _service.messages(classId, before: oldest.id);
      _hasMore = page.hasMore;
      _merge(page.messages);
    } catch (_) {
      // Leave the list as it is; scrolling to the top again retries
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  /// After the connection comes back: catch up on anything missed.
  Future<void> _syncLatest() async {
    try {
      final details = await _service.details(classId);
      final page = await _service.messages(classId);
      _room = details.room;
      _activeSession = details.activeSession;
      _pinned = details.pinned;
      _merge(page.messages);
      _notify();
    } catch (_) {
      // Try again on the next reconnect
    }
  }

  /// Reloads the class details and catches up on messages. Call it after
  /// coming back from a settings or members screen.
  Future<void> refresh() => _syncLatest();

  /// Adds new messages and updates existing ones (matched by id).
  void _merge(List<ChatMessage> incoming) {
    for (final m in incoming) {
      final i = _messages.indexWhere((x) => x.id == m.id);
      if (i == -1) {
        _messages.add(m);
      } else {
        _messages[i] = m;
      }
    }
    _messages.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  }

  void _onConnectionChanged() {
    final online = _socket.connected.value;
    if (online && !_wasOnline) {
      _wasOnline = true;
      if (!_loading) unawaited(_syncLatest());
    } else if (!online) {
      _wasOnline = false;
    }
    _notify();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SENDING
  // ══════════════════════════════════════════════════════════════════════════

  String _newClientId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';

  /// Shows the message right away, then sends it. The returned result is only
  /// needed if the screen wants to react (for example, to show a snackbar).
  Future<SocketAck> send(String text, {ChatMessage? replyTo}) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return Future.value(const SocketAck(ok: false, error: 'INVALID_TEXT'));
    }

    userStoppedTyping();
    final clientId = _newClientId();

    ReplyPreview? preview;
    if (replyTo != null) {
      preview = ReplyPreview(
        id: replyTo.id,
        text: replyTo.text.length > 120
            ? replyTo.text.substring(0, 120)
            : replyTo.text,
        deleted: false,
        senderName: replyTo.senderName,
      );
    }

    _messages.add(
      ChatMessage(
        id: clientId,
        clientId: clientId,
        classId: classId,
        senderId: _myId,
        senderName: _myName,
        text: clean,
        deleted: false,
        pinned: false,
        replyTo: preview,
        createdAt: DateTime.now(),
        sendState: SendState.sending,
      ),
    );
    _notify();

    return _deliver(clientId, clean, replyTo?.id);
  }

  Future<SocketAck> _deliver(
    String clientId,
    String text,
    String? replyToId,
  ) async {
    final ack = await _socket.sendMessage(
      classId: classId,
      text: text,
      clientId: clientId,
      replyTo: replyToId,
    );

    if (ack.ok) {
      final raw = ack.data['message'];
      if (raw is Map) {
        final real = ChatMessage.fromMap(Map<String, dynamic>.from(raw));
        if (_myId.isEmpty) _myId = real.senderId;
        _replacePending(clientId, real);
      }
    } else {
      _markFailed(clientId, ack);
    }
    return ack;
  }

  /// Swaps a "sending" message for the real one. Safe if the live event and
  /// the confirmation both arrive, in either order.
  void _replacePending(String clientId, ChatMessage real) {
    final pendingIdx = clientId.isEmpty
        ? -1
        : _messages.indexWhere((m) => m.id == clientId);
    final realIdx = _messages.indexWhere((m) => m.id == real.id);

    if (pendingIdx != -1 && realIdx != -1) {
      _messages.removeAt(pendingIdx);
    } else if (pendingIdx != -1) {
      _messages[pendingIdx] = real;
    } else if (realIdx == -1) {
      _messages.add(real);
    }
    _failReasons.remove(clientId);
    _messages.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    _notify();
  }

  void _markFailed(String clientId, SocketAck ack) {
    final i = _messages.indexWhere((m) => m.id == clientId);
    if (i == -1) return;
    _messages[i] = _messages[i].copyWith(sendState: SendState.failed);
    _failReasons[clientId] = ack.errorText;
    _notify();
  }

  /// Tap "retry" on a failed message.
  Future<SocketAck> retry(String messageId) {
    final i = _messages.indexWhere((m) => m.id == messageId);
    if (i == -1) {
      return Future.value(const SocketAck(ok: false, error: 'NOT_FOUND'));
    }
    final m = _messages[i];
    _messages[i] = m.copyWith(sendState: SendState.sending);
    _failReasons.remove(messageId);
    _notify();
    return _deliver(messageId, m.text, m.replyTo?.id);
  }

  /// Remove a message that failed to send.
  void discardFailed(String messageId) {
    _messages.removeWhere(
      (m) => m.id == messageId && m.sendState == SendState.failed,
    );
    _failReasons.remove(messageId);
    _notify();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MESSAGE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Delete my own message (or any message if I'm an admin). The screen
  /// updates when the server's live event arrives.
  Future<SocketAck> deleteMessage(String messageId) =>
      _socket.deleteMessage(messageId);

  /// Admin: pin or unpin. Throws ApiException on failure.
  Future<void> pin(String messageId, {required bool pinned}) =>
      _service.pinMessage(classId, messageId, pinned: pinned);

  /// Throws ApiException on failure.
  Future<void> report(String messageId) =>
      _service.reportMessage(classId, messageId);

  // ══════════════════════════════════════════════════════════════════════════
  //  TYPING
  // ══════════════════════════════════════════════════════════════════════════

  /// Call on every keystroke. Tells the class "typing..." once, and
  /// automatically says "stopped" after 3 seconds without typing.
  void userIsTyping() {
    if (!_iAmTyping) {
      _iAmTyping = true;
      _socket.sendTyping(classId, true);
    }
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 3), userStoppedTyping);
  }

  void userStoppedTyping() {
    _stopTypingTimer?.cancel();
    if (_iAmTyping) {
      _iAmTyping = false;
      _socket.sendTyping(classId, false);
    }
  }

  void _onTyping(TypingEvent e) {
    if (e.classId != classId) return;
    if (_myId.isNotEmpty && e.userId == _myId) return;

    _typingTimers[e.userId]?.cancel();
    if (e.isTyping) {
      _typingNames[e.userId] = e.name;
      // If the "stopped" event is lost, don't show "typing..." forever
      _typingTimers[e.userId] = Timer(const Duration(seconds: 5), () {
        _typingNames.remove(e.userId);
        _typingTimers.remove(e.userId);
        _notify();
      });
    } else {
      _typingNames.remove(e.userId);
      _typingTimers.remove(e.userId);
    }
    _notify();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIVE EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  void _onNew(ChatMessage m) {
    if (m.classId != classId) return;
    _replacePending(m.clientId ?? '', m);
  }

  void _onDeleted(Map<String, dynamic> d) {
    if (d['classId'] != classId) return;
    final id = d['id'] as String?;
    if (id == null) return;

    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(
        deleted: true,
        text: '',
        pinned: false,
      );
    }
    _pinned = _pinned.where((m) => m.id != id).toList();
    _notify();
  }

  void _onPinned(Map<String, dynamic> d) {
    if (d['classId'] != classId) return;
    final id = d['id'] as String?;
    if (id == null) return;

    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(pinned: d['pinned'] == true);
      _notify();
    }
    unawaited(_refreshPinned());
  }

  Future<void> _refreshPinned() async {
    try {
      final details = await _service.details(classId);
      _pinned = details.pinned;
      _notify();
    } catch (_) {
      // Keep the current pins
    }
  }

  void _onAnonOpened(AnonSession s) {
    if (s.classId != classId) return;
    _activeSession = s;
    _notify();
  }

  void _onAnonClosed(AnonSession s) {
    if (s.classId != classId) return;
    if (_activeSession?.id == s.id) {
      _activeSession = null;
      _notify();
    }
  }

  void _onClassEvent(ClassEvent e) {
    if (e.classId != classId) return;

    switch (e.name) {
      case 'class:updated':
        _room = _room?.copyWith(
          name: e.data['name'] as String?,
          description: e.data['description'] as String?,
          requireApproval: e.data['requireApproval'] as bool?,
          chatLocked: e.data['chatLocked'] as bool?,
        );
        break;
      case 'class:archived':
        _room = _room?.copyWith(archived: true);
        break;
      case 'class:removed':
        _removed = true;
        break;
      case 'member:joined':
        final r = _room;
        if (r != null) _room = r.copyWith(memberCount: r.memberCount + 1);
        break;
      case 'member:left':
        final r = _room;
        if (r != null) {
          _room = r.copyWith(memberCount: max(0, r.memberCount - 1));
        }
        break;
      default:
        return;
    }
    _notify();
  }
}
