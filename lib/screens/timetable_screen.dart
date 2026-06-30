import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_notifier.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_service.dart';
import 'super_admin_screen.dart';
import '../services/muted_courses_store.dart';
import '../widgets/snackBar.dart';
import '../services/notification_service.dart';
import 'compose_announcement_screen.dart';

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

  int get _todayIndex {
    final wd = DateTime.now().weekday; // 1=Mon … 7=Sun
    return wd - 1;
  }

  @override
  void initState() {
    super.initState();
    _typeTabCtrl = TabController(length: 3, vsync: this);
    _dayTabCtrl = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: _todayIndex,
    );
    _lecturePageCtrl = PageController(initialPage: _todayIndex); // ← add
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ── Unified gradient header: title + actions + sub-tabs ──
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Timetable',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _loadAll,
                        ),
                        if (_isAdmin) ...[
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ComposeAnnouncementScreen(),
                              ),
                            ),
                            child: const Text(
                              'Announce',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmResign(isDark),
                            child: const Text(
                              'Resign',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (!_isAdmin && !_isSuperAdmin)
                          TextButton(
                            onPressed: () => _showAdminRequestSheet(isDark),
                            child: const Text(
                              'Be Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_isSuperAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SuperAdminScreen(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _typeTabCtrl,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.cast_for_education_rounded, size: 20),
                        text: 'Lecture',
                      ),
                      Tab(
                        icon: Icon(Icons.menu_book_rounded, size: 20),
                        text: 'Personal',
                      ),
                      Tab(
                        icon: Icon(Icons.event_note_rounded, size: 20),
                        text: 'Exam',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DAY VIEW (shared by Lecture + Personal tabs)
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
            )
          : (_isAdmin
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddLectureSheet(isDark),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Class'),
                    backgroundColor: _primary,
                  )
                : null),
      body: Column(
        children: [
          // Day-of-week sub-bar, now blended to sit flush under the gradient header
          Container(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            child: TabBar(
              controller: _dayTabCtrl,
              isScrollable: true,
              labelColor: _primary,
              unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
              indicatorColor: _primary,
              indicatorWeight: 3,
              onTap: (i) {
                pageCtrl.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tabs: List.generate(_days.length, (i) {
                final isToday = i == _todayIndex;
                return Tab(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dayShort[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
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

                if (isPersonal) {
                  final entries = _personal.where((e) => e.day == day).toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
                  return _dayEntriesList(
                    isDark: isDark,
                    isEmpty: entries.isEmpty,
                    day: day,
                    isPersonal: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _personalCard(entries[i], isDark),
                    ),
                  );
                } else {
                  final entries = _lectures.where((e) => e.day == day).toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
                  return _dayEntriesList(
                    isDark: isDark,
                    isEmpty: entries.isEmpty,
                    day: day,
                    isPersonal: false,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _lectureCard(entries[i], isDark),
                    ),
                  );
                }
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
    if (isEmpty) {
      return Center(
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
                child: Icon(
                  isPersonal
                      ? Icons.menu_book_outlined
                      : Icons.cast_for_education_outlined,
                  size: 44,
                  color: _primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No classes on $day',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPersonal
                    ? 'Tap "Add Study" to add a session'
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
      );
    }
    return child;
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
          ? _emptyState(
              icon: Icons.event_note_outlined,
              title: 'No Exams Scheduled',
              subtitle: _isAdmin
                  ? 'Tap "Add Exam" to schedule an exam'
                  : 'No exam timetable has been published yet',
              isDark: isDark,
            )
          : RefreshIndicator(
              onRefresh: _loadExams,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _examCard(sorted[i], isDark),
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CARDS
  // ══════════════════════════════════════════════════════════

  Widget _lectureCard(LectureEntry e, bool isDark) {
    final typeColor = e.classType == 'test'
        ? Colors.red
        : e.classType == 'impromptu'
        ? Colors.orange
        : e.classType == 'meeting'
        ? Colors.purple
        : _primary;

    final typeIcon = e.classType == 'test'
        ? Icons.quiz_rounded
        : e.classType == 'impromptu'
        ? Icons.bolt_rounded
        : e.classType == 'meeting'
        ? Icons.groups_rounded
        : Icons.school_rounded;

    final dur = _duration(e.startTime, e.endTime);
    final isMuted = MutedCoursesStore().isMuted(e.courseCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: e.isImportant
            ? Border.all(color: typeColor.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.startTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.endTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (dur.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dur,
                            style: TextStyle(
                              fontSize: 9,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 2,
                  height: 60,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(typeIcon, color: typeColor, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.courseCode,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (e.isImportant)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.classType.toUpperCase(),
                                style: TextStyle(
                                  color: typeColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (e.courseTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          e.courseTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                      if (e.venue.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                e.venue,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Mute button (everyone) ──
                IconButton(
                  icon: Icon(
                    isMuted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_active_outlined,
                    color: isMuted
                        ? Colors.grey
                        : (isDark ? Colors.white38 : Colors.black38),
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
                        await _svc.deleteLecture(e.id);
                        await _loadLectures();
                        setState(() {});
                      } else {
                        _showAddLectureSheet(isDark, editing: e);
                      }
                    },
                  ),
              ],
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _alertChip(
                    icon: e.isEmergency
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    active: e.isEmergency,
                    color: Colors.amber,
                    isDark: isDark,
                    onTap: _isAdmin
                        ? () => _toggleAlert(e.id, 'emergency')
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _alertChip(
                    icon: Icons.quiz_rounded,
                    active: e.isTest,
                    color: Colors.red,
                    isDark: isDark,
                    onTap: _isAdmin ? () => _toggleAlert(e.id, 'test') : null,
                  ),
                  const SizedBox(width: 8),
                  _alertChip(
                    icon: Icons.how_to_reg_rounded,
                    active: e.isAttendance,
                    color: Colors.green,
                    isDark: isDark,
                    onTap: _isAdmin
                        ? () => _toggleAlert(e.id, 'attendance')
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _alertChip(
                    icon: Icons.block_rounded,
                    active: e.isCancelled,
                    color: Colors.red,
                    isDark: isDark,
                    onTap: _isAdmin
                        ? () => _toggleAlert(e.id, 'cancelled')
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _reminderChip(e, isDark),
                ],
              ),
            ),
          ],
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
    );
  }

  Widget _reminderChip(LectureEntry e, bool isDark) {
    final reminder = _reminders[e.id];
    final enabled = reminder?['enabled'] ?? false;

    return GestureDetector(
      onTap: () => _showReminderSheet(e, isDark),
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
    );
  }

  void _showReminderSheet(LectureEntry e, bool isDark) {
    final reminder = _reminders[e.id];
    bool enabled = reminder?['enabled'] ?? false;
    int minutesBefore = reminder?['minutesBefore'] ?? 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

  Widget _personalCard(PersonalEntry e, bool isDark) {
    final color = _primary;
    final dur = _duration(e.startTime, e.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.startTime,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.endTime,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  if (dur.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dur,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 2,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (e.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      e.note,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
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
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
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
    final daysLeft = e.date != null
        ? e.date!.difference(DateTime.now()).inDays
        : null;
    final urgent = daysLeft != null && daysLeft <= 7;
    final dur = _duration(e.startTime, e.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? Colors.red.withOpacity(0.5)
              : Colors.red.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.courseCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (e.courseTitle.isNotEmpty)
                    Text(
                      e.courseTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (e.date != null)
                    Text(
                      '${e.date!.day}/${e.date!.month}/${e.date!.year}  •  ${e.startTime} – ${e.endTime}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  if (dur.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Duration: $dur',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (e.venue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '📍 ${e.venue}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                if (daysLeft != null)
                  Column(
                    children: [
                      Text(
                        daysLeft <= 0 ? 'Today!' : '$daysLeft',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: daysLeft <= 0 ? 13 : 22,
                          color: daysLeft <= 3
                              ? Colors.red
                              : daysLeft <= 7
                              ? Colors.orange
                              : Colors.grey,
                        ),
                      ),
                      if (daysLeft > 0)
                        Text(
                          'days',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                if (_isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white38 : Colors.black38,
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
  );

  // ══════════════════════════════════════════════════════════
  //  BOTTOM SHEETS (keep all existing ones)
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
                Row(
                  children: colors.map((c) {
                    final selected = c == color;
                    return GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
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
                    await _svc.requestAdmin({'reason': reasonCtrl.text.trim()});
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
  );
}
