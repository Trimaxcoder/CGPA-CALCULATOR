import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'timetable_service.dart';
import 'muted_courses_store.dart';
import 'notification_store.dart';
import 'navigation_service.dart';
import 'notification_router.dart';
import '../models/app_notification.dart';
import 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_stub.dart'
    as web_impl;

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _svc = TimetableService();
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      debugPrint('NotificationService.init() called again — skipping.');
      return;
    }

    if (kIsWeb) {
      await web_impl.NotificationServiceWeb.init();
      _initialized = true;
      return;
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _initLocalNotifications();

    final token = await _getTokenWithRetry();
    if (token != null) {
      await _saveToken(token);
    } else {
      debugPrint(
        'FCM token unavailable after retries — will rely on onTokenRefresh.',
      );
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _storeNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _storeNotification(message);
      final notif = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'GradeX',
        body: message.notification?.body ?? '',
        type: message.data['type'] ?? 'general',
        data: message.data,
        receivedAt: DateTime.now(),
      );
      NotificationRouter.route(notif);
    });

    _initialized =
        true; // CHANGED — moved here, set once after everything registers
  }

  /// Fetches the FCM token, retrying with exponential backoff if Play
  /// Services is momentarily unreachable (e.g. SERVICE_NOT_AVAILABLE).
  /// Returns null (instead of throwing) if all attempts fail — callers
  /// should treat that as "try again later via onTokenRefresh", not fatal.
  static Future<String?> _getTokenWithRetry({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    var delay = initialDelay;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _messaging.getToken();
      } catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        debugPrint(
          'getToken() failed (attempt $attempt/$maxAttempts): $e'
          '${isLastAttempt ? ' — giving up' : ' — retrying in ${delay.inSeconds}s'}',
        );

        if (isLastAttempt) return null;

        await Future.delayed(delay);
        delay *= 2; // exponential backoff: 2s, 4s, 8s...
      }
    }
    return null;
  }

  /// Call this once from main(), AFTER runApp(), to handle the case where
  /// the app was completely closed and got opened by tapping a push.
  static Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  // NEW method
  static void routeFromInitialMessage(RemoteMessage message) {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'GradeX',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
      data: message.data,
      receivedAt: DateTime.now(),
    );
    NotificationRouter.route(notif);
  }

  static Future<void> _initLocalNotifications() async {
    // ── CHANGED: was '@mipmap/ic_launcher' (your square app icon) ──
    // Now points to a custom white silhouette icon you need to add yourself.
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final courseCode = message.data['courseCode'] ?? '';
    if (courseCode.isNotEmpty && MutedCoursesStore().isMuted(courseCode)) {
      return; // user muted this course, skip showing the notification
    }

    const androidDetails = AndroidNotificationDetails(
      'gradex_channel',
      'Gradex Notifications',
      channelDescription: 'Timetable and admin notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }

  static Future<void> _storeNotification(RemoteMessage message) async {
    final courseCode = message.data['courseCode'] ?? '';
    if (courseCode.isNotEmpty && MutedCoursesStore().isMuted(courseCode)) {
      return; // also skip saving to bell/badge history
    }

    await NotificationStore().add(
      title: message.notification?.title ?? 'GradeX',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
      data: message.data,
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
        school = decoded['school'] ?? '';
        faculty = decoded['faculty'] ?? '';
        department = decoded['department'] ?? '';
        level = decoded['level'] ?? '';
      }
      await _svc.saveNotificationToken(
        token: token,
        school: school,
        faculty: faculty,
        department: department,
        level: level,
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcmToken');
  }

  // ── Study reminder scheduling for bookmarked personal sessions ──

  static int _weekdayFor(String day) {
    const map = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };
    return map[day] ?? DateTime.monday;
  }

  static Future<void> scheduleStudyReminder({
    required String entryId,
    required String title,
    required String day,
    required String startTime,
    int minutesBefore = 10,
  }) async {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final weekday = _weekdayFor(day);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(Duration(minutes: minutesBefore));

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'study_reminders',
      'Study Reminders',
      channelDescription: 'Reminders for bookmarked personal study sessions',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.zonedSchedule(
      entryId.hashCode,
      '📖 Study Time!',
      'Time to read $title — you\'ve got this!',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelStudyReminder(String entryId) async {
    await _localNotifications.cancel(entryId.hashCode);
  }
}
