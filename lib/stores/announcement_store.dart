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

  List<Announcement> get items =>
      List.unmodifiable(_allFetched.where((a) => !_hiddenIds.contains(a.id)));
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _unreadIds.length;

  bool isUnread(String id) => _unreadIds.contains(id);

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
      final fresh = await AnnouncementService.fetchAnnouncements();

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

  // ── Permanent local delete (students) ────────────────────────────────────
  // Hides the announcement on THIS device forever. It still exists on the
  // server / for other users — this is "delete for me", like clearing an
  // inbox item, not retracting the broadcast.
  Future<void> hideLocal(String id) async {
    _hiddenIds.add(id);
    _unreadIds.remove(id);
    await _persistHidden();
    notifyListeners();
  }

  Future<void> hideAllLocal() async {
    for (final a in _allFetched) {
      _hiddenIds.add(a.id);
    }
    _unreadIds.clear();
    await _persistHidden();
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