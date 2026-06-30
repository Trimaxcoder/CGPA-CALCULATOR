import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/theme_notifier.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/notification_store.dart';
import 'services/notification_router.dart';
import 'services/navigation_service.dart'; 
import 'services/muted_courses_store.dart';
import 'stores/announcement_store.dart';

// REMOVED: local `final navigatorKey = GlobalKey<NavigatorState>();`
// Now using NavigationService.navigatorKey everywhere instead, so
// NotificationService/NotificationRouter can navigate from outside
// a widget's context too.

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final courseCode = message.data['courseCode'] ?? '';
  await MutedCoursesStore().load(); // background isolate needs to load fresh
  if (courseCode.isNotEmpty && MutedCoursesStore().isMuted(courseCode)) {
    return;
  }

  await NotificationStore().add(
    title: message.notification?.title ?? 'GradeX',
    body: message.notification?.body ?? '',
    type: message.data['type'] ?? 'general',
    data: message.data, // NEW — keep courseCode/examId for routing later
  );
}

/// Wraps NotificationService.init() so that a transient FCM/Play Services
/// failure (e.g. SERVICE_NOT_AVAILABLE) never crashes app startup.
/// Retries once in the background after a short delay if the first
/// attempt fails.
Future<void> _initNotificationsSafely() async {
  try {
    await NotificationService.init();
  } catch (e, st) {
    debugPrint('NotificationService.init failed (will retry): $e');
    debugPrintStack(stackTrace: st);

    // Retry once in the background — don't block app launch on this.
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        await NotificationService.init();
      } catch (e2) {
        debugPrint('NotificationService retry also failed: $e2');
      }
    });
  }
}

void main() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationStore().load();
  await MutedCoursesStore().load();

  // Don't let push-token failures (e.g. SERVICE_NOT_AVAILABLE on devices
  // with outdated/missing Play Services) block or crash app startup.
  await _initNotificationsSafely();
  await AnnouncementStore().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final message = await NotificationService.getInitialMessage();
    if (message == null) return;

    // Wait until the first frame is drawn before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationRouter.routeByType(message.data['type'] ?? 'general'); // CHANGED
    });
  }

  // REMOVED: _routeFromNotification — logic now lives in
  // NotificationRouter.routeByType so it's shared with FCM
  // background-tap and in-app card-tap too, instead of being
  // duplicated three times.

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => NotificationStore()),
        ChangeNotifierProvider(create: (_) => AnnouncementStore()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) => MaterialApp(
          navigatorKey: NavigationService.navigatorKey, // CHANGED
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          ),
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}