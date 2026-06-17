import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../services/timetable_service.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _svc = TimetableService();
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      if (kIsWeb) {
        print('FCM foreground (web): ${message.notification?.title}');
      } else {
        _showLocalNotification(message);
      }
    });
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(settings);

    final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'gradex_channel',
      'Gradex Notifications',
      channelDescription: 'Timetable and admin notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
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
        token: token,
        school: school,
        faculty: faculty,
        department: department,
        level: level,
      );
    } catch (e) {
      print('Failed to save FCM token to backend: $e');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcmToken');
  }
}