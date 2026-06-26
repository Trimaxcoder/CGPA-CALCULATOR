import 'package:flutter/material.dart';
import 'navigation_service.dart';
import '../screens/main_shell.dart';
import '../screens/timetable_screen.dart';
import '../screens/notifications_screen.dart';
import '../models/app_notification.dart';

class NotificationRouter {
  /// Single source of truth for "where does this notification type go".
  /// Called from: card tap, FCM background tap, and cold-start tap.
  static void route(AppNotification n) => routeByType(n.type);

  static void routeByType(String type) {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    switch (type) {
      case 'class_reminder':
      case 'emergency_toggle':
      case 'test_toggle':
      case 'attendance_toggle':
      case 'cancelled_toggle':
      case 'important_class':
      case 'exam_added':
      case 'morning_digest':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1)),
        );
        break;
      case 'admin_approved':
      case 'admin_rejected':
      case 'admin_revoked':
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      default:
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
    }
  }
}
