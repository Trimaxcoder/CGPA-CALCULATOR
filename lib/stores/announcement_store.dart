// lib/stores/announcement_store.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';

class AnnouncementStore extends ChangeNotifier {
  AnnouncementStore._();
  static final AnnouncementStore _instance = AnnouncementStore._();
  factory AnnouncementStore() => _instance;

  List<Announcement> _allFetched = []; // raw server result, unfiltered
  bool _loading = false;
  String? _error;

  // Announcements this device has permanently hidden (student "delete").
  // Survives refresh() because every fetch is filtered against this set.
  final Set<String> _hiddenIds = {};

  // Read/unread tracking (separate from hidden — hidden implies read too)
  final Set<String> _unreadIds = {};
  final Set<String> _readIds   = {};

  // How many of each kind we pull on a refresh. Fetching the two scopes
  // separately means a burst of general announcements can never push a
  // student's class announcements out of the list (or the other way round).
  static const _pageSize = 30;

  List<Announcement> get items =>
      List.unmodifiable(_allFetched.where((a) => !_hiddenIds.contains(a.id)));

  /// General announcements (from the super admin)
  List<Announcement> get globalItems =>
      items.where((a) => a.isGlobal).toList();

  /// Announcements for the student's own class (from their course reps)
  List<Announcement> get classItems =>
      items.where((a) => !a.isGlobal).toList();

  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount =>
      _unreadIds.where((id) => !_hiddenIds.contains(id)).length;
  int get unreadGlobalCount =>
      globalItems.where((a) => _unreadIds.contains(a.id)).length;
  int get unreadClassCount =>
      classItems.where((a) => _unreadIds.contains(a.id)).length;

  bool isUnread(String id) => _unreadIds.contains(id);

  /// Find an already-loaded announcement (e.g. when a push is tapped).
  Announcement? byId(String id) {
    for (final a in _allFetched) {
      if (a.id == id) return a;
    }
    return null;
  }

  static const _cacheKey  = 'announcements_cache';
  static const _unreadKey = 'announcements_unread';
  static const _hiddenKey = 'announcements_hidden';

  // ── Boot ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadFromCache();
    await refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final pages = await Future.wait([
        AnnouncementService.fetchPage(scope: 'global', limit: _pageSize),
        AnnouncementService.fetchPage(scope: 'class', limit: _pageSize),
      ]);

      final fresh = [...pages[0].items, ...pages[1].items]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Mark brand-new items (never seen, never hidden) as unread
      final existingIds = _allFetched.map((a) => a.id).toSet();
      for (final a in fresh) {
        final isNew = !existingIds.contains(a.id) &&
            !_readIds.contains(a.id) &&
            !_hiddenIds.contains(a.id);
        if (isNew) _unreadIds.add(a.id);
      }

      _allFetched = fresh;
      await _persistCache();
      await _persistReadState();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    if (_unreadIds.remove(id)) {
      _readIds.add(id);
      await _persistReadState();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    _readIds.addAll(_unreadIds);
    _unreadIds.clear();
    await _persistReadState();
    notifyListeners();
  }

  /// Mark a specific set as read (e.g. only the tab being viewed).
  Future<void> markManyRead(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      if (_unreadIds.remove(id)) {
        _readIds.add(id);
        changed = true;
      }
    }
    if (changed) {
      await _persistReadState();
      notifyListeners();
    }
  }

  /// Hide a specific set on this device (e.g. only the tab being viewed).
  Future<void> hideMany(Iterable<String> ids) async {
    for (final id in ids) {
      _hiddenIds.add(id);
      _unreadIds.remove(id);
    }
    await _persistHidden();
    await _persistReadState();
    notifyListeners();
  }

  // ── Permanent local delete (students) ────────────────────────────────────
  // Hides the announcement on THIS device forever. It still exists on the
  // server / for other users — this is "delete for me", like clearing an
  // inbox item, not retracting the broadcast.
  Future<void> hideLocal(String id) async {
    _hiddenIds.add(id);
    _unreadIds.remove(id);
    await _persistHidden();
    await _persistReadState();
    notifyListeners();
  }

  Future<void> hideAllLocal() async {
    for (final a in _allFetched) {
      _hiddenIds.add(a.id);
    }
    _unreadIds.clear();
    await _persistHidden();
    await _persistReadState();
    notifyListeners();
  }

  // ── Server-side removal (admin retracts an announcement entirely) ───────
  // Call this after AnnouncementService.deleteAnnouncement() succeeds.
  // Removes it from EVERY device's feed on next refresh, not just this one.
  void removeFromServerResult(String id) {
    _allFetched.removeWhere((a) => a.id == id);
    _hiddenIds.remove(id); // no need to keep hiding something that's gone
    _unreadIds.remove(id);
    notifyListeners();
  }

  // Apply an edit locally so the UI updates instantly without a full refresh
  void applyEdit(Announcement updated) {
    final idx = _allFetched.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      _allFetched[idx] = updated;
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  // Call this when the user logs out. Without it, the next person to log in
  // on this device would briefly see the previous user's cached announcements
  // (possibly from a different class) and inherit their hidden/unread state.
  Future<void> clear() async {
    _allFetched = [];
    _hiddenIds.clear();
    _unreadIds.clear();
    _readIds.clear();
    _error = null;
    _loading = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_unreadKey);
      await prefs.remove(_hiddenKey);
    } catch (e) {
      debugPrint('AnnouncementStore.clear: $e');
    }
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _allFetched = list
            .map((e) => Announcement.fromMap(e as Map<String, dynamic>))
            .toList();
      }

      final unreadRaw = prefs.getString(_unreadKey);
      if (unreadRaw != null) {
        final map = jsonDecode(unreadRaw) as Map<String, dynamic>;
        _unreadIds.addAll((map['unread'] as List<dynamic>).cast<String>());
        _readIds.addAll((map['read'] as List<dynamic>).cast<String>());
      }

      final hiddenRaw = prefs.getString(_hiddenKey);
      if (hiddenRaw != null) {
        final list = jsonDecode(hiddenRaw) as List<dynamic>;
        _hiddenIds.addAll(list.cast<String>());
      }

      notifyListeners();
    } catch (e) {
      debugPrint('AnnouncementStore._loadFromCache: $e');
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(_allFetched.map(_toMap).toList()),
      );
    } catch (e) {
      debugPrint('AnnouncementStore._persistCache: $e');
    }
  }

  Future<void> _persistReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _unreadKey,
        jsonEncode({
          'unread': _unreadIds.toList(),
          'read':   _readIds.toList(),
        }),
      );
    } catch (e) {
      debugPrint('AnnouncementStore._persistReadState: $e');
    }
  }

  Future<void> _persistHidden() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hiddenKey, jsonEncode(_hiddenIds.toList()));
    } catch (e) {
      debugPrint('AnnouncementStore._persistHidden: $e');
    }
  }

  Map<String, dynamic> _toMap(Announcement a) => {
        '_id':        a.id,
        'scope':      a.scope, // must be cached, or general ones reload as class
        'adminName':  a.adminName,
        'school':     a.school,
        'faculty':    a.faculty,
        'department': a.department,
        'level':      a.level,
        'title':      a.title,
        'message':    a.message,
        'createdAt':  a.createdAt.toIso8601String(),
        'editedAt':   a.editedAt?.toIso8601String(),
      };
}