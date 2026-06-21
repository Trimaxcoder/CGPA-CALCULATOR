import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../providers/theme_notifier.dart';
import '../services/notification_store.dart';
import 'homescreen.dart';
import 'timetable_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart'; 

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0; // 0 = Home (default)

  static const _screens = [
    _HomeTab(),
    TimetableScreen(),
    HomeScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
        _name       = m['name']       ?? '';
        _department = m['department'] ?? '';
        _level      = m['level']      ?? '';
        _school     = m['school']     ?? '';
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
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8);
    final cardBg = isDark ? Colors.black : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Fixed gradient header ────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // G logo
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1565C0),
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'GRADEX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const Spacer(),
                        // Notification bell
                      // Notification bell with badge
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
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
                  border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
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
                    const SizedBox(height: 28),
                    Text(
                      '$_greeting,',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _firstName.isNotEmpty ? _firstName : 'Student',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Student info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_level.isNotEmpty) _infoChip(Icons.stairs_outlined, '$_level Level'),
                        if (_department.isNotEmpty) _infoChip(Icons.school_outlined, _department),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scrollable content below the fixed header ────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: [
                // ── Quick Actions ───────────────────────────
                Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'Timetable',
                      color: const Color(0xFF1565C0),
                      isDark: isDark,
                      onTap: () {
                        final shell = context.findAncestorStateOfType<_MainShellState>();
                        shell?.setState(() => shell._currentIndex = 1);
                      },
                    ),
                    const SizedBox(width: 12),
                    _quickAction(
                      icon: Icons.school_rounded,
                      label: 'Grades',
                      color: const Color(0xFF0891B2),
                      isDark: isDark,
                      onTap: () {
                        final shell = context.findAncestorStateOfType<_MainShellState>();
                        shell?.setState(() => shell._currentIndex = 2);
                      },
                    ),
                    const SizedBox(width: 12),
                    _quickAction(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                      onTap: () {
                        final shell = context.findAncestorStateOfType<_MainShellState>();
                        shell?.setState(() => shell._currentIndex = 3);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Academic Info Card ──────────────────────
                Text(
                  'Academic Info',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.account_balance_rounded, 'School', _school.isNotEmpty ? _school : '—', isDark),
                      const SizedBox(height: 16),
                      _infoRow(Icons.account_balance_outlined, 'Department', _department.isNotEmpty ? _department : '—', isDark),
                      const SizedBox(height: 16),
                      _infoRow(Icons.stairs_outlined, 'Level', _level.isNotEmpty ? '$_level Level' : '—', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Tips Card ───────────────────────────────
                Text(
                  'Study Tips',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 12),
                ..._tips(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 13),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value, bool isDark) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
              ],
            ),
          ),
        ],
      );

  List<Widget> _tips(bool isDark) {
    final tips = [
      ('📚', 'Review your notes within 24 hours of class to retain 80% more information.'),
      ('⏰', 'Use the Pomodoro technique: 25 min focused study, 5 min break.'),
      ('🎯', 'Set specific daily study goals instead of vague "study more" intentions.'),
      ('💤', 'Sleep at least 7 hours — memory consolidation happens during sleep.'),
    ];

    return tips.map((t) => Container(
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
            child: Text(t.$2,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                )),
          ),
        ],
      ),
    )).toList();
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
    final inactiveColor =
        isDark ? Colors.white38 : Colors.black38;

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
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}