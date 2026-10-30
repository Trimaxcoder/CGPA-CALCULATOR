import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, debugPrintStack;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'timetable_service.dart';
import 'muted_courses_store.dart';
import 'notification_store.dart';
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
  static bool _listening = false;

  // Longest we wait on each network call during startup.
  static const _tokenTimeout = Duration(seconds: 10);
  static const _saveTokenTimeout = Duration(seconds: 8);

  // The small white "SL" picture shown in the status bar.
  // It lives in android/app/src/main/res/drawable-*/ic_notification.png
  static const _smallIcon = 'ic_notification';
  static const _accent = Color(0xFF1565C0);

  // Channels. The main one is also named in AndroidManifest.xml, so a push
  // that arrives while the app is closed uses it too.
  static const _mainChannelId = 'gradex_channel';
  static const _studyChannelId = 'study_reminders';

  static Future<void> init() async {
    if (_initialized) {
      debugPrint('NotificationService.init() called again, skipping.');
      return;
    }

    if (kIsWeb) {
      await web_impl.NotificationServiceWeb.init();
      _initialized = true;
      return;
    }

    // Every step is on its own. If one of them fails (a missing icon, a
    // permission prompt that is refused) the others still run, so one problem
    // can never stop this phone from registering for notifications.
    await _step('permission', () async {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    });
    await _step('local notifications', _initLocalNotifications);

    _registerListeners();
    _initialized = true;

    await syncToken();
  }

  static Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('NotificationService: "$name" failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  static void _registerListeners() {
    if (_listening) return;
    _listening = true;

    // App is open: Firebase shows nothing by itself, so we show it.
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _storeNotification(message);
    });

    // App was in the background and a notification was tapped.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _storeNotification(message);
      NotificationRouter.routeWhenReady(_toAppNotification(message));
    });

    _messaging.onTokenRefresh.listen((token) {
      _saveToken(token);
    });
  }

  // ── Token registration ─────────────────────────────────────────────────────

  static bool _syncing = false;
  static int _retries = 0;
  static Timer? _retryTimer;

  /// Gets this phone's notification address and saves it on the server.
  /// Safe to call as often as you like. If it fails (no internet, not signed
  /// in yet) it tries again every 30 seconds for a few minutes.
  static Future<void> syncToken() async {
    if (kIsWeb || _syncing) return;
    _syncing = true;
    try {
      final token = await _getTokenWithRetry();
      if (token == null) {
        debugPrint('FCM token unavailable, will try again.');
        _scheduleRetry();
        return;
      }
      final saved = await _saveToken(token);
      if (saved) {
        _retryTimer?.cancel();
        _retries = 0;
      } else {
        _scheduleRetry();
      }
    } finally {
      _syncing = false;
    }
  }

  static void _scheduleRetry() {
    if (_retries >= 12) return; // the next app resume starts over
    _retries++;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), syncToken);
  }

  /// Call this right after a student signs in (or switches account), so the
  /// new account gets notifications on this phone straight away.
  static Future<void> onLogin() {
    _retries = 0;
    return syncToken();
  }

  /// Called whenever the app comes back to the front.
  static Future<void> onAppResumed() {
    if (!_initialized) return Future.value();
    _retries = 0;
    return syncToken();
  }

  /// Fetches the FCM token, retrying with exponential backoff if Play
  /// Services is momentarily unreachable (e.g. SERVICE_NOT_AVAILABLE).
  /// Returns null (instead of throwing) if all attempts fail.
  static Future<String?> _getTokenWithRetry({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    var delay = initialDelay;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _messaging.getToken().timeout(_tokenTimeout);
      } catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        debugPrint(
          'getToken() failed (attempt $attempt/$maxAttempts): $e'
          '${isLastAttempt ? ', giving up' : ', retrying in ${delay.inSeconds}s'}',
        );

        if (isLastAttempt) return null;

        await Future.delayed(delay);
        delay *= 2; // 2s, 4s, 8s...
      }
    }
    return null;
  }

  /// true when the server accepted the token.
  static Future<bool> _saveToken(String token) async {
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
      await _svc
          .saveNotificationToken(
            token: token,
            school: school,
            faculty: faculty,
            department: department,
            level: level,
          )
          .timeout(_saveTokenTimeout);
      return true;
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
      return false;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcmToken');
  }

  // ── Opening the app from a notification ────────────────────────────────────

  /// Call this once after runApp(), for the case where the app was completely
  /// closed and got opened by tapping a push.
  static Future<RemoteMessage?> getInitialMessage() {
    if (kIsWeb) return Future.value(null);
    return _messaging.getInitialMessage();
  }

  static void routeFromInitialMessage(RemoteMessage message) {
    NotificationRouter.routeWhenReady(_toAppNotification(message));
  }

  static AppNotification _toAppNotification(RemoteMessage message) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'SchoolLife',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
      data: message.data,
      receivedAt: DateTime.now(),
    );
  }

  /// A notification the app drew itself was tapped. Its payload is the
  /// message data as JSON (older ones were "class:<classId>").
  static void _routeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> data;
    if (payload.startsWith('class:')) {
      data = {'type': 'class_message', 'classId': payload.substring(6)};
    } else {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) return;
        data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return;
      }
    }

    NotificationRouter.routeWhenReady(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        body: '',
        type: (data['type'] ?? 'general').toString(),
        data: data,
        receivedAt: DateTime.now(),
      ),
    );
  }

  // ── Local notifications ────────────────────────────────────────────────────

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(_smallIcon);
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _routeFromPayload(response.payload);
      },
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      await _step('notification permission', () async {
        await androidImpl.requestNotificationsPermission();
      });

      // Create the channels now, with high importance, so alerts pop up on
      // screen. (Exact alarm permission is asked only when a study reminder
      // is switched on, not at every start.)
      await _step('channels', () async {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _mainChannelId,
            'SchoolLife notifications',
            description: 'Class chat, class alerts and announcements',
            importance: Importance.high,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _studyChannelId,
            'Study reminders',
            description: 'Reminders for bookmarked personal study sessions',
            importance: Importance.high,
          ),
        );
      });
    }

    // The app was closed and a notification this app drew was tapped
    await _step('launch details', () async {
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        _routeFromPayload(launch.notificationResponse?.payload);
      }
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // Normal pushes carry a title and body. Data-only ones may carry them
    // inside the data instead.
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    final courseCode = message.data['courseCode'] ?? '';
    if (courseCode.isNotEmpty && MutedCoursesStore().isMuted(courseCode)) {
      return; // user muted this course, skip showing the notification
    }

    // Class notifications use one fixed id per class, so a new message
    // replaces the previous notification instead of piling up.
    final classId = (message.data['classId'] ?? '').toString();
    final isClass = classId.isNotEmpty;
    final notificationId = isClass
        ? 'class:$classId'.hashCode & 0x7fffffff
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      _mainChannelId,
      'SchoolLife notifications',
      channelDescription: 'Class chat, class alerts and announcements',
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      color: _accent,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  static Future<void> _storeNotification(RemoteMessage message) async {
    // Chat messages would flood the bell history, so they are not saved
    if (message.data['type'] == 'class_message') return;

    final courseCode = message.data['courseCode'] ?? '';
    if (courseCode.isNotEmpty && MutedCoursesStore().isMuted(courseCode)) {
      return; // also skip saving to bell/badge history
    }

    await NotificationStore().add(
      title: message.notification?.title ?? 'SchoolLife',
      body: message.notification?.body ?? '',
      type: message.data['type'] ?? 'general',
      data: message.data,
    );
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

  static const _studyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _studyChannelId,
      'Study reminders',
      channelDescription: 'Reminders for bookmarked personal study sessions',
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      color: _accent,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<bool> scheduleStudyReminder({
    required String entryId,
    required String title,
    required String day,
    required String startTime,
    int minutesBefore = 10,
  }) async {
    final hasPermission = await canScheduleExactAlarms();
    if (!hasPermission) {
      debugPrint('Cannot schedule: exact alarm permission not granted.');
      return false; // caller knows it failed
    }

    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final weekday = _weekdayFor(day);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
            .subtract(Duration(minutes: minutesBefore));

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _localNotifications.zonedSchedule(
        entryId.hashCode,
        '📖 Study Time!',
        'Time to study $title, you\'ve got this!',
        scheduled,
        _studyDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode({'type': 'study_reminder'}),
      );
      return true;
    } catch (e, st) {
      debugPrint('zonedSchedule FAILED: $e');
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  static Future<void> cancelStudyReminder(String entryId) async {
    await _localNotifications.cancel(entryId.hashCode);
  }

  // ── Personal Reminders toggle support ──

  static Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return true; // iOS doesn't need this
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidImpl?.canScheduleExactNotifications() ?? false;
  }

  static Future<void> openExactAlarmSettings() async {
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// Schedules a one-off verification notification ~10 seconds out.
  /// Used right after the user enables Personal Reminders, so they get
  /// immediate proof it works instead of waiting days for a real class.
  static Future<void> scheduleVerificationTest() async {
    final scheduled =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    debugPrint('Verification test scheduled for: $scheduled');

    try {
      await _localNotifications.zonedSchedule(
        777777,
        '✅ Reminders are working!',
        'Personal study reminders are set up correctly.',
        scheduled,
        _studyDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: jsonEncode({'type': 'study_reminder'}),
      );
    } catch (e, st) {
      debugPrint('Verification test FAILED: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}