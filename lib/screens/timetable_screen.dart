import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_notifier.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_service.dart';
import 'super_admin_screen.dart';
import '../services/muted_courses_store.dart';
import '../utils/responsive.dart';
import '../widgets/snackBar.dart';
import '../services/notification_service.dart';
import 'compose_announcement_screen.dart';
import '../widgets/animations.dart';
import '../widgets/class_card.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with TickerProviderStateMixin {
  late TabController _typeTabCtrl; // Lecture / Personal / Exam
  late TabController _dayTabCtrl;
  late PageController _lecturePageCtrl;
  late PageController _personalPageCtrl; // Mon–Sun

  List<LectureEntry> _lectures = [];
  List<LectureEntry> _exams = [];
  List<PersonalEntry> _personal = [];

  bool _loading = true;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  static const Color _primary = Color(0xFF1565C0);

  /// Max width of the timetable content on big screens.
  static const double _contentMaxWidth = 1100;

  /// Bottom sheets stay phone-sized (centered) on wide screens.
  static const BoxConstraints _sheetConstraints = BoxConstraints(
    maxWidth: 560,
  );

  Map<String, Map<String, dynamic>> _reminders = {};

  String _school = '', _faculty = '', _department = '', _level = '';

  final _svc = TimetableService();

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _dayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  int get _todayIndex {
    final wd = DateTime.now().weekday; // 1=Mon … 7=Sun
    return wd - 1;
  }

  @override
  void initState() {
    super.initState();
    _typeTabCtrl = TabController(length: 3, vsync: this);
    _typeTabCtrl.addListener(() {
      if (mounted && !_typeTabCtrl.indexIsChanging) setState(() {});
    });
    _dayTabCtrl = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: _todayIndex,
    );
    _dayTabCtrl.addListener(() {
      if (!_dayTabCtrl.indexIsChanging) setState(() {});
    });
    _lecturePageCtrl = PageController(initialPage: _todayIndex);
    _personalPageCtrl = PageController(initialPage: _todayIndex);
    _loadAll();
  }

  @override
  void dispose() {
    _typeTabCtrl.dispose();
    _dayTabCtrl.dispose();
    _lecturePageCtrl.dispose();
    _personalPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadProfile();
    await Future.wait([_loadLectures(), _loadExams(), _loadPersonal()]);
    await _checkAdminStatus();
    await _loadReminders();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('profile');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _school = decoded['school'] ?? '';
        _faculty = decoded['faculty'] ?? '';
        _department = decoded['department'] ?? '';
        _level = decoded['level'] ?? '';
      }
    } catch (_) {}
  }

  Future<void> _loadLectures() async {
    try {
      final list = await _svc.getLectures();
      _lectures = list.map(LectureEntry.fromMap).toList();
    } catch (_) {}
  }

  Future<void> _loadExams() async {
    try {
      final list = await _svc.getExams();
      _exams = list.map(LectureEntry.fromMap).toList();
    } catch (_) {}
  }

  Future<void> _loadPersonal() async {
    try {
      final list = await _svc.getPersonal();
      _personal = list.map(PersonalEntry.fromMap).toList();

      for (final entry in _personal.where((e) => e.isBookmarked)) {
        await NotificationService.scheduleStudyReminder(
          entryId: entry.id,
          title: entry.title,
          day: entry.day,
          startTime: entry.startTime,
        );
      }
    } catch (_) {}
  }

  Future<void> _checkAdminStatus() async {
    try {
      final res = await _svc.getAdminStatus();
      print('ADMIN STATUS: $res');
      if (mounted)
        setState(() {
          _isAdmin = res['isAdmin'] ?? false;
          _isSuperAdmin = res['isSuperAdmin'] ?? false;
        });
    } catch (_) {}
  }

  Future<void> _loadReminders() async {
    try {
      final list = await _svc.getReminders();
      final map = <String, Map<String, dynamic>>{};
      for (final r in list) {
        final lectureId = r['lecture'] is Map
            ? r['lecture']['_id']
            : r['lecture'];
        map[lectureId] = r;
      }
      if (mounted) setState(() => _reminders = map);
    } catch (_) {}
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _toggleAlert(String id, String type) async {
    try {
      if (type == 'emergency') {
        await _svc.toggleEmergency(id);
      } else {
        await _svc.toggleAlert(id, type);
      }
      await _loadLectures();
      setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.indigo;
    }
  }

  String _duration(String start, String end) {
    try {
      final s = start.split(':');
      final e = end.split(':');
      final sm = int.parse(s[0]) * 60 + int.parse(s[1]);
      final em = int.parse(e[0]) * 60 + int.parse(e[1]);
      final diff = em - sm;
      if (diff <= 0) return '';
      final h = diff ~/ 60;
      final m = diff % 60;
      if (h == 0) return '${m}min';
      if (m == 0) return '${h}h';
      return '${h}h ${m}min';
    } catch (_) {
      return '';
    }
  }

  /// Scrollable list of cards: 1 column on phones, 2 columns on wide
  /// content areas, centered and capped at [_contentMaxWidth].
  Widget _responsiveList(double cw, List<Widget> cards) {
    final sidePad = responsiveSidePadding(cw, maxWidth: _contentMaxWidth);
    final cols = cw >= 820 ? 2 : 1;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 100),
      children: [
        ResponsiveGrid(
          columns: cols,
          spacing: 12,
          runSpacing: 0,
          children: staggered(cards, stepMs: 60),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    // Desktop / large screens get their own layout; phones and tablets
    // use the one below.
    if (context.isExpanded) return _buildDesktop(isDark);
    return _buildMobile(isDark);
  }

  // ══════════════════════════════════════════════════════════
  //  PHONE / TABLET LAYOUT
  // ══════════════════════════════════════════════════════════
  Widget _buildMobile(bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final now = DateTime.now();

    Widget tile(Widget child) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: child,
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timetable',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_days[_todayIndex]}, ${now.day} ${_monthNames[now.month - 1]}',
                          style: TextStyle(fontSize: 13, color: sub),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadAll,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: tile(
                        Icon(Icons.refresh_rounded, size: 20, color: textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    onSelected: (v) {
                      switch (v) {
                        case 'announce':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ComposeAnnouncementScreen(),
                            ),
                          );
                          break;
                        case 'resign':
                          _confirmResign(isDark);
                          break;
                        case 'request':
                          _showAdminRequestSheet(isDark);
                          break;
                        case 'superadmin':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SuperAdminScreen(),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (_isAdmin)
                        const PopupMenuItem(
                          value: 'announce',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.campaign_rounded),
                            title: Text('Announce'),
                          ),
                        ),
                      if (_isAdmin)
                        const PopupMenuItem(
                          value: 'resign',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.logout_rounded, color: Colors.red),
                            title: Text(
                              'Resign as admin',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      if (!_isAdmin && !_isSuperAdmin)
                        const PopupMenuItem(
                          value: 'request',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.verified_user_outlined),
                            title: Text('Become an admin'),
                          ),
                        ),
                      if (_isSuperAdmin)
                        const PopupMenuItem(
                          value: 'superadmin',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.admin_panel_settings_rounded),
                            title: Text('Admin panel'),
                          ),
                        ),
                    ],
                    child: tile(
                      Icon(Icons.more_horiz_rounded, size: 22, color: textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Lecture / Personal / Exam switch ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _mobileSegmented(isDark),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _typeTabCtrl,
                      children: [
                        _buildDayView(isDark, isPersonal: false),
                        _buildDayView(isDark, isPersonal: true),
                        _buildExamTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sliding pill that follows the swipe between the three tabs.
  Widget _mobileSegmented(bool isDark) {
    const items = [
      (Icons.cast_for_education_rounded, 'Lecture'),
      (Icons.menu_book_rounded, 'Personal'),
      (Icons.event_note_rounded, 'Exam'),
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
            animation: _typeTabCtrl.animation!,
            builder: (context, _) {
              final v = _typeTabCtrl.animation!.value;
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
                            onTap: () => _typeTabCtrl.animateTo(i),
                            child: Center(
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
                                ],
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

  // ══════════════════════════════════════════════════════════
  //  DESKTOP LAYOUT (screens >= 1024 px)
  // ══════════════════════════════════════════════════════════
  Widget _buildDesktop(bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final tab = _typeTabCtrl.index;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 26, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopHeader(isDark, tab),
                  const SizedBox(height: 22),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : tab == 2
                        ? _desktopExams(isDark)
                        : _desktopDays(isDark, isPersonal: tab == 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader(bool isDark, int tab) {
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    // Primary "add" action replaces the floating button on desktop
    Widget? addButton;
    if (tab == 0 && _isAdmin) {
      addButton = _deskButton(
        icon: Icons.add_rounded,
        label: 'Add class',
        filled: true,
        color: _primary,
        isDark: isDark,
        onTap: () => _showAddLectureSheet(isDark),
      );
    } else if (tab == 1) {
      addButton = _deskButton(
        icon: Icons.add_rounded,
        label: 'Add study',
        filled: true,
        color: _primary,
        isDark: isDark,
        onTap: () => _showAddPersonalSheet(isDark),
      );
    } else if (tab == 2 && _isAdmin) {
      addButton = _deskButton(
        icon: Icons.add_rounded,
        label: 'Add exam',
        filled: true,
        color: Colors.red.shade700,
        isDark: isDark,
        onTap: () => _showAddExamSheet(isDark),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Timetable',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today is ${_days[_todayIndex]}',
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _deskButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  isDark: isDark,
                  onTap: _loadAll,
                ),
                if (_isAdmin) ...[
                  _deskButton(
                    icon: Icons.campaign_rounded,
                    label: 'Announce',
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComposeAnnouncementScreen(),
                      ),
                    ),
                  ),
                  _deskButton(
                    icon: Icons.logout_rounded,
                    label: 'Resign',
                    color: Colors.red,
                    isDark: isDark,
                    onTap: () => _confirmResign(isDark),
                  ),
                ],
                if (!_isAdmin && !_isSuperAdmin)
                  _deskButton(
                    icon: Icons.verified_user_outlined,
                    label: 'Be Admin',
                    isDark: isDark,
                    onTap: () => _showAdminRequestSheet(isDark),
                  ),
                if (_isSuperAdmin)
                  _deskButton(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin panel',
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SuperAdminScreen(),
                      ),
                    ),
                  ),
                if (addButton != null) addButton,
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _segmented(isDark, tab),
      ],
    );
  }

  Widget _deskButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool filled = false,
    Color? color,
  }) {
    final c = color ?? _primary;
    final fg = filled ? Colors.white : (color ?? (isDark ? Colors.white70 : Colors.black87));
    return Material(
      color: filled
          ? c
          : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill-style segmented control that drives the same [_typeTabCtrl].
  Widget _segmented(bool isDark, int tab) {
    const items = [
      (Icons.cast_for_education_rounded, 'Lecture'),
      (Icons.menu_book_rounded, 'Personal'),
      (Icons.event_note_rounded, 'Exam'),
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
              onTap: () => setState(() => _typeTabCtrl.index = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: tab == i
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
                        color: tab == i
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tab == i
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _countFor(String day, bool isPersonal) => isPersonal
      ? _personal.where((e) => e.day == day).length
      : _lectures.where((e) => e.day == day).length;

  /// Lecture / Personal: vertical day list on the left, selected day on the right.
  Widget _desktopDays(bool isDark, {required bool isPersonal}) {
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;
    final sel = _dayTabCtrl.index;
    final day = _days[sel];
    final noun = isPersonal ? 'session' : 'class';

    final cards = isPersonal
        ? (_personal.where((e) => e.day == day).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime)))
            .map((e) => _personalCard(e, isDark))
            .toList()
        : (_lectures.where((e) => e.day == day).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime)))
            .map((e) => _lectureCard(e, isDark))
            .toList();

    // ── Left: day list ──
    final dayRail = Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _dayTabCtrl.index = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      gradient: sel == i
                          ? const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _days[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel == i
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: sel == i ? Colors.white : textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                () {
                                  final n = _countFor(_days[i], isPersonal);
                                  return n == 0
                                      ? 'Free'
                                      : '$n ${n == 1 ? noun : '${noun}s'}';
                                }(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sel == i
                                      ? Colors.white70
                                      : textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i == _todayIndex)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sel == i
                                  ? Colors.white.withOpacity(0.2)
                                  : _primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'TODAY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: sel == i ? Colors.white : _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // ── Right: selected day ──
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              day,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                cards.isEmpty
                    ? 'Nothing scheduled'
                    : '${cards.length} ${cards.length == 1 ? noun : '${noun}s'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: cards.isEmpty
              ? _dayEntriesList(
                  isDark: isDark,
                  isEmpty: true,
                  day: day,
                  isPersonal: isPersonal,
                  child: const SizedBox.shrink(),
                )
              : LayoutBuilder(
                  builder: (context, c) => ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      ResponsiveGrid(
                        columns: c.maxWidth >= 780 ? 2 : 1,
                        spacing: 14,
                        runSpacing: 0,
                        children: staggered(cards, stepMs: 60),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(child: dayRail),
        const SizedBox(width: 26),
        Expanded(child: detail),
      ],
    );
  }

  /// Exams: summary stats on top, exam cards below.
  Widget _desktopExams(bool isDark) {
    final sorted = [..._exams]
      ..sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        final dateCmp = a.date!.compareTo(b.date!);
        if (dateCmp != 0) return dateCmp;
        return a.startTime.compareTo(b.startTime);
      });

    if (sorted.isEmpty) {
      return _emptyState(
        icon: Icons.event_note_outlined,
        title: 'No Exams Scheduled',
        subtitle: _isAdmin
            ? 'Use "Add exam" to schedule an exam'
            : 'No exam timetable has been published yet',
        isDark: isDark,
      );
    }

    final now = DateTime.now();
    final dated = sorted.where((e) => e.date != null).toList();
    final upcoming = dated
        .where((e) => e.date!.difference(now).inDays >= 0)
        .toList();
    final nextDays = upcoming.isEmpty
        ? null
        : upcoming.first.date!.difference(now).inDays;
    final thisWeek = upcoming
        .where((e) => e.date!.difference(now).inDays <= 7)
        .length;

    final stats = ResponsiveGrid(
      columns: 3,
      children: [
        _statCard(
          icon: Icons.event_note_rounded,
          label: 'Total exams',
          value: '${sorted.length}',
          color: Colors.red.shade700,
          isDark: isDark,
        ),
        _statCard(
          icon: Icons.timer_outlined,
          label: 'Next exam',
          value: nextDays == null
              ? '—'
              : nextDays <= 0
              ? 'Today'
              : '$nextDays ${nextDays == 1 ? 'day' : 'days'}',
          color: Colors.orange.shade700,
          isDark: isDark,
        ),
        _statCard(
          icon: Icons.warning_amber_rounded,
          label: 'Within 7 days',
          value: '$thisWeek',
          color: _primary,
          isDark: isDark,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) => RefreshIndicator(
        onRefresh: _loadExams,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            stats,
            const SizedBox(height: 20),
            ResponsiveGrid(
              columns: c.maxWidth >= 860 ? 2 : 1,
              spacing: 14,
              runSpacing: 0,
              children: sorted.map((e) => _examCard(e, isDark)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15181D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DAY VIEW (phone) — week strip + swipeable days
  // ══════════════════════════════════════════════════════════
  Widget _buildDayView(bool isDark, {required bool isPersonal}) {
    final pageCtrl = isPersonal ? _personalPageCtrl : _lecturePageCtrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isPersonal
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPersonalSheet(isDark),
              icon: const Icon(Icons.add),
              label: const Text('Add Study'),
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : (_isAdmin
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddLectureSheet(isDark),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Class'),
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )
                : null),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cw = constraints.maxWidth;

          return Column(
            children: [
              _weekStrip(isDark, isPersonal, pageCtrl),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: pageCtrl,
                  itemCount: _days.length,
                  onPageChanged: (i) {
                    if (_dayTabCtrl.index != i) {
                      _dayTabCtrl.animateTo(i);
                    }
                  },
                  itemBuilder: (_, dayIndex) {
                    final day = _days[dayIndex];
                    final List<Widget> cards;
                    if (isPersonal) {
                      final entries =
                          _personal.where((e) => e.day == day).toList()..sort(
                            (a, b) => a.startTime.compareTo(b.startTime),
                          );
                      cards = entries
                          .map((e) => _personalCard(e, isDark))
                          .toList();
                    } else {
                      final entries =
                          _lectures.where((e) => e.day == day).toList()..sort(
                            (a, b) => a.startTime.compareTo(b.startTime),
                          );
                      cards = entries
                          .map((e) => _lectureCard(e, isDark))
                          .toList();
                    }
                    // drag down to refresh works on every day, even when empty
                    return RefreshIndicator(
                      color: _primary,
                      onRefresh: _loadAll,
                      child: _dayEntriesList(
                        isDark: isDark,
                        isEmpty: cards.isEmpty,
                        day: day,
                        isPersonal: isPersonal,
                        child: _responsiveList(cw, cards),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Seven equal day cards: weekday, date, and dots for how many entries.
  Widget _weekStrip(bool isDark, bool isPersonal, PageController pageCtrl) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sub = isDark ? Colors.white54 : Colors.black45;
    final text = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var i = 0; i < _days.length; i++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final selected = _dayTabCtrl.index == i;
                  final isToday = i == _todayIndex;
                  final date = monday.add(Duration(days: i));
                  final count = isPersonal
                      ? _personal.where((e) => e.day == _days[i]).length
                      : _lectures.where((e) => e.day == _days[i]).length;
                  final dotColor = selected ? Colors.white : _primary;

                  return GestureDetector(
                    onTap: () {
                      _dayTabCtrl.animateTo(i);
                      pageCtrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1E88E5),
                                    Color(0xFF0D47A1),
                                  ],
                                )
                              : null,
                          color: selected
                              ? null
                              : (isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : (isToday
                                      ? _primary.withOpacity(0.55)
                                      : (isDark
                                            ? Colors.white.withOpacity(0.06)
                                            : Colors.black.withOpacity(0.05))),
                            width: isToday && !selected ? 1.4 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dayShort[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: selected ? Colors.white70 : sub,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: selected ? Colors.white : text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var k = 0; k < (count > 3 ? 3 : count); k++)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayEntriesList({
    required bool isDark,
    required bool isEmpty,
    required String day,
    required bool isPersonal,
    required Widget child,
  }) {
    if (!isEmpty) return child;

    // scrollable so pull-to-refresh also works on an empty day
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: c.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPersonal
                            ? Icons.menu_book_outlined
                            : Icons.weekend_rounded,
                        size: 42,
                        color: _primary.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPersonal ? 'No study sessions' : 'Nothing on $day',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPersonal
                          ? 'Tap "Add Study" to plan a session'
                          : _isAdmin
                          ? 'Tap "Add Class" to schedule a lecture'
                          : 'No lectures scheduled for this day',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  EXAM TAB
  // ══════════════════════════════════════════════════════════
  Widget _buildExamTab(bool isDark) {
    final sorted = [..._exams]
      ..sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        final dateCmp = a.date!.compareTo(b.date!);
        if (dateCmp != 0) return dateCmp;
        return a.startTime.compareTo(b.startTime);
      });

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddExamSheet(isDark),
              icon: const Icon(Icons.add),
              label: const Text('Add Exam'),
              backgroundColor: Colors.red.shade700,
            )
          : null,
      body: sorted.isEmpty
          ? RefreshIndicator(
              color: _primary,
              onRefresh: _loadExams,
              child: LayoutBuilder(
                builder: (context, c) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: c.maxHeight,
                      child: _emptyState(
                        icon: Icons.event_note_outlined,
                        title: 'No Exams Scheduled',
                        subtitle: _isAdmin
                            ? 'Tap "Add Exam" to schedule an exam'
                            : 'No exam timetable has been published yet',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                onRefresh: _loadExams,
                child: _responsiveList(
                  constraints.maxWidth,
                  sorted.map((e) => _examCard(e, isDark)).toList(),
                ),
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CARDS
  // ══════════════════════════════════════════════════════════

  Widget _lectureCard(LectureEntry e, bool isDark) {
    final isMuted = MutedCoursesStore().isMuted(e.courseCode);
    final reminderOn = (_reminders[e.id]?['enabled'] ?? false) == true;
    final iconColor = isDark ? Colors.white38 : Colors.black38;

    // small actions on the right of the card
    final trailing = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isMuted ? 'Unmute notifications' : 'Mute notifications',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isMuted
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_outlined,
            color: isMuted ? Colors.grey : iconColor,
            size: 20,
          ),
          onPressed: () async {
            await MutedCoursesStore().toggle(e.courseCode);
            setState(() {});
            AppSnackBar.showInfo(
              context,
              MutedCoursesStore().isMuted(e.courseCode)
                  ? '${e.courseCode} notifications muted'
                  : '${e.courseCode} notifications unmuted',
            );
          },
        ),
        if (_isAdmin)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: iconColor, size: 20),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
            onSelected: (val) async {
              if (val == 'delete') {
                await _svc.deleteLecture(e.id);
                await _loadLectures();
                setState(() {});
              } else {
                _showAddLectureSheet(isDark, editing: e);
              }
            },
          ),
      ],
    );

    // flags: admins can toggle all of them, students only see the active ones
    final footer = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_isAdmin || e.isEmergency)
          _flagChip(
            'Emergency',
            Icons.star_rounded,
            e.isEmergency,
            Colors.amber,
            isDark,
            _isAdmin ? () => _toggleAlert(e.id, 'emergency') : null,
          ),
        if (_isAdmin || e.isTest)
          _flagChip(
            'Test',
            Icons.quiz_rounded,
            e.isTest,
            Colors.red,
            isDark,
            _isAdmin ? () => _toggleAlert(e.id, 'test') : null,
          ),
        if (_isAdmin || e.isAttendance)
          _flagChip(
            'Attendance',
            Icons.how_to_reg_rounded,
            e.isAttendance,
            Colors.green,
            isDark,
            _isAdmin ? () => _toggleAlert(e.id, 'attendance') : null,
          ),
        if (_isAdmin || e.isCancelled)
          _flagChip(
            'Cancelled',
            Icons.block_rounded,
            e.isCancelled,
            Colors.red,
            isDark,
            _isAdmin ? () => _toggleAlert(e.id, 'cancelled') : null,
          ),
        _flagChip(
          reminderOn ? 'Reminder on' : 'Remind me',
          reminderOn
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          reminderOn,
          _primary,
          isDark,
          () => _showReminderSheet(e, isDark),
        ),
      ],
    );

    final status = classStatusOf(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClassCard(
        entry: e,
        isDark: isDark,
        status: status,
        progress: status == ClassStatus.ongoing ? classProgressOf(e) : 0,
        trailing: trailing,
        footer: footer,
      ),
    );
  }

  Widget _flagChip(
    String label,
    IconData icon,
    bool active,
    Color color,
    bool isDark,
    VoidCallback? onTap,
  ) {
    final off = isDark ? Colors.white38 : Colors.black38;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.14)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? color.withOpacity(0.45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? color : off),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? color : off,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco(bool isDark, {Color? border}) => BoxDecoration(
    color: isDark ? const Color(0xFF15181D) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: border != null ? Border.all(color: border, width: 1.2) : null,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _personalCard(PersonalEntry e, bool isDark) {
    final color = _hexColor(e.color);
    final dur = _duration(e.startTime, e.endTime);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── time block ──
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    e.startTime,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    e.endTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                  if (dur.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dur,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── title + note ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 15, color: color),
                      const SizedBox(width: 6),
                      Text(
                        'STUDY SESSION',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: text,
                    ),
                  ),
                  if (e.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      e.note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  ],
                  if (e.isBookmarked) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alarm_on_rounded,
                            size: 12,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'REMINDER ON',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── bookmark + menu ──
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: e.isBookmarked ? 'Remove reminder' : 'Remind me',
                  icon: Icon(
                    e.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline,
                    color: e.isBookmarked ? Colors.amber : Colors.grey,
                    size: 22,
                  ),
                  onPressed: () async {
                    await _svc.toggleBookmark(e.id);
                    await _loadPersonal();
                    setState(() {});

                    final updated = _personal.firstWhere(
                      (p) => p.id == e.id,
                      orElse: () => e,
                    );
                    if (updated.isBookmarked) {
                      final success =
                          await NotificationService.scheduleStudyReminder(
                            entryId: updated.id,
                            title: updated.title,
                            day: updated.day,
                            startTime: updated.startTime,
                          );
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Reminder permission missing — enable it in Settings.',
                            ),
                          ),
                        );
                      }
                    } else {
                      await NotificationService.cancelStudyReminder(updated.id);
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (val) async {
                    if (val == 'delete') {
                      await _svc.deletePersonal(e.id);
                      await _loadPersonal();
                      setState(() {});
                    } else {
                      _showAddPersonalSheet(isDark, editing: e);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _examCard(LectureEntry e, bool isDark) {
    final d = e.date;
    int? daysLeft;
    if (d != null) {
      final n = DateTime.now();
      daysLeft = DateTime(d.year, d.month, d.day)
          .difference(DateTime(n.year, n.month, n.day))
          .inDays;
    }
    final past = daysLeft != null && daysLeft < 0;
    final urgent = daysLeft != null && daysLeft >= 0 && daysLeft <= 7;
    final chip = daysLeft == null
        ? Colors.grey
        : daysLeft <= 3
        ? Colors.red
        : daysLeft <= 7
        ? Colors.orange
        : Colors.grey;
    final dur = _duration(e.startTime, e.endTime);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: past ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco(
            isDark,
            border: urgent ? Colors.red.withOpacity(0.45) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── date block ──
              Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: d == null
                    ? const Icon(Icons.event_note_rounded, color: Colors.red)
                    : Column(
                        children: [
                          Text(
                            '${d.day}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            _monthNames[d.month - 1].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dayShort[d.weekday - 1],
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),

              // ── info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.courseCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: text,
                      ),
                    ),
                    if (e.courseTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.courseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: sub),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: sub),
                        const SizedBox(width: 4),
                        Text(
                          '${e.startTime} – ${e.endTime}'
                          '${dur.isNotEmpty ? '  ·  $dur' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                    if (e.venue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 13, color: sub),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              e.venue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── countdown + menu ──
              Column(
                children: [
                  if (daysLeft != null)
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: chip.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            past
                                ? 'Done'
                                : daysLeft == 0
                                ? 'Today'
                                : '$daysLeft',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: past || daysLeft == 0 ? 13 : 20,
                              color: chip,
                              height: 1.1,
                            ),
                          ),
                          if (!past && daysLeft > 0)
                            Text(
                              daysLeft == 1 ? 'day' : 'days',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: chip,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_isAdmin)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      onSelected: (val) async {
                        if (val == 'delete') {
                          await _svc.deleteExam(e.id);
                          await _loadExams();
                          setState(() {});
                        } else {
                          _showAddExamSheet(isDark, editing: e);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertChip({
    required IconData icon,
    required bool active,
    required Color color,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.15)
                : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? color : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _reminderChip(LectureEntry e, bool isDark) {
    final reminder = _reminders[e.id];
    final enabled = reminder?['enabled'] ?? false;

    return GestureDetector(
      onTap: () => _showReminderSheet(e, isDark),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: enabled
                ? _primary.withOpacity(0.15)
                : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            size: 18,
            color: enabled
                ? _primary
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _showReminderSheet(LectureEntry e, bool isDark) {
    final reminder = _reminders[e.id];
    bool enabled = reminder?['enabled'] ?? false;
    int minutesBefore = reminder?['minutesBefore'] ?? 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: _sheetConstraints,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(isDark),
              const SizedBox(height: 16),
              Text(
                'Class Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.courseCode,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Enable Reminder',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: enabled,
                    onChanged: (v) => setS(() => enabled = v),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Remind me before class',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 15, 30, 60].map((min) {
                  final selected = minutesBefore == min;
                  return GestureDetector(
                    onTap: () => setS(() => minutesBefore = min),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.blue
                            : (isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$min min',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await _svc.setReminder(e.id, enabled, minutesBefore);
                      await _loadReminders();
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              enabled
                                  ? '🔔 Reminder set for $minutesBefore min before class'
                                  : 'Reminder turned off',
                            ),
                          ),
                        );
                    } catch (err) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $err')));
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  BOTTOM SHEETS
  // ══════════════════════════════════════════════════════════
  void _showAddLectureSheet(bool isDark, {LectureEntry? editing}) {
    final codeCtrl = TextEditingController(text: editing?.courseCode ?? '');
    final titleCtrl = TextEditingController(text: editing?.courseTitle ?? '');
    final venueCtrl = TextEditingController(text: editing?.venue ?? '');
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    String day = editing?.day ?? _days[_todayIndex];
    String startTime = editing?.startTime ?? '08:00';
    String endTime = editing?.endTime ?? '10:00';
    String classType = editing?.classType ?? 'normal';
    bool isImportant = editing?.isImportant ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: _sheetConstraints,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(isDark),
                const SizedBox(height: 16),
                Text(
                  editing == null ? 'Add Lecture' : 'Edit Lecture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetField('Course Code *', codeCtrl, isDark),
                const SizedBox(height: 12),
                _sheetField('Course Title', titleCtrl, isDark),
                const SizedBox(height: 12),
                _sheetField('Venue', venueCtrl, isDark),
                const SizedBox(height: 12),
                _dropdownField(
                  'Day',
                  _days,
                  day,
                  isDark,
                  (v) => setS(() => day = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'Start',
                        startTime,
                        isDark,
                        (t) => setS(() => startTime = t),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'End',
                        endTime,
                        isDark,
                        (t) => setS(() => endTime = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dropdownField(
                  'Class Type',
                  ['normal', 'impromptu', 'test', 'meeting', 'other'],
                  classType,
                  isDark,
                  (v) => setS(() {
                    classType = v!;
                    if (v != 'normal') isImportant = true;
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Mark as Important',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: isImportant,
                      onChanged: (v) => setS(() => isImportant = v),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
                _sheetField('Note (optional)', noteCtrl, isDark),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      final body = {
                        'courseCode': codeCtrl.text.trim(),
                        'courseTitle': titleCtrl.text.trim(),
                        'venue': venueCtrl.text.trim(),
                        'day': day,
                        'startTime': startTime,
                        'endTime': endTime,
                        'classType': classType,
                        'isImportant': isImportant,
                        'note': noteCtrl.text.trim(),
                        'school': _school,
                        'faculty': _faculty,
                        'department': _department,
                        'level': _level,
                      };
                      try {
                        if (editing == null) {
                          await _svc.addLecture(body);
                        } else {
                          await _svc.updateLecture(editing.id, body);
                        }
                        await _loadLectures();
                        setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: Text(
                      editing == null ? 'Add Lecture' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPersonalSheet(bool isDark, {PersonalEntry? editing}) {
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    String day = editing?.day ?? _days[_todayIndex];
    String startTime = editing?.startTime ?? '08:00';
    String endTime = editing?.endTime ?? '10:00';
    String color = editing?.color ?? '#4F46E5';

    final colors = [
      '#4F46E5',
      '#7C3AED',
      '#DB2777',
      '#DC2626',
      '#D97706',
      '#059669',
      '#0891B2',
      '#1D4ED8',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: _sheetConstraints,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(isDark),
                const SizedBox(height: 16),
                Text(
                  editing == null ? 'Add Study Session' : 'Edit Session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetField('Title (e.g. Read MTH301) *', titleCtrl, isDark),
                const SizedBox(height: 12),
                _dropdownField(
                  'Day',
                  _days,
                  day,
                  isDark,
                  (v) => setS(() => day = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'Start',
                        startTime,
                        isDark,
                        (t) => setS(() => startTime = t),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'End',
                        endTime,
                        isDark,
                        (t) => setS(() => endTime = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                // Wrap (not Row) so the swatches never overflow narrow screens
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final selected = c == color;
                    return GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _hexColor(c),
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _hexColor(c).withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _sheetField('Note (optional)', noteCtrl, isDark),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final body = {
                        'title': titleCtrl.text.trim(),
                        'day': day,
                        'startTime': startTime,
                        'endTime': endTime,
                        'color': color,
                        'note': noteCtrl.text.trim(),
                      };
                      try {
                        if (editing == null) {
                          await _svc.addPersonal(body);
                        } else {
                          await _svc.updatePersonal(editing.id, body);
                        }
                        await _loadPersonal();
                        setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: Text(
                      editing == null ? 'Add Session' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExamSheet(bool isDark, {LectureEntry? editing}) {
    final codeCtrl = TextEditingController(text: editing?.courseCode ?? '');
    final titleCtrl = TextEditingController(text: editing?.courseTitle ?? '');
    final venueCtrl = TextEditingController(text: editing?.venue ?? '');
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    String startTime = editing?.startTime ?? '09:00';
    String endTime = editing?.endTime ?? '11:00';
    DateTime? examDate = editing?.date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: _sheetConstraints,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(isDark),
                const SizedBox(height: 16),
                Text(
                  editing == null ? 'Add Exam' : 'Edit Exam',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetField('Course Code *', codeCtrl, isDark),
                const SizedBox(height: 12),
                _sheetField('Course Title', titleCtrl, isDark),
                const SizedBox(height: 12),
                _sheetField('Venue', venueCtrl, isDark),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: examDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setS(() => examDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          examDate != null
                              ? '${examDate!.day}/${examDate!.month}/${examDate!.year}'
                              : 'Pick Exam Date *',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'Start',
                        startTime,
                        isDark,
                        (t) => setS(() => startTime = t),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker(
                        ctx,
                        'End',
                        endTime,
                        isDark,
                        (t) => setS(() => endTime = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sheetField('Note (optional)', noteCtrl, isDark),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (codeCtrl.text.trim().isEmpty || examDate == null)
                        return;
                      final body = {
                        'courseCode': codeCtrl.text.trim(),
                        'courseTitle': titleCtrl.text.trim(),
                        'venue': venueCtrl.text.trim(),
                        'date': examDate!.toIso8601String(),
                        'startTime': startTime,
                        'endTime': endTime,
                        'note': noteCtrl.text.trim(),
                        'school': _school,
                        'faculty': _faculty,
                        'department': _department,
                        'level': _level,
                      };
                      try {
                        if (editing == null) {
                          await _svc.addExam(body);
                        } else {
                          await _svc.updateExam(editing.id, body);
                        }
                        await _loadExams();
                        setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: Text(editing == null ? 'Add Exam' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAdminRequestSheet(bool isDark) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: _sheetConstraints,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(isDark),
              const SizedBox(height: 16),
              Text(
                'Request Admin Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your school/faculty/department/level from your profile will be used. '
                'Tell us why you should be a course rep admin.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g. I am the elected course rep for 300L CSC...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (reasonCtrl.text.trim().isEmpty) return;
                    try {
                      await _svc.requestAdmin({
                        'reason': reasonCtrl.text.trim(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ Request submitted! You\'ll be notified when reviewed.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResign(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Resign as Admin?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You will lose admin access immediately. Your timetable entries will remain.',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _svc.resignAdmin();
      await _checkAdminStatus();
      setState(() {});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have resigned as admin.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Sheet helpers ─────────────────────────────────────────────────────────
  Widget _sheetHandle(bool isDark) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _sheetField(
    String label,
    TextEditingController ctrl,
    bool isDark,
  ) => TextField(
    controller: ctrl,
    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
    cursorColor: _primary,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
    ),
  );

  Widget _dropdownField(
    String label,
    List<String> items,
    String value,
    bool isDark,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    value: value,
    onChanged: onChanged,
    dropdownColor: isDark ? Colors.black : Colors.white,
    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
    ),
    items: items
        .map(
          (d) => DropdownMenuItem(
            value: d,
            child: Text(d[0].toUpperCase() + d.substring(1)),
          ),
        )
        .toList(),
  );

  Widget _timePicker(
    BuildContext ctx,
    String label,
    String current,
    bool isDark,
    ValueChanged<String> onPicked,
  ) => GestureDetector(
    onTap: () async {
      final parts = current.split(':');
      final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
      final picked = await showTimePicker(context: ctx, initialTime: initial);
      if (picked != null) {
        onPicked(
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        );
      }
    },
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: _primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  current,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}