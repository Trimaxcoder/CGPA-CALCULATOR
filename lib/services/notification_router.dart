// lib/services/notification_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'navigation_service.dart';
import 'class_service.dart';
import '../screens/main_shell.dart';
import '../screens/notifications_screen.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/class_screen.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';
import '../stores/announcement_store.dart';
import '../screens/class_workspace_screen.dart';

/// Watches the navigator so the router knows when the splash screen is gone.
/// The splash screen is the app's first page (route name "/"). It replaces
/// itself with the real home page after it has checked the login.
class _SplashWatcher extends NavigatorObserver {
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute?.settings.name == '/') NotificationRouter._markReady();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == '/') NotificationRouter._markReady();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name == '/') NotificationRouter._markReady();
  }
}

class NotificationRouter {
  /// Give this to MaterialApp(navigatorObservers: [...]).
  static final NavigatorObserver observer = _SplashWatcher();

  static bool _ready = false;
  static AppNotification? _pending;
  static Timer? _safetyTimer;

  /// Opens the right screen for a tapped notification. If the app was closed
  /// and is still starting up (splash screen), the tap is kept and carried
  /// out as soon as the home page is on screen. Otherwise a navigation made
  /// now would be wiped out by the splash screen replacing itself.
  static void routeWhenReady(AppNotification n) {
    if (_ready) {
      route(n);
      return;
    }
    _pending = n;
    // Safety net: never keep a tap waiting forever
    _safetyTimer ??= Timer(const Duration(seconds: 12), _markReady);
  }

  static void _markReady() {
    _ready = true;
    _safetyTimer?.cancel();
    _safetyTimer = null;

    final n = _pending;
    _pending = null;
    if (n == null) return;
    // Let the home page finish building first
    Future.delayed(const Duration(milliseconds: 600), () => route(n));
  }

  /// Push types that belong to the "Join a class" feature. Each one carries a
  /// classId in its data, so tapping it opens that class.
  static const _classTypes = {
    'class_message',
    'anon_opened',
    'class_join_request',
    'class_approved',
  };

  /// Called when the user taps a notification card inside the app.
  /// Has access to the full [AppNotification] including [data] map.
  static void route(AppNotification n) {
    if (_classTypes.contains(n.type)) {
      _routeToClass(n.data['classId']?.toString());
      return;
    }

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
      case 'study_reminder':
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

      case 'class_message':
      case 'anon_opened':
      case 'class_join_request':
      case 'class_approved':
        // No classId available here — open the class list instead.
        navigator.push(
          MaterialPageRoute(builder: (_) => const ClassWorkspaceScreen()),
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

  /// Opens the class chat for [classId]. If the class can't be loaded (no
  /// internet, or the student is no longer a member) it opens the class list.
  static Future<void> _routeToClass(String? classId) async {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    if (classId == null || classId.isEmpty) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const ClassWorkspaceScreen()),
      );
      return;
    }

    try {
      final details = await ClassService().details(classId);
      final nav = NavigationService.navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(builder: (_) => ClassScreen(room: details.room)),
      );
    } catch (_) {
      NavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ClassWorkspaceScreen()),
      );
    }
  }

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