import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_notifier.dart';
import '../services/notification_store.dart';
import '../utils/responsive.dart';
import 'homescreen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

const _blue = Color(0xFF1565C0);

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late final List<Widget> _screens;

  /// null = use the default for the current screen size.
  double? _sidebarWidth;

  static const double _railWidth = 76;
  static const double _minExpandedWidth = 220;
  static const double _defaultExpandedWidth = 268;
  static const double _collapseThreshold = 150;

  String _name = '';
  String _department = '';
  String _level = '';

  static const _destinations = [
    _NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavDestination(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Timetable',
    ),
    _NavDestination(
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
      label: 'Grades',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      _HomeTab(onNavigate: _goTo),
      const TimetableScreen(),
      const HomeScreen(),
      const SettingsScreen(),
    ];
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile');
    if (raw == null || !mounted) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _name = m['name'] ?? '';
      _department = m['department'] ?? '';
      _level = m['level'] ?? '';
    });
  }

  void _goTo(int i) {
    if (i != _currentIndex) {
      setState(() => _currentIndex = i);
      _loadProfile(); // keeps the sidebar profile fresh after edits
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final content = IndexedStack(index: _currentIndex, children: _screens);

        // ── Phone: bottom navigation (unchanged) ──────────────
        if (width < Breakpoints.medium) {
          return Scaffold(
            body: content,
            bottomNavigationBar: _buildBottomNav(isDark),
          );
        }

        // ── Tablet / desktop / web: resizable sidebar ─────────
        final maxW = width * 0.45 < 380 ? width * 0.45 : 380.0;
        final defaultW = width >= Breakpoints.expanded
            ? _defaultExpandedWidth
            : _railWidth;
        final sw = ((_sidebarWidth ?? defaultW).clamp(_railWidth, maxW))
            .toDouble();
        final collapsed = sw < _collapseThreshold;

        final sidebarBg = isDark
            ? const Color(0xFF0D1B2A)
            : const Color(0xFFE9EDF4);
        final panelBg = isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF7F8FA);

        final subtitleParts = [
          if (_level.isNotEmpty) '$_level Level',
          if (_department.isNotEmpty) _department,
        ];

        return Scaffold(
          backgroundColor: sidebarBg,
          body: Row(
            children: [
              SizedBox(
                width: sw,
                child: _Sidebar(
                  destinations: _destinations,
                  currentIndex: _currentIndex,
                  collapsed: collapsed,
                  isDark: isDark,
                  background: sidebarBg,
                  name: _name,
                  subtitle: subtitleParts.isEmpty
                      ? 'SchoolLife'
                      : subtitleParts.join(' · '),
                  onTap: _goTo,
                  onToggle: () => setState(
                    () => _sidebarWidth = collapsed
                        ? _defaultExpandedWidth
                        : _railWidth,
                  ),
                ),
              ),
              _ResizeHandle(
                isDark: isDark,
                onDrag: (dx) => setState(
                  () => _sidebarWidth = (sw + dx).clamp(_railWidth, maxW).toDouble(),
                ),
                onDragEnd: () => setState(() {
                  final w = _sidebarWidth ?? sw;
                  if (w < _collapseThreshold) {
                    _sidebarWidth = _railWidth;
                  } else if (w < _minExpandedWidth) {
                    _sidebarWidth = _minExpandedWidth;
                  }
                }),
                onDoubleTap: () => setState(
                  () => _sidebarWidth = collapsed
                      ? _defaultExpandedWidth
                      : _railWidth,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B2A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                _NavItem(
                  index: i,
                  currentIndex: _currentIndex,
                  destination: _destinations[i],
                  onTap: _goTo,
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SIDEBAR (tablet / desktop / web)
// ══════════════════════════════════════════════════════════
class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.showText});

  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'SCHOOLLIFE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.currentIndex,
    required this.collapsed,
    required this.isDark,
    required this.background,
    required this.name,
    required this.subtitle,
    required this.onTap,
    required this.onToggle,
  });

  final List<_NavDestination> destinations;
  final int currentIndex;
  final bool collapsed;
  final bool isDark;
  final Color background;
  final String name;
  final String subtitle;
  final ValueChanged<int> onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white54 : Colors.black54;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    final toggle = Tooltip(
      message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );

    final avatar = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );

    return SafeArea(
      right: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(collapsed ? 12 : 14, 14, 6, 12),
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            // ── Top: brand + collapse toggle ──
            if (collapsed) ...[
              const _BrandMark(showText: false),
              const SizedBox(height: 8),
              toggle,
            ] else
              Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _BrandMark(showText: true),
                      ),
                    ),
                  ),
                  toggle,
                ],
              ),
            const SizedBox(height: 20),

            // ── Navigation (starts at the top) ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: collapsed
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _SidebarItem(
                        destination: destinations[i],
                        isActive: i == currentIndex,
                        isDark: isDark,
                        collapsed: collapsed,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),

            // ── Bottom: profile + notifications ──
            Divider(
              height: 20,
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
            ),
            if (collapsed) ...[
              _BellButton(isDark: isDark, badgeBorder: background, size: 40),
              const SizedBox(height: 10),
              Tooltip(
                message: name.isNotEmpty ? name : 'Settings',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onTap(3),
                  child: avatar,
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onTap(3),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              avatar,
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isNotEmpty ? name : 'Student',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _BellButton(
                    isDark: isDark,
                    badgeBorder: background,
                    size: 40,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.isActive,
    required this.isDark,
    required this.collapsed,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final bool isDark;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;
    final color = isActive ? _blue : inactiveColor;
    final icon = Icon(
      isActive ? destination.activeIcon : destination.icon,
      color: color,
      size: 22,
    );

    final item = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: collapsed ? 48 : null,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14),
          decoration: BoxDecoration(
            color: isActive ? _blue.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: collapsed
              ? Center(child: icon)
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: collapsed
          ? Tooltip(
              message: destination.label,
              preferBelow: false,
              child: item,
            )
          : item,
    );
  }
}

/// Thin draggable strip between the sidebar and the content panel.
/// Drag to resize, double-click/tap to collapse or expand.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.isDark,
    required this.onDrag,
    required this.onDragEnd,
    required this.onDoubleTap,
  });

  final bool isDark;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd();
        },
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          width: 10,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              height: active ? 56 : 0,
              decoration: BoxDecoration(
                color: _dragging
                    ? _blue
                    : (widget.isDark ? Colors.white30 : Colors.black26),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Notification bell with unread badge (used in the header and sidebar).
class _BellButton extends StatelessWidget {
  const _BellButton({
    required this.isDark,
    required this.badgeBorder,
    this.size = 42,
  });

  final bool isDark;
  final Color badgeBorder;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationStore>(
      builder: (context, store, _) {
        final count = store.unreadCount;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: _blue,
                    size: 21,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeBorder, width: 2),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HOME TAB
// ══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _name = '';
  String _department = '';
  String _level = '';
  String _school = '';

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile');
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name = m['name'] ?? '';
        _department = m['department'] ?? '';
        _level = m['level'] ?? '';
        _school = m['school'] ?? '';
      });
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName => _name.split(' ').first;

  String get _dateLabel {
    final n = DateTime.now();
    return '${_weekdays[n.weekday - 1]}, ${n.day} ${_months[n.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= Breakpoints.expanded;
    final showBrand = screenWidth < Breakpoints.medium;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cw = constraints.maxWidth;

            if (isDesktop) {
              return _desktopHome(
                cw: cw,
                isDark: isDark,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              );
            }

            // ── Phone / tablet layout ───────────────────────
            final sidePad = responsiveSidePadding(cw);
            final narrow = cw < 600;
            final threeInfoCards = cw >= 640;
            final tipColumns = cw >= 700 ? 2 : 1;

            final greetingBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: TextStyle(fontSize: 15, color: textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName.isNotEmpty ? _firstName : 'Student',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            );

            final infoCards = [
              _infoCard(
                icon: Icons.account_balance_outlined,
                label: 'Department',
                value: _department.isNotEmpty ? _department : '—',
                color: const Color(0xFF0891B2),
                cardBg: cardBg,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _infoCard(
                icon: Icons.stairs_outlined,
                label: 'Level',
                value: _level.isNotEmpty ? '$_level Level' : '—',
                color: const Color(0xFF7C3AED),
                cardBg: cardBg,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _infoCard(
                icon: Icons.account_balance_rounded,
                label: 'School',
                value: _school.isNotEmpty ? _school : '—',
                color: _blue,
                cardBg: cardBg,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                fullWidth: true,
              ),
            ];

            final actions = [
              _quickAction(
                icon: Icons.calendar_month_rounded,
                label: 'Timetable',
                color: _blue,
                textPrimary: textPrimary,
                onTap: () => widget.onNavigate(1),
              ),
              _quickAction(
                icon: Icons.school_rounded,
                label: 'Grades',
                color: const Color(0xFF0891B2),
                textPrimary: textPrimary,
                onTap: () => widget.onNavigate(2),
              ),
              _quickAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                color: const Color(0xFF7C3AED),
                textPrimary: textPrimary,
                onTap: () => widget.onNavigate(3),
              ),
            ];

            return ListView(
              padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 32),
              children: [
                // ── Header ────────────────────────────────
                if (showBrand) ...[
                  Row(
                    children: [
                      const _BrandMark(showText: true),
                      const Spacer(),
                      _BellButton(isDark: isDark, badgeBorder: bg),
                    ],
                  ),
                  const SizedBox(height: 24),
                  greetingBlock,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: greetingBlock),
                      _BellButton(isDark: isDark, badgeBorder: bg),
                    ],
                  ),
                const SizedBox(height: 20),

                // ── Blue gradient CTA banner ──────────────
                _TapScale(
                  onTap: () => widget.onNavigate(2),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(narrow ? 20 : 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check your grades',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                narrow
                                    ? 'See your latest results\nand track your progress'
                                    : 'See your latest results and track your progress',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Quick Actions (circle style) ──────────
                _sectionTitle('Quick Actions', textPrimary),
                const SizedBox(height: 14),
                if (narrow)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: actions,
                  )
                else
                  Wrap(spacing: 44, runSpacing: 16, children: actions),
                const SizedBox(height: 28),

                // ── Academic Info ─────────────────────────
                _sectionTitle('Academic Info', textPrimary),
                const SizedBox(height: 14),
                if (threeInfoCards)
                  ResponsiveGrid(columns: 3, children: infoCards)
                else ...[
                  ResponsiveGrid(columns: 2, children: infoCards.sublist(0, 2)),
                  const SizedBox(height: 14),
                  infoCards[2],
                ],
                const SizedBox(height: 28),

                // ── Tips ───────────────────────────────────
                _sectionTitle('Study Tips', textPrimary),
                const SizedBox(height: 12),
                ResponsiveGrid(
                  columns: tipColumns,
                  spacing: 12,
                  runSpacing: 12,
                  children: _tips(isDark),
                ),

                if (kIsWeb) _downloadApkButton(isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  DESKTOP DASHBOARD
  // ════════════════════════════════════════════════════════
  Widget _desktopHome({
    required double cw,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final sidePad = responsiveSidePadding(cw, maxWidth: 1280);
    final twoCol = cw >= 900;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'S';

    // ── Greeting header ──
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: TextStyle(fontSize: 16, color: textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                _firstName.isNotEmpty ? _firstName : 'Student',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _cardShadow(isDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.today_rounded, size: 16, color: _blue),
              const SizedBox(width: 8),
              Text(
                _dateLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // ── Hero banner ──
    final hero = _TapScale(
      onTap: () => widget.onNavigate(2),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _blue.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              right: 110,
              bottom: -90,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check your grades',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'See your latest results and track your progress',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View grades',
                                style: TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: _blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cw >= 760)
                    Icon(
                      Icons.school_rounded,
                      size: 104,
                      color: Colors.white.withOpacity(0.25),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ── Quick action cards ──
    final actionCards = [
      _desktopActionCard(
        icon: Icons.calendar_month_rounded,
        label: 'Timetable',
        desc: 'Lectures, study sessions & exams',
        color: _blue,
        cardBg: cardBg,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        onTap: () => widget.onNavigate(1),
      ),
      _desktopActionCard(
        icon: Icons.school_rounded,
        label: 'Grades',
        desc: 'Results and progress',
        color: const Color(0xFF0891B2),
        cardBg: cardBg,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        onTap: () => widget.onNavigate(2),
      ),
      _desktopActionCard(
        icon: Icons.settings_rounded,
        label: 'Settings',
        desc: 'Profile and preferences',
        color: const Color(0xFF7C3AED),
        cardBg: cardBg,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        onTap: () => widget.onNavigate(3),
      ),
    ];

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hero,
        const SizedBox(height: 30),
        _sectionTitle('Quick Actions', textPrimary),
        const SizedBox(height: 14),
        ResponsiveGrid(minItemWidth: 210, children: actionCards),
        const SizedBox(height: 30),
        _sectionTitle('Study Tips', textPrimary),
        const SizedBox(height: 14),
        ResponsiveGrid(
          minItemWidth: 300,
          spacing: 14,
          runSpacing: 14,
          children: _tips(isDark),
        ),
      ],
    );

    // ── Right panel: profile + academic info ──
    final profile = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? _name : 'Student',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _level.isNotEmpty ? '$_level Level' : 'SchoolLife',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.07),
          ),
          const SizedBox(height: 16),
          Text(
            'ACADEMIC INFO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _profileRow(
            icon: Icons.account_balance_outlined,
            label: 'Department',
            value: _department.isNotEmpty ? _department : '—',
            color: const Color(0xFF0891B2),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),
          _profileRow(
            icon: Icons.stairs_outlined,
            label: 'Level',
            value: _level.isNotEmpty ? '$_level Level' : '—',
            color: const Color(0xFF7C3AED),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),
          _profileRow(
            icon: Icons.account_balance_rounded,
            label: 'School',
            value: _school.isNotEmpty ? _school : '—',
            color: _blue,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );

    final download = kIsWeb
        ? Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _cardShadow(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.android_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get the Android app',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Take SchoolLife with you',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _downloadApkButton(isDark, top: 16),
              ],
            ),
          )
        : const SizedBox.shrink();

    final side = Column(
      children: [
        profile,
        if (kIsWeb) ...[const SizedBox(height: 18), download],
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(sidePad, 28, sidePad, 40),
      children: [
        header,
        const SizedBox(height: 26),
        if (twoCol)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 28),
              SizedBox(width: 340, child: side),
            ],
          )
        else ...[
          main,
          const SizedBox(height: 28),
          side,
        ],
      ],
    );
  }

  List<BoxShadow> _cardShadow(bool isDark) => [
    BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  Widget _sectionTitle(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
  );

  Widget _desktopActionCard({
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
    required Color cardBg,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        hoverColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow(isDark),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return _TapScale(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardBg,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadApkButton(bool isDark, {double top = 28}) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: EdgeInsets.only(top: top),
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            // NOTE: backend URL and APK file name are unchanged on purpose.
            // Update them only after the server side is renamed too.
            final uri = Uri.parse(
              'https://gradexbackend.onrender.com/downloads/gradex.apk',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, webOnlyWindowName: '_self');
            }
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text(
            'Download SchoolLife for Android',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ),
    ),
  );

  List<Widget> _tips(bool isDark) {
    const tips = [
      (
        '📚',
        'Review your notes within 24 hours of class to retain 80% more information.',
      ),
      ('⏰', 'Use the Pomodoro technique: 25 min focused study, 5 min break.'),
      (
        '🎯',
        'Set specific daily study goals instead of vague "study more" intentions.',
      ),
      (
        '💤',
        'Sleep at least 7 hours — memory consolidation happens during sleep.',
      ),
    ];

    return tips
        .map(
          (t) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                Text(t.$1, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

// ══════════════════════════════════════════════════════════
//  BOTTOM NAV ITEM (phone)
// ══════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final _NavDestination destination;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.destination,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    const activeColor = _blue;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? destination.activeIcon : destination.icon,
                  key: ValueKey(isActive),
                  color: isActive ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(destination.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.97),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}