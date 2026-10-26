// lib/stores/anon_store.dart
//
// The state of the anonymous space of ONE class: its sessions, the posts of
// the session being viewed, and the admin actions (start, close, hide).
//
// Open it only from the class screen. That screen already keeps the live room
// joined, so this store just listens; it never joins or leaves the room.
//
// Anonymity: AnonPost has no author field and the server never sends one, so
// nothing in this file (or any screen) can know who wrote a post.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/class_models.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';

class AnonStore extends ChangeNotifier {
  AnonStore(this.classId);

  final String classId;
  final _service = ClassService();
  final _socket = ClassSocket();

  // ── State ──────────────────────────────────────────────────────────────────
  List<AnonSession> _sessions = []; // newest first
  AnonSession? _viewing;
  List<AnonPost> _posts = []; // newest first

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _sending = false;
  bool _busy = false; // an admin action is running
  String? _error;

  /// true when the student picked an old session from the history list, so a
  /// newly opened session must not pull them away from it.
  bool _manual = false;

  bool _disposed = false;
  bool _wasOnline = false;
  final List<StreamSubscription<dynamic>> _subs = [];

  // ── Read-only view for the screen ──────────────────────────────────────────
  List<AnonSession> get sessions => List.unmodifiable(_sessions);
  AnonSession? get viewing => _viewing;
  List<AnonPost> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get sending => _sending;
  bool get busy => _busy;
  String? get error => _error;

  /// The session that is open right now (there is at most one per class).
  AnonSession? get openSession {
    for (final s in _sessions) {
      if (s.isOpen) return s;
    }
    return null;
  }

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
      ..add(_socket.onAnonOpened.listen(_onOpened))
      ..add(_socket.onAnonClosed.listen(_onClosed))
      ..add(_socket.onAnonNew.listen(_onNew))
      ..add(_socket.onAnonHidden.listen(_onHidden));

    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _socket.connected.removeListener(_onConnectionChanged);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOADING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      _notify();
    }

    try {
      final list = await _service.anonSessions(classId);
      _sessions = list;

      // Keep the old session the student chose, otherwise show the open
      // session, otherwise the most recent one.
      AnonSession? kept;
      if (_manual && _viewing != null) {
        for (final s in list) {
          if (s.id == _viewing!.id) kept = s;
        }
      }
      final target = kept ?? openSession ?? (list.isNotEmpty ? list.first : null);
      if (kept == null) _manual = false;

      if (target == null || target.id != _viewing?.id) {
        _posts = [];
        _hasMore = false;
      }
      _viewing = target;
      if (target != null) await _loadPosts(target.id);
    } on ApiException catch (e) {
      if (!silent) _error = e.message;
    } catch (_) {
      if (!silent) _error = 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _loadPosts(String sessionId) async {
    final page = await _service.anonPosts(classId, sessionId);
    if (_viewing?.id != sessionId) return; // the student switched meanwhile
    _putSession(page.session);
    _posts = page.posts;
    _hasMore = page.hasMore;
  }

  /// Show another session (from the history list).
  Future<void> viewSession(AnonSession s) async {
    _manual = !s.isOpen;
    _viewing = s;
    _posts = [];
    _hasMore = false;
    _loading = true;
    _error = null;
    _notify();

    try {
      await _loadPosts(s.id);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Jump back to the open session.
  Future<void> viewOpen() async {
    final open = openSession;
    if (open != null) await viewSession(open);
  }

  Future<void> loadOlder() async {
    final s = _viewing;
    if (_loadingMore || !_hasMore || s == null || _posts.isEmpty) return;

    _loadingMore = true;
    _notify();
    try {
      final page = await _service.anonPosts(
        classId,
        s.id,
        before: _posts.last.id,
      );
      if (_viewing?.id == s.id) {
        final known = _posts.map((p) => p.id).toSet();
        _posts = [..._posts, ...page.posts.where((p) => !known.contains(p.id))];
        _hasMore = page.hasMore;
      }
    } catch (_) {
      // Scrolling to the bottom again retries
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  void _onConnectionChanged() {
    final online = _socket.connected.value;
    if (online && !_wasOnline) {
      _wasOnline = true;
      if (!_loading) unawaited(load(silent: true)); // catch up on missed posts
    } else if (!online) {
      _wasOnline = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STUDENTS: POSTING
  // ══════════════════════════════════════════════════════════════════════════

  /// Sends an anonymous post. The post appears in the list when the server's
  /// live event arrives (a moment later), so it shows up for everyone at the
  /// same time.
  Future<SocketAck> sendPost(String text) async {
    final s = _viewing;
    final clean = text.trim();
    if (s == null || !s.isOpen) {
      return const SocketAck(ok: false, error: 'SESSION_CLOSED');
    }
    if (clean.isEmpty) {
      return const SocketAck(ok: false, error: 'INVALID_TEXT');
    }

    _sending = true;
    _notify();
    final ack = await _socket.sendAnonPost(
      classId: classId,
      sessionId: s.id,
      text: clean,
    );
    _sending = false;
    _notify();
    return ack;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADMINS
  //  Each returns null on success, or a message to show on failure.
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> startSession(String prompt) async {
    _busy = true;
    _notify();
    try {
      final s = await _service.openAnonSession(classId, prompt: prompt.trim());
      _manual = false;
      _putSession(s);
      _viewing = s;
      _posts = [];
      _hasMore = false;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<String?> closeSession() async {
    final open = openSession;
    if (open == null) return 'There is no open session.';

    _busy = true;
    _notify();
    try {
      final s = await _service.closeAnonSession(classId, open.id);
      _putSession(s);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Hides a post for everyone. With [block], the sender also can't post again
  /// in this session. The admin never learns who they are.
  Future<String?> hidePost(String postId, {bool block = false}) async {
    final s = _viewing;
    if (s == null) return 'No session selected.';

    try {
      await _service.hideAnonPost(classId, s.id, postId, block: block);
      _posts = _posts.where((p) => p.id != postId).toList();
      _notify();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIVE EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  void _putSession(AnonSession s) {
    final i = _sessions.indexWhere((x) => x.id == s.id);
    if (i == -1) {
      _sessions = [s, ..._sessions];
    } else {
      _sessions = [..._sessions];
      _sessions[i] = s;
    }
    if (_viewing?.id == s.id) _viewing = s;
  }

  void _onOpened(AnonSession s) {
    if (s.classId != classId) return;
    _putSession(s);

    // Move to the new session, unless the student is reading an old one
    if (_viewing == null || !_manual) {
      if (_viewing?.id != s.id) {
        _posts = [];
        _hasMore = false;
      }
      _viewing = s;
    }
    _notify();
  }

  void _onClosed(AnonSession s) {
    if (s.classId != classId) return;
    _putSession(s);
    _notify();
  }

  void _onNew(AnonPost post) {
    if (post.classId != classId) return;

    for (final s in _sessions) {
      if (s.id == post.sessionId) {
        _putSession(s.copyWith(postCount: s.postCount + 1));
        break;
      }
    }

    if (_viewing?.id == post.sessionId &&
        !_posts.any((p) => p.id == post.id)) {
      _posts = [post, ..._posts];
    }
    _notify();
  }

  void _onHidden(Map<String, dynamic> d) {
    if (d['classId'] != classId) return;
    final id = d['id'] as String?;
    if (id == null) return;
    _posts = _posts.where((p) => p.id != id).toList();
    _notify();
  }
}