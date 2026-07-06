import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/theme_notifier.dart';
import '../services/notification_store.dart';
import 'homescreen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  static const _screens = [
    _HomeTab(),
    TimetableScreen(),
    HomeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    // NEW
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(isDark),
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
              _NavItem(
                index: 0,
                currentIndex: _currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                onTap: (i) => setState(() => _currentIndex = i),
                isDark: isDark,
              ),
              _NavItem(
                index: 1,
                currentIndex: _currentIndex,
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month_rounded,
                label: 'Timetable',
                onTap: (i) => setState(() => _currentIndex = i),
                isDark: isDark,
              ),
              _NavItem(
                index: 2,
                currentIndex: _currentIndex,
                icon: Icons.school_outlined,
                activeIcon: Icons.school_rounded,
                label: 'Grades',
                onTap: (i) => setState(() => _currentIndex = i),
                isDark: isDark,
              ),
              _NavItem(
                index: 3,
                currentIndex: _currentIndex,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                onTap: (i) => setState(() => _currentIndex = i),
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
//  HOME TAB
// ══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _name = '';
  String _department = '';
  String _level = '';
  String _school = '';

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



@override
Widget build(BuildContext context) {
  final isDark = context.watch<ThemeNotifier>().isDarkMode;
  final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
  final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
  final textPrimary = isDark ? Colors.white : Colors.black87;
  final textSecondary = isDark ? Colors.white54 : Colors.black45;

  return Scaffold(
    backgroundColor: bg,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // ── Brand + bell ──────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'GRADEX',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              Consumer<NotificationStore>(
                builder: (context, store, _) {
                  final count = store.unreadCount;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF1565C0),
                            size: 21,
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: bg, width: 2),
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
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Greeting ──────────────────────────────
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
          const SizedBox(height: 20),

          // ── Blue gradient CTA banner ──────────────
          _TapScale(
            onTap: () {
              final shell = context.findAncestorStateOfType<_MainShellState>();
              shell?.setState(() => shell._currentIndex = 2);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.35),
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
                        const Text(
                          'See your latest results\nand track your progress',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
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
                    child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Quick Actions (circle style) ──────────
          Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickAction(
                icon: Icons.calendar_month_rounded,
                label: 'Timetable',
                color: const Color(0xFF1565C0),
                textPrimary: textPrimary,
                onTap: () {
                  final shell = context.findAncestorStateOfType<_MainShellState>();
                  shell?.setState(() => shell._currentIndex = 1);
                },
              ),
              _quickAction(
                icon: Icons.school_rounded,
                label: 'Grades',
                color: const Color(0xFF0891B2),
                textPrimary: textPrimary,
                onTap: () {
                  final shell = context.findAncestorStateOfType<_MainShellState>();
                  shell?.setState(() => shell._currentIndex = 2);
                },
              ),
              _quickAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                color: const Color(0xFF7C3AED),
                textPrimary: textPrimary,
                onTap: () {
                  final shell = context.findAncestorStateOfType<_MainShellState>();
                  shell?.setState(() => shell._currentIndex = 3);
                },
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Academic Info grid ────────────────────
          Text(
            'Academic Info',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.account_balance_outlined,
                  label: 'Department',
                  value: _department.isNotEmpty ? _department : '—',
                  color: const Color(0xFF0891B2),
                  cardBg: cardBg,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _infoCard(
                  icon: Icons.stairs_outlined,
                  label: 'Level',
                  value: _level.isNotEmpty ? '$_level Level' : '—',
                  color: const Color(0xFF7C3AED),
                  cardBg: cardBg,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoCard(
            icon: Icons.account_balance_rounded,
            label: 'School',
            value: _school.isNotEmpty ? _school : '—',
            color: const Color(0xFF1565C0),
            cardBg: cardBg,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            fullWidth: true,
          ),
          const SizedBox(height: 28),

          // ── Tips ───────────────────────────────────
          Text(
            'Study Tips',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 12),
          ..._tips(isDark),

          if (kIsWeb) _downloadApkButton(isDark),
        ],
      ),
    ),
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
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
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _downloadApkButton(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 28),
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(
          'https://gradexbackend.onrender.com/downloads/gradex.apk',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, webOnlyWindowName: '_self');
        }
      },
      icon: const Icon(Icons.download_rounded),
      label: const Text(
        'Download GradeX for Android',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),
  );

  List<Widget> _tips(bool isDark) {
    final tips = [
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
            margin: const EdgeInsets.only(bottom: 10),
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
//  NAV ITEM
// ══════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final activeColor = const Color(0xFF1565C0);
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
                  isActive ? activeIcon : icon,
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
              child: Text(label),
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
