import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'timetable_service.dart';

class NotificationServiceWeb {
  static final _messaging = FirebaseMessaging.instance;
  static final _svc = TimetableService();

  static Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (html.Notification.supported) {
      await html.Notification.requestPermission();
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      if (!html.Notification.supported) return;
      if (html.Notification.permission != 'granted') return;

      html.Notification(
        notification.title ?? 'Gradex',
        body: notification.body ?? '',
        icon: '/icons/Icon-192.png',
      );
    });
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', token);

    try {
      final raw = prefs.getString('profile');
      String school = '', faculty = '', department = '', level = '';
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        school     = decoded['school']     ?? '';
        faculty    = decoded['faculty']    ?? '';
        department = decoded['department'] ?? '';
        level      = decoded['level']      ?? '';
      }
      await _svc.saveNotificationToken(
        token: token, school: school, faculty: faculty,
        department: department, level: level,
      );
    } catch (e) {
      print('Failed to save FCM token: $e');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcmToken');
  }
}