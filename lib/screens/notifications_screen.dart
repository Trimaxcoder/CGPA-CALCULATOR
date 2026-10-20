// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_store.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';
import '../stores/announcement_store.dart';
import '../services/notification_router.dart';
import '../providers/theme_notifier.dart';
import '../utils/responsive.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/desktop_page.dart';
import 'announcement_detail_screen.dart';
import '../widgets/page_header.dart';

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
    // lets the desktop segmented control follow the controller
    _tab.addListener(() {
      if (mounted && !_tab.indexIsChanging) setState(() {});
    });

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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'class_reminder':
        return Icons.access_time_filled_rounded;
      case 'emergency_toggle':
        return Icons.warning_amber_rounded;
      case 'test_toggle':
        return Icons.quiz_rounded;
      case 'attendance_toggle':
        return Icons.how_to_reg_rounded;
      case 'cancelled_toggle':
        return Icons.block_rounded;
      case 'important_class':
        return Icons.push_pin_rounded;
      case 'exam_added':
        return Icons.event_note_rounded;
      case 'admin_approved':
        return Icons.verified_rounded;
      case 'admin_rejected':
        return Icons.cancel_rounded;
      case 'admin_revoked':
        return Icons.gpp_bad_rounded;
      case 'morning_digest':
        return Icons.wb_sunny_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final notifStore = context.watch<NotificationStore>();
    final annStore = context.watch<AnnouncementStore>();

    // ── Desktop: title + segmented switch, centered list ────
    if (context.isExpanded) {
      final unreadN = notifStore.unreadCount;
      final unreadA = annStore.unreadCount;
      return DesktopPage(
        title: 'Notifications',
        subtitle: (unreadN + unreadA) == 0
            ? 'You\'re all caught up'
            : '$unreadN unread notification${unreadN == 1 ? '' : 's'} · '
                  '$unreadA unread announcement${unreadA == 1 ? '' : 's'}',
        maxWidth: 1100,
        actions: [_segmented(isDark, unreadN, unreadA)],
        child: _tab.index == 0
            ? _NotificationsTab(
                isDark: isDark,
                store: notifStore,
                iconFor: _iconFor,
                timeAgo: _timeAgo,
                desktop: true,
              )
            : _AnnouncementsTab(
                isDark: isDark,
                store: annStore,
                timeAgo: _timeAgo,
                desktop: true,
              ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF7F8FA),
      body: Column(
        children: [
          MobileHeader(
            title: 'Notifications',
            subtitle: _unreadSubtitle(
              notifStore.unreadCount,
              annStore.unreadCount,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _mobileSwitch(
              isDark,
              notifStore.unreadCount,
              annStore.unreadCount,
            ),
          ),
          const SizedBox(height: 10),

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

  String _unreadSubtitle(int n, int a) {
    if (n + a == 0) return 'You\'re all caught up';
    return '$n unread · $a new announcement${a == 1 ? '' : 's'}';
  }

  /// Sliding pill (same style as Timetable / Grades) with unread badges.
  Widget _mobileSwitch(bool isDark, int unreadN, int unreadA) {
    final items = [
      (Icons.notifications_rounded, 'Notifications', unreadN),
      (Icons.campaign_rounded, 'Announcements', unreadA),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / items.length;
        return Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _tab.animation!,
            builder: (context, _) {
              final v = _tab.animation!.value;
              return Stack(
                children: [
                  Positioned(
                    left: v * w,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _tab.animateTo(i),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      items[i].$1,
                                      size: 17,
                                      color: (v - i).abs() < 0.5
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white54
                                                : Colors.black54),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      items[i].$2,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: (v - i).abs() < 0.5
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white54
                                                  : Colors.black54),
                                      ),
                                    ),
                                    if (items[i].$3 > 0) ...[
                                      const SizedBox(width: 6),
                                      _Badge(items[i].$3),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _segmented(bool isDark, int unreadN, int unreadA) {
    final items = [
      (Icons.notifications_rounded, 'Notifications', unreadN),
      (Icons.campaign_rounded, 'Announcements', unreadA),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => setState(() => _tab.index = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: _tab.index == i
                        ? const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 18,
                        color: _tab.index == i
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _tab.index == i
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      if (items[i].$3 > 0) ...[
                        const SizedBox(width: 8),
                        _Badge(items[i].$3),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop action row (mark all read / clear all)
// ─────────────────────────────────────────────────────────────────────────────

Widget _desktopActions({
  required bool isDark,
  required VoidCallback? onMarkAll,
  required VoidCallback onClear,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      DeskButton(
        icon: Icons.done_all_rounded,
        label: 'Mark all as read',
        isDark: isDark,
        onTap: onMarkAll,
      ),
      const SizedBox(width: 10),
      DeskButton(
        icon: Icons.delete_sweep_rounded,
        label: 'Clear all',
        color: Colors.red,
        isDark: isDark,
        onTap: onClear,
      ),
    ],
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 1 — Notifications
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends StatelessWidget {
  final bool isDark;
  final NotificationStore store;
  final IconData Function(String) iconFor;
  final String Function(DateTime) timeAgo;
  final bool desktop;

  static const Color _primary = Color(0xFF1565C0);

  const _NotificationsTab({
    required this.isDark,
    required this.store,
    required this.iconFor,
    required this.timeAgo,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = store.items;

    // ── Desktop: grid of cards with hover-friendly remove button ──
    if (desktop) {
      return Column(
        children: [
          if (items.isNotEmpty)
            _desktopActions(
              isDark: isDark,
              onMarkAll: store.unreadCount == 0 ? null : store.markAllRead,
              onClear: () => _confirmClearAll(context),
            ),
          Expanded(
            child: items.isEmpty
                ? _EmptyState(
                    isDark: isDark,
                    icon: Icons.notifications_none_rounded,
                    label: 'No notifications yet',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      ResponsiveGrid(
                        minItemWidth: 440,
                        spacing: 14,
                        runSpacing: 0,
                        children: [
                          for (final n in items)
                            _NotifCard(
                              n: n,
                              isDark: isDark,
                              icon: iconFor(n.type),
                              timeLabel: timeAgo(n.receivedAt),
                              onTap: () {
                                store.markAsRead(n.id);
                                NotificationRouter.route(n);
                              },
                              onDelete: () => store.remove(n.id),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: store.unreadCount == 0
                        ? null
                        : store.markAllRead,
                    icon: const Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    label: const Text(
                      'Mark all as read',
                      style: TextStyle(color: _primary),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmClearAll(context),
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Clear all',
                      style: TextStyle(color: Colors.red),
                    ),
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
                  onRefresh: () => store.load(),
                )
              : RefreshIndicator(
                  color: const Color(0xFF1565C0),
                  onRefresh: () => store.load(),
                  child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: responsiveSidePadding(
                      MediaQuery.sizeOf(context).width,
                      maxWidth: 720,
                    ),
                    vertical: 8,
                  ),
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
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear all notifications?',
      message: 'This cannot be undone.',
      confirmLabel: 'Clear all',
      icon: Icons.delete_sweep_rounded,
      color: Colors.red,
    );
    if (ok) store.clearAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab 2 — Announcements
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementsTab extends StatelessWidget {
  final bool isDark;
  final AnnouncementStore store;
  final String Function(DateTime) timeAgo;
  final bool desktop;

  static const Color _primary = Color(0xFF1565C0);

  const _AnnouncementsTab({
    required this.isDark,
    required this.store,
    required this.timeAgo,
    this.desktop = false,
  });

  void _open(BuildContext context, Announcement a) {
    store.markRead(a.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: a),
      ),
    );
  }

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
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: store.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = store.items;

    // ── Desktop ────────────────────────────────────────────
    if (desktop) {
      return Column(
        children: [
          if (items.isNotEmpty)
            _desktopActions(
              isDark: isDark,
              onMarkAll: store.unreadCount == 0 ? null : store.markAllRead,
              onClear: () => _confirmClearAll(context),
            ),
          Expanded(
            child: items.isEmpty
                ? _EmptyState(
                    isDark: isDark,
                    icon: Icons.campaign_outlined,
                    label: 'No announcements yet',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      ResponsiveGrid(
                        minItemWidth: 440,
                        spacing: 14,
                        runSpacing: 0,
                        children: [
                          for (final a in items)
                            _AnnouncementCard(
                              a: a,
                              isDark: isDark,
                              isUnread: store.isUnread(a.id),
                              timeLabel: timeAgo(a.createdAt),
                              onTap: () => _open(context, a),
                              onDelete: () => store.hideLocal(a.id),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

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
                    onPressed: store.unreadCount == 0
                        ? null
                        : store.markAllRead,
                    icon: const Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    label: const Text(
                      'Mark all as read',
                      style: TextStyle(color: _primary),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmClearAll(context),
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Clear all',
                      style: TextStyle(color: Colors.red),
                    ),
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
                  onRefresh: store.refresh,
                )
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsiveSidePadding(
                        MediaQuery.sizeOf(context).width,
                        maxWidth: 720,
                      ),
                      vertical: 8,
                    ),
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
                          onTap: () => _open(context, a),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear all announcements?',
      message: 'This only removes them from your view.',
      confirmLabel: 'Clear all',
      icon: Icons.delete_sweep_rounded,
      color: Colors.red,
    );
    if (ok) store.hideAllLocal();
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
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.red.shade400,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Icon(Icons.delete, color: Colors.white),
  );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;

  /// When given, the empty screen can be pulled down to refresh.
  final Future<void> Function()? onRefresh;

  static const Color _primary = Color(0xFF1565C0);

  const _EmptyState({
    required this.isDark,
    required this.icon,
    required this.label,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Widget content() => Center(
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
            child: Icon(icon, size: 44, color: _primary.withOpacity(0.5)),
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

    if (onRefresh == null) return content();

    return RefreshIndicator(
      color: _primary,
      onRefresh: onRefresh!,
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: c.maxHeight < 260 ? 260 : c.maxHeight,
              child: content(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cards
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco(bool isDark, bool highlight) => BoxDecoration(
  color: isDark ? const Color(0xFF15181D) : Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: highlight
      ? Border.all(color: const Color(0xFF1565C0).withOpacity(0.45), width: 1.2)
      : null,
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ],
);

Widget _iconBlock(IconData icon) => Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    color: const Color(0xFF1565C0).withOpacity(0.12),
    borderRadius: BorderRadius.circular(15),
  ),
  child: Icon(icon, color: const Color(0xFF1565C0), size: 23),
);

Widget _unreadDot() => Container(
  width: 9,
  height: 9,
  decoration: const BoxDecoration(
    color: Color(0xFF1565C0),
    shape: BoxShape.circle,
  ),
);

Widget _removeButton(bool isDark, VoidCallback onDelete) => IconButton(
  tooltip: 'Remove',
  icon: Icon(
    Icons.close_rounded,
    size: 18,
    color: isDark ? Colors.white38 : Colors.black38,
  ),
  visualDensity: VisualDensity.compact,
  onPressed: onDelete,
);

class _NotifCard extends StatelessWidget {
  final AppNotification n;
  final bool isDark;
  final IconData icon;
  final String timeLabel;
  final VoidCallback onTap;

  /// Desktop only: shows a remove button (phones swipe to dismiss).
  final VoidCallback? onDelete;

  const _NotifCard({
    required this.n,
    required this.isDark,
    required this.icon,
    required this.timeLabel,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black54;
    final faint = isDark ? Colors.white38 : Colors.black38;

    return FadeSlideIn(
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(isDark, !n.isRead),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBlock(icon),
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
                              fontWeight: n.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              fontSize: 14.5,
                              color: text,
                            ),
                          ),
                        ),
                        if (!n.isRead) _unreadDot(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: sub),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: faint),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(fontSize: 11, color: faint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null) _removeButton(isDark, onDelete!),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final bool isDark;
  final bool isUnread;
  final String timeLabel;
  final VoidCallback onTap;

  /// Desktop only: shows a remove button (phones swipe to dismiss).
  final VoidCallback? onDelete;

  const _AnnouncementCard({
    required this.a,
    required this.isDark,
    required this.isUnread,
    required this.timeLabel,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1565C0);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black54;
    final faint = isDark ? Colors.white38 : Colors.black38;

    return FadeSlideIn(
      child: PressScale(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(isDark, isUnread),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBlock(Icons.campaign_rounded),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              fontSize: 14.5,
                              color: text,
                            ),
                          ),
                        ),
                        if (isUnread) _unreadDot(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: blue.withOpacity(0.85),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            a.levelLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: blue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: sub),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: faint),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(fontSize: 11, color: faint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null) _removeButton(isDark, onDelete!),
            ],
          ),
        ),
      ),
    );
  }
}