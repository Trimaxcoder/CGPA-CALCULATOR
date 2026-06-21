// lib/services/notification_store.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationStore extends ChangeNotifier {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  static const _key = 'app_notifications';
  static const _maxStored = 100; // cap so storage doesn't grow forever

  List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _items = [];
    } else {
      final list = jsonDecode(raw) as List;
      _items = list.map((e) => AppNotification.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((n) => n.toMap()).toList()));
  }

  Future<void> add({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      receivedAt: DateTime.now(),
    );
    _items.insert(0, notif);
    if (_items.length > _maxStored) {
      _items = _items.sublist(0, _maxStored);
    }
    await _save();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final n in _items) {
      n.isRead = true;
    }
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }
}
