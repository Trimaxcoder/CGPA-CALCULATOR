// lib/services/notification_router.dart
import 'package:flutter/material.dart';
import 'navigation_service.dart';
import '../screens/main_shell.dart';
import '../screens/notifications_screen.dart';
import '../screens/announcement_detail_screen.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';
import '../stores/announcement_store.dart';

class NotificationRouter {
  /// Called when the user taps a notification card inside the app.
  /// Has access to the full [AppNotification] including [data] map.
  static void route(AppNotification n) {
    if (n.type == 'announcement') {
      _routeToAnnouncement(n.data['announcementId'] as String?);
      return;
    }
    routeByType(n.type);
  }

  /// Called when the app is opened from a push tap (background or cold start).
  /// Only has the [type] string — no data map — so announcements fall back
  /// to opening the Notifications screen on the Announcements tab.
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
          MaterialPageRoute(
            builder: (_) => const MainShell(initialIndex: 1),
          ),
        );
        break;

      case 'announcement':
        // No announcementId available here — open Notifications screen.
        // The Announcements tab will be visible and the user can tap from there.
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;

      case 'admin_approved':
      case 'admin_rejected':
      case 'admin_revoked':
      default:
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Tries to find the announcement by [announcementId] in the already-loaded
  /// store and opens its detail screen directly.
  /// Falls back to the Notifications screen if the store is empty or the id
  /// isn't found (e.g. the app was freshly installed and cache is cold).
  static void _routeToAnnouncement(String? announcementId) {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    Announcement? match;

    if (announcementId != null) {
      final items = AnnouncementStore().items;
      try {
        match = items.firstWhere((a) => a.id == announcementId);
      } catch (_) {
        // firstWhere throws StateError when nothing matches
        match = null;
      }
    }

    if (match != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(announcement: match!),
        ),
      );
    } else {
      // Announcement not in cache yet — send user to the list so they can
      // pull-to-refresh and tap it themselves.
      navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }
}