// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_store.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';
import '../stores/announcement_store.dart';
import '../services/notification_router.dart';
import '../services/notification_service.dart';
import '../providers/theme_notifier.dart';
import 'announcement_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  /// Pass initialTab: 1 to land directly on the Announcements tab
  /// (used when a push notification of type 'announcement' is tapped).
  final int initialTab;
  const NotificationsScreen({super.key, this.initialTab = 0});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnnouncementStore().refresh();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'class_reminder':    return Icons.access_time_filled_rounded;
      case 'emergency_toggle':  return Icons.warning_amber_rounded;
      case 'test_toggle':       return Icons.quiz_rounded;
      case 'attendance_toggle': return Icons.how_to_reg_rounded;
      case 'cancelled_toggle':  return Icons.block_rounded;
      case 'important_class':   return Icons.push_pin_rounded;
      case 'exam_added':        return Icons.event_note_rounded;
      case 'admin_approved':    return Icons.verified_rounded;
      case 'admin_rejected':    return Icons.cancel_rounded;
      case 'admin_revoked':     return Icons.gpp_bad_rounded;
      case 'morning_digest':    return Icons.wb_sunny_rounded;
      case 'announcement':      return Icons.campaign_rounded;
      default:                  return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = context.watch<ThemeNotifier>().isDarkMode;
    final notifStore = context.watch<NotificationStore>();
    final annStore   = context.watch<AnnouncementStore>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ],
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x331565C0),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Notifications'),
                            if (notifStore.unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              _Badge(notifStore.unreadCount),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Announcements'),
                            if (annStore.unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              _Badge(annStore.unreadCount),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _NotificationsTab(
                  isDark: isDark,
                  store: notifStore,
                  iconFor: _iconFor,
                  timeAgo: _timeAgo,
                ),
                _AnnouncementsTab(
                  isDark: isDark,
                  store: annStore,
                  timeAgo: _timeAgo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 1 — Notifications
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends StatelessWidget {
  final bool isDark;
  final NotificationStore store;
  final IconData Function(String) iconFor;
  final String Function(DateTime) timeAgo;

  static const Color _primary = Color(0xFF1565C0);

  const _NotificationsTab({
    required this.isDark,
    required this.store,
    required this.iconFor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final items = store.items;

    return Column(
      children: [
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed:
                        store.unreadCount == 0 ? null : store.markAllRead,
                    icon: const Icon(Icons.done_all_rounded,
                        size: 18, color: _primary),
                    label: const Text('Mark all as read',
                        style: TextStyle(color: _primary)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmClearAll(context),
                    icon: const Icon(Icons.delete_sweep_rounded,
                        size: 18, color: Colors.red),
                    label: const Text('Clear all',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  isDark: isDark,
                  icon: Icons.notifications_none_rounded,
                  label: 'No notifications yet',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return Dismissible(
                      key: Key(n.id),
                      direction: DismissDirection.endToStart,
                      background: const _DismissBackground(),
                      onDismissed: (_) => store.remove(n.id),
                      child: _NotifCard(
                        n: n,
                        isDark: isDark,
                        icon: iconFor(n.type),
                        timeLabel: timeAgo(n.receivedAt),
                        onTap: () {
                          store.markAsRead(n.id);
                          NotificationRouter.route(n);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              store.clearAll();
              Navigator.pop(ctx);
            },
            child:
                const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 2 — Announcements
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementsTab extends StatelessWidget {
  final bool isDark;
  final AnnouncementStore store;
  final String Function(DateTime) timeAgo;

  static const Color _primary = Color(0xFF1565C0);

  const _AnnouncementsTab({
    required this.isDark,
    required this.store,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    if (store.loading && store.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.error != null && store.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Could not load announcements',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: store.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = store.items;

    return Column(
      children: [
        // ── Action row ───────────────────────────────────────────────────
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed:
                        store.unreadCount == 0 ? null : store.markAllRead,
                    icon: const Icon(Icons.done_all_rounded,
                        size: 18, color: _primary),
                    label: const Text('Mark all as read',
                        style: TextStyle(color: _primary)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmClearAll(context),
                    icon: const Icon(Icons.delete_sweep_rounded,
                        size: 18, color: Colors.red),
                    label: const Text('Clear all',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  isDark: isDark,
                  icon: Icons.campaign_outlined,
                  label: 'No announcements yet',
                )
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final a = items[i];
                      final unread = store.isUnread(a.id);
                      return Dismissible(
                        key: Key(a.id),
                        direction: DismissDirection.endToStart,
                        background: const _DismissBackground(),
                        onDismissed: (_) => store.hideLocal(a.id),
                        child: _AnnouncementCard(
                          a: a,
                          isDark: isDark,
                          isUnread: unread,
                          timeLabel: timeAgo(a.createdAt),
                          onTap: () {
                            store.markRead(a.id);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AnnouncementDetailScreen(announcement: a),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all announcements?'),
        content: const Text('This removes them from your view only.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              store.hideAllLocal();
              Navigator.pop(ctx);
            },
            child:
                const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      );
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;

  static const Color _primary = Color(0xFF1565C0);

  const _EmptyState(
      {required this.isDark, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, size: 44, color: _primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification n;
  final bool isDark;
  final IconData icon;
  final String timeLabel;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1565C0);

  const _NotifCard({
    required this.n,
    required this.isDark,
    required this.icon,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: !n.isRead
                ? Border.all(color: _primary.withOpacity(0.4), width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Announcement card
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final bool isDark;
  final bool isUnread;
  final String timeLabel;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1565C0);

  const _AnnouncementCard({
    required this.a,
    required this.isDark,
    required this.isUnread,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isUnread
                ? Border.all(color: _primary.withOpacity(0.4), width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.adminName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primary.withOpacity(0.8),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            a.levelLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}