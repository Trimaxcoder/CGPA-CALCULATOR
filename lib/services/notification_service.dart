import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'timetable_service.dart';
import 'notification_store.dart'; // ← new import, adjust path to where you saved it
import 'notification_service_web.dart' if (dart.library.io) 'notification_service_stub.dart' as web_impl;

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _svc = TimetableService();
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) {
      await web_impl.NotificationServiceWeb.init();
      return;
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _initLocalNotifications();

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    // App is open and in foreground when push arrives
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _storeNotification(message);
    });

    // App was in background, user taps the push to open it
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _storeNotification(message);
      // Navigation handling goes in main.dart, see note below
    });
  }

  /// Call this once from main(), AFTER runApp(), to handle the case where
  /// the app was completely closed and got opened by tapping a push.
  static Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  static Future<void> _initLocalNotifications() async {
    // ── CHANGED: was '@mipmap/ic_launcher' (your square app icon) ──
    // Now points to a custom white silhouette icon you need to add yourself.
    const androidSettings = AndroidInitializationSettings('ic_notification');
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
      icon: 'ic_notification', // ← added: same custom icon as above
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

  /// NEW: saves the incoming push into local notification history
  /// so it shows up in your in-app Notifications screen + badge count.
  static Future<void> _storeNotification(RemoteMessage message) async {
    await NotificationStore().add(
      title: message.notification?.title ?? 'GradeX',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
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