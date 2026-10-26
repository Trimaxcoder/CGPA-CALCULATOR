import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_notifier.dart';
import '../utils/responsive.dart';
import '../widgets/animations.dart';
import '../widgets/brand_widgets.dart';
import 'home_dashboard.dart';
import 'homescreen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import '../widgets/snackBar.dart';
import 'class_workspace_screen.dart';

const _blue = Color(0xFF1565C0);

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final List<Widget> _screens;

  // Keeps every tab's state alive when the layout switches between the
  // phone (bottom bar) and wide (sidebar) versions, e.g. on window resize
  // or device rotation.
  final GlobalKey _contentKey = GlobalKey();

  // soft fade + slide whenever the tab changes (IndexedStack keeps state)
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final Animation<double> _tabFade = CurvedAnimation(
    parent: _tabAnim,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _tabSlide = Tween<Offset>(
    begin: const Offset(0, 0.025),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _tabAnim, curve: Curves.easeOutCubic));

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
    // clamp so a bad index from a notification route can't crash IndexedStack
    _currentIndex = widget.initialIndex.clamp(0, _destinations.length - 1);
    _screens = [
      HomeDashboard(onNavigate: _goTo),
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

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i != _currentIndex) {
      setState(() => _currentIndex = i);
      _tabAnim.forward(from: 0);
      _loadProfile(); // keeps the sidebar profile fresh after edits
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final content = FadeTransition(
          key: _contentKey, // preserves screen state across layout switches
          opacity: _tabFade,
          child: SlideTransition(
            position: _tabSlide,
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        );

        // ── Phone: bottom navigation (unchanged) ──────────────
        if (width < Breakpoints.medium) {
          return _buildPhone(context, isDark, content);
        }

        // ── Tablet / desktop / web: resizable sidebar ─────────
        final maxW = width * 0.45 < 380 ? width * 0.45 : 380.0;
        // full sidebar only when there is room; 600–1179 px starts as a rail
        final defaultW = width >= 1180 ? _defaultExpandedWidth : _railWidth;
        final sw = ((_sidebarWidth ?? defaultW).clamp(
          _railWidth,
          maxW,
        )).toDouble();
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
                  onMore: _showMoreSheet,
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
                  () => _sidebarWidth = (sw + dx)
                      .clamp(_railWidth, maxW)
                      .toDouble(),
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

  // ══════════════════════════════════════════════════════════
  //  PHONE LAYOUT: black bottom bar with a raised center button
  // ══════════════════════════════════════════════════════════
  static const double _barH = 66; // bar height (without the safe area)
  static const double _bump = 32; // how far the center button rises

  Widget _buildPhone(BuildContext context, bool isDark, Widget content) {
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final inset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: bg,
      // the bar floats over the page, so the page must not resize for the
      // keyboard (child screens still receive the keyboard insets)
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard ? 0 : _barH + inset),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: content,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: keyboard ? const Offset(0, 1.3) : Offset.zero,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _buildBottomNav(inset, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(double inset, bool isDark) {
    final barTotal = _barH + inset;
    return SizedBox(
      height: barTotal + _bump,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // black bar with a curved notch around the center button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barTotal,
            child: CustomPaint(
              painter: _NavBarPainter(isDark: isDark),
              child: Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      _BarItem(
                        destination: _destinations[i],
                        active: i == _currentIndex,
                        isDark: isDark,
                        onTap: () => _goTo(i),
                      ),
                    const SizedBox(width: 104), // room for the notch
                    for (var i = 2; i < 4; i++)
                      _BarItem(
                        destination: _destinations[i],
                        active: i == _currentIndex,
                        isDark: isDark,
                        onTap: () => _goTo(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // raised "more" button
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _MoreButton(onTap: _showMoreSheet),
            ),
          ),
        ],
      ),
    );
  }

  /// Features that live behind the center button.
  /// Phone: bottom sheet. Tablet / desktop / web: centered dialog.
  void _showMoreSheet() {
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    final card = isDark ? const Color(0xFF15181D) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    // (icon, label, color, onTap). A null onTap shows the SOON badge.
    final List<(IconData, String, Color, VoidCallback?)> items = [
      (
        Icons.group_add_rounded,
        'Join a class',
        const Color(0xFF1565C0),
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ClassWorkspaceScreen())),
      ),
      (Icons.forum_rounded, 'Communities', const Color(0xFF7C3AED), null),
      (Icons.how_to_reg_rounded, 'Attendance', const Color(0xFF0891B2), null),
      (Icons.assignment_rounded, 'Assignments', const Color(0xFF1E88E5), null),
    ];

    // Shared content, used by both the phone sheet and the wide dialog.
    Widget buildContent(BuildContext ctx) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, isWide ? 22 : 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isWide) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'More',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'New features are on the way',
                        style: TextStyle(fontSize: 13, color: sub),
                      ),
                    ],
                  ),
                ),
                if (isWide)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: sub),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 92, // fixed height, never grows with width
              ),
              itemBuilder: (_, i) {
                final it = items[i];
                return PressScale(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (it.$4 != null) {
                      it.$4!();
                    } else {
                      AppSnackBar.auto(context, '${it.$2} is coming soon');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: it.$3.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: it.$3.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(it.$1, color: it.$3, size: 24),
                            const Spacer(),
                            if (it.$4 == null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: it.$3.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'SOON',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: it.$3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          it.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // ── Tablet / desktop / web: centered dialog with a max width ──
    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: buildContent(ctx),
          ),
        ),
      );
      return;
    }

    // ── Phone: bottom sheet ──
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(child: buildContent(ctx)),
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
    required this.onMore,
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
  final VoidCallback onMore;

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
              const BrandMark(showText: false),
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
                        child: BrandMark(showText: true),
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
                    const SizedBox(height: 14),
                    _SidebarMore(collapsed: collapsed, onTap: onMore),
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
              BellButton(isDark: isDark, badgeBorder: background, size: 40),
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
                  BellButton(isDark: isDark, badgeBorder: background, size: 40),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "More" entry of the sidebar — same job as the raised button on phones.
class _SidebarMore extends StatelessWidget {
  const _SidebarMore({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
    );

    if (collapsed) {
      return Center(
        child: Tooltip(
          message: 'More',
          preferBelow: false,
          child: PressScale(
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.apps_rounded, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return PressScale(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.apps_rounded, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'More',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 20,
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
          ? Tooltip(message: destination.label, preferBelow: false, child: item)
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

// ══════════════════════════════════════════════════════════
//  BOTTOM BAR PIECES (phone)
// ══════════════════════════════════════════════════════════

/// Black bar: rounded top corners + a smooth notch for the center button.
class _NavBarPainter extends CustomPainter {
  _NavBarPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 28.0; // top corner radius
    const half = 50.0; // half width of the notch
    const depth = 42.0; // notch depth
    final w = size.width, h = size.height, cx = w / 2;

    final path = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cx - half - 18, 0)
      ..cubicTo(cx - half + 4, 0, cx - half + 2, depth, cx, depth)
      ..cubicTo(cx + half - 2, depth, cx + half - 4, 0, cx + half + 18, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    // white bar in the light theme, black bar in the dark theme
    canvas.drawShadow(path, Colors.black, isDark ? 12 : 10, true);
    canvas.drawPath(
      path,
      Paint()..color = isDark ? Colors.black : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_NavBarPainter old) => old.isDark != isDark;
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final color = active ? _accent : (isDark ? Colors.white54 : Colors.black45);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? _accent.withOpacity(0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedScale(
                scale: active ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  active ? destination.activeIcon : destination.icon,
                  color: color,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(destination.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised center button with a slow breathing glow.
class _MoreButton extends StatefulWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: widget.onTap,
      pressedScale: 0.92,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF1E88E5,
                ).withOpacity(0.25 + 0.25 * _c.value),
                blurRadius: 14 + 10 * _c.value,
                spreadRadius: 1 + 2 * _c.value,
              ),
            ],
          ),
          child: child,
        ),
        child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}