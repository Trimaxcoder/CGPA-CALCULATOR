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
import 'screens/notifications_screen.dart';
import 'screens/main_shell.dart';
import 'services/muted_courses_store.dart';

// Global navigator key — lets us navigate from outside a widget's context
final navigatorKey = GlobalKey<NavigatorState>();

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
  );
}

void main() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationStore().load();
  await MutedCoursesStore().load();
  await NotificationService.init();

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
      _routeFromNotification(message.data['type'] ?? 'general');
    });
  }

  void _routeFromNotification(String type) {
    switch (type) {
      case 'class_reminder':
      case 'emergency_toggle':
      case 'test_toggle':
      case 'attendance_toggle':
      case 'cancelled_toggle':
      case 'important_class':
      case 'exam_added':
        // All timetable-related — open the app to the Timetable tab
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
        break;
      case 'admin_approved':
      case 'admin_rejected':
      case 'admin_revoked':
        // Account/admin-status related — open the Notifications screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      default:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => NotificationStore()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) => MaterialApp(
          navigatorKey: navigatorKey,
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
