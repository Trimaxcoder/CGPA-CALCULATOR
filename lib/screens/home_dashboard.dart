// ══════════════════════════════════════════════════════════
//  HOME DASHBOARD
//  Auto-playing info carousel, today's classes (live status),
//  CGPA + semester rings, upcoming exams, quick actions.
//  Phone: single column.  Desktop (>= 1024 px): main + side panel.
// ══════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/announcement.dart';
import '../models/timetable_entry.dart';
import '../providers/theme_notifier.dart';
import '../services/notification_store.dart';
import '../services/timetable_service.dart';
import '../stores/announcement_store.dart';
import '../utils/responsive.dart';
import '../widgets/animations.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/class_card.dart';
import 'announcement_detail_screen.dart';
import 'notifications_screen.dart';

const Color _blue = Color(0xFF1565C0);
const Color _blueLight = Color(0xFF1E88E5);
const Color _blueDark = Color(0xFF0D47A1);
const Color _teal = Color(0xFF0891B2);
const Color _purple = Color(0xFF7C3AED);

enum _Status { upcoming, ongoing, done, cancelled }

class _C {
  _C(this.dark)
    : bg = dark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      card = dark ? const Color(0xFF15181D) : Colors.white,
      text = dark ? Colors.white : Colors.black87,
      sub = dark ? Colors.white54 : Colors.black45;
  final bool dark;
  final Color bg, card, text, sub;

  List<BoxShadow> get shadow => [
    BoxShadow(
      color: Colors.black.withOpacity(dark ? 0.3 : 0.05),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _tips = [
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

  // profile
  String _name = '', _department = '', _level = '', _school = '';

  // data
  List<LectureEntry> _lectures = [];
  List<LectureEntry> _exams = [];
  bool _loadingRemote = true;

  // timers + carousel
  Timer? _tick;
  Timer? _auto;
  final PageController _page = PageController(viewportFraction: 0.92);
  int _slideCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // keeps "starts in 12 min" / live status fresh
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _slideCount < 2 || !_page.hasClients) return;
      if (_page.position.isScrollingNotifier.value) return;
      final cur = (_page.page ?? 0).round();
      _page.animateToPage(
        (cur + 1) % _slideCount,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────
  Future<void> _loadAll() async {
    await _loadLocal();
    await _loadRemote();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('profile');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _name = m['name'] ?? '';
        _department = m['department'] ?? '';
        _level = m['level'] ?? '';
        _school = m['school'] ?? '';
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadRemote() async {
    final svc = TimetableService();
    try {
      final l = await svc.getLectures();
      _lectures = l.map(LectureEntry.fromMap).toList();
    } catch (_) {}
    try {
      final e = await svc.getExams();
      _exams = e.map(LectureEntry.fromMap).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingRemote = false);
  }

  // ── Derived data ─────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName => _name.trim().split(' ').first;
  String get _initial => _name.isNotEmpty ? _name[0].toUpperCase() : 'S';

  String get _dateLabel {
    final n = DateTime.now();
    return '${_days[n.weekday - 1]}, ${n.day} ${_months[n.month - 1]}';
  }

  int _mins(String t) {
    final p = t.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  int get _nowMin {
    final n = DateTime.now();
    return n.hour * 60 + n.minute;
  }

  List<LectureEntry> get _todayClasses {
    final d = _days[DateTime.now().weekday - 1];
    return _lectures.where((e) => e.day == d).toList()
      ..sort((a, b) => _mins(a.startTime).compareTo(_mins(b.startTime)));
  }

  _Status _status(LectureEntry e) {
    if (e.isCancelled) return _Status.cancelled;
    final s = _mins(e.startTime), en = _mins(e.endTime), n = _nowMin;
    if (n < s) return _Status.upcoming;
    if (n >= en) return _Status.done;
    return _Status.ongoing;
  }

  LectureEntry? get _nextClass {
    for (final e in _todayClasses) {
      final s = _status(e);
      if (s == _Status.ongoing || s == _Status.upcoming) return e;
    }
    return null;
  }

  int _daysLeft(DateTime d) {
    final n = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(n.year, n.month, n.day))
        .inDays;
  }

  List<LectureEntry> get _upcomingExams {
    final l = _exams
        .where((e) => e.date != null && _daysLeft(e.date!) >= 0)
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    return l;
  }

  String _fmtMin(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final dark = context.watch<ThemeNotifier>().isDarkMode;
    final ann = context.watch<AnnouncementStore>();
    final notif = context.watch<NotificationStore>();
    final c = _C(dark);
    final desktop = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, cons) {
            final cw = cons.maxWidth;
            final side = responsiveSidePadding(
              cw,
              maxWidth: desktop ? 1280 : 760,
            );
            final twoCol = desktop && cw >= 900;

            final carousel = _carousel(c, ann, desktop ? 208 : 190);
            final stats = _stats(c, notif.unreadCount + ann.unreadCount);
            final today = _todaySection(c);
            final exams = _examsSection(c);
            final actions = _actionsSection(c);
            final info = _infoCard(c);
            final tips = _tipsSection(c, desktop && cw >= 700);
            final download = kIsWeb ? _downloadCard(c) : const SizedBox.shrink();

            final List<Widget> content;
            if (twoCol) {
              content = [
                _header(c, desktop: true),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: staggered([
                          carousel,
                          const SizedBox(height: 22),
                          today,
                          const SizedBox(height: 26),
                          stats,
                          const SizedBox(height: 26),
                          tips,
                        ], startMs: 80),
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 340,
                      child: Column(
                        children: staggered([
                          info,
                          const SizedBox(height: 22),
                          exams,
                          const SizedBox(height: 22),
                          actions,
                          if (kIsWeb) const SizedBox(height: 22),
                          download,
                        ], startMs: 160),
                      ),
                    ),
                  ],
                ),
              ];
            } else {
              content = staggered([
                _header(c, desktop: false),
                const SizedBox(height: 20),
                carousel,
                const SizedBox(height: 20),
                today,
                const SizedBox(height: 26),
                stats,
                const SizedBox(height: 26),
                exams,
                const SizedBox(height: 26),
                actions,
                const SizedBox(height: 26),
                info,
                const SizedBox(height: 26),
                tips,
                if (kIsWeb) ...[const SizedBox(height: 22), download],
              ], stepMs: 70);
            }

            return RefreshIndicator(
              onRefresh: _loadAll,
              color: _blue,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(side, 16, side, 40),
                children: content,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _header(_C c, {required bool desktop}) {
    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_greeting,',
              style: TextStyle(fontSize: desktop ? 16 : 14, color: c.sub),
            ),
            const SizedBox(width: 6),
            const WavingHand(size: 18),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _firstName.isNotEmpty ? _firstName : 'Student',
          style: TextStyle(
            fontSize: desktop ? 34 : 26,
            fontWeight: FontWeight.w900,
            color: c.text,
          ),
        ),
      ],
    );

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: greetingBlock),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: c.shadow,
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
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        PressScale(
          onTap: () => widget.onNavigate(3),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blueLight, _blueDark],
              ),
            ),
            child: Center(
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: greetingBlock),
        BellButton(isDark: c.dark, badgeBorder: c.bg),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CAROUSEL
  // ══════════════════════════════════════════════════════════
  Widget _carousel(_C c, AnnouncementStore ann, double height) {
    final slides = <Widget>[
      _classSlide(),
      _examSlide(),
      if (ann.items.isNotEmpty) _announcementSlide(ann),
      _tipSlide(),
    ];
    _slideCount = slides.length;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _page,
            itemCount: slides.length,
            itemBuilder: (_, i) => AnimatedBuilder(
              animation: _page,
              builder: (context, child) {
                double p = i.toDouble();
                if (_page.hasClients && _page.position.haveDimensions) {
                  p = _page.page ?? i.toDouble();
                }
                final d = (p - i).abs().clamp(0.0, 1.0);
                return Transform.scale(
                  scale: 1 - 0.06 * d,
                  child: Opacity(opacity: 1 - 0.25 * d, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: slides[i],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _page,
          builder: (_, __) {
            int cur = 0;
            if (_page.hasClients && _page.position.haveDimensions) {
              cur = (_page.page ?? 0).round();
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == cur ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == cur
                          ? _blue
                          : (c.dark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _slide({
    required List<Color> colors,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -70,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, {bool live = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        live
            ? const PulseDot(color: Colors.greenAccent, size: 7)
            : Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // Slide 1 — next / current class
  Widget _classSlide() {
    final next = _nextClass;
    if (next == null) {
      final none = _todayClasses.isEmpty;
      return _slide(
        colors: const [_blueLight, _blueDark],
        onTap: () => widget.onNavigate(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag(Icons.calendar_today_rounded, 'TODAY'),
            const Spacer(),
            Text(
              none ? 'No classes today' : 'You\'re done for today 🎉',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadingRemote
                  ? 'Loading your timetable…'
                  : 'Plan a study session or review your timetable.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final st = _status(next);
    final live = st == _Status.ongoing;
    final s = _mins(next.startTime), en = _mins(next.endTime), n = _nowMin;
    final progress = live ? ((n - s) / (en - s)).clamp(0.0, 1.0) : 0.0;

    return _slide(
      colors: const [_blueLight, _blueDark],
      onTap: () => widget.onNavigate(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag(
                Icons.schedule_rounded,
                live ? 'HAPPENING NOW' : 'NEXT CLASS',
                live: live,
              ),
              const Spacer(),
              Text(
                live
                    ? 'Ends in ${_fmtMin(en - n)}'
                    : 'Starts in ${_fmtMin(s - n)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            next.courseCode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (next.courseTitle.isNotEmpty)
            Text(
              next.courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(Icons.access_time_rounded, '${next.startTime} – ${next.endTime}'),
              if (next.venue.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: _pill(Icons.location_on_outlined, next.venue)),
              ],
            ],
          ),
          if (live) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Slide 3 — next exam
  Widget _examSlide() {
    final list = _upcomingExams;
    if (list.isEmpty) {
      return _slide(
        colors: const [_purple, _blue],
        onTap: () => widget.onNavigate(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag(Icons.event_note_rounded, 'EXAMS'),
            const Spacer(),
            const Text(
              'No exams scheduled',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your exam countdown will appear here.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    final e = list.first;
    final left = _daysLeft(e.date!);
    return _slide(
      colors: const [_purple, _blue],
      onTap: () => widget.onNavigate(1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tag(Icons.event_note_rounded, 'NEXT EXAM'),
                const Spacer(),
                Text(
                  e.courseCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (e.courseTitle.isNotEmpty)
                  Text(
                    e.courseTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                const SizedBox(height: 10),
                _pill(
                  Icons.calendar_today_rounded,
                  '${e.date!.day} ${_months[e.date!.month - 1]} · ${e.startTime}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                left == 0
                    ? const Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : AnimatedCount(
                        value: left.toDouble(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                if (left != 0)
                  Text(
                    left == 1 ? 'day left' : 'days left',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 4 — latest announcement
  Widget _announcementSlide(AnnouncementStore ann) {
    final Announcement a = ann.items.first;
    final unread = ann.unreadCount;
    return _slide(
      colors: const [_blue, _teal],
      onTap: () {
        ann.markRead(a.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnnouncementDetailScreen(announcement: a),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag(Icons.campaign_rounded, 'ANNOUNCEMENT'),
              const Spacer(),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread new',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            a.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${a.adminName} · ${_timeAgo(a.createdAt)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Slide 5 — tip of the day
  Widget _tipSlide() {
    final t = _tips[DateTime.now().day % _tips.length];
    return _slide(
      colors: const [_purple, _teal],
      child: Row(
        children: [
          Text(t.$1, style: const TextStyle(fontSize: 46)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tag(Icons.lightbulb_outline_rounded, 'TIP OF THE DAY'),
                const SizedBox(height: 10),
                Text(
                  t.$2,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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
  //  STATS
  // ══════════════════════════════════════════════════════════
  Widget _stats(_C c, int unread) {
    Widget tile(
      IconData icon,
      Color color,
      int value,
      String label,
      VoidCallback onTap,
    ) => Expanded(
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: c.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 12),
              AnimatedCount(
                value: value.toDouble(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, color: c.sub)),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        tile(
          Icons.calendar_today_rounded,
          _blue,
          _todayClasses.length,
          'Classes today',
          () => widget.onNavigate(1),
        ),
        const SizedBox(width: 12),
        tile(
          Icons.event_note_rounded,
          _purple,
          _upcomingExams.length,
          'Upcoming exams',
          () => widget.onNavigate(1),
        ),
        const SizedBox(width: 12),
        tile(
          Icons.notifications_active_rounded,
          _teal,
          unread,
          'Unread',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    _C c,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                action,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  TODAY'S CLASSES
  // ══════════════════════════════════════════════════════════
  Widget _todaySection(_C c) {
    final list = _todayClasses;
    final n = DateTime.now();

    Widget body;
    if (_loadingRemote && _lectures.isEmpty) {
      body = Column(
        children: const [
          Skeleton(height: 74),
          SizedBox(height: 10),
          Skeleton(height: 74),
        ],
      );
    } else if (list.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: c.shadow,
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.weekend_rounded,
                color: _blue.withOpacity(0.6),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No classes today',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Enjoy the free time',
              style: TextStyle(fontSize: 12, color: c.sub),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 120 + i * 70),
                offset: const Offset(0.06, 0),
                child: _classRow(c, list[i]),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          c,
          'Today\'s classes',
          action: 'Timetable',
          onAction: () => widget.onNavigate(1),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${_days[n.weekday - 1]} · ${list.length} ${list.length == 1 ? 'class' : 'classes'}',
            style: TextStyle(fontSize: 12, color: c.sub),
          ),
        ),
        body,
      ],
    );
  }

  Widget _classRow(_C c, LectureEntry e) {
    final st = _status(e);
    final s = _mins(e.startTime), en = _mins(e.endTime), n = _nowMin;
    final progress = st == _Status.ongoing && en > s
        ? ((n - s) / (en - s)).clamp(0.0, 1.0)
        : 0.0;
    return ClassCard(
      entry: e,
      isDark: c.dark,
      // both enums have the same order
      status: ClassStatus.values[st.index],
      progress: progress,
      onTap: () => widget.onNavigate(1),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  UPCOMING EXAMS
  // ══════════════════════════════════════════════════════════
  Widget _examsSection(_C c) {
    final list = _upcomingExams.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          c,
          'Upcoming exams',
          action: list.isEmpty ? null : 'See all',
          onAction: () => widget.onNavigate(1),
        ),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: c.shadow,
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, color: _purple.withOpacity(0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _loadingRemote ? 'Loading…' : 'No exams scheduled yet',
                    style: TextStyle(fontSize: 13, color: c.sub),
                  ),
                ),
              ],
            ),
          )
        else
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _examRow(c, e),
            ),
      ],
    );
  }

  Widget _examRow(_C c, LectureEntry e) {
    final d = e.date!;
    final left = _daysLeft(d);
    final chip = left <= 3
        ? Colors.red
        : left <= 7
        ? Colors.orange
        : Colors.grey;
    return PressScale(
      onTap: () => widget.onNavigate(1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: c.shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${d.day}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _purple,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _months[d.month - 1].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.courseCode,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                  Text(
                    '${e.startTime} – ${e.endTime}${e.venue.isNotEmpty ? ' · ${e.venue}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.sub),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: chip.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                left == 0
                    ? 'TODAY'
                    : left == 1
                    ? '1 DAY'
                    : '$left DAYS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: chip,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  QUICK ACTIONS
  // ══════════════════════════════════════════════════════════
  Widget _actionsSection(_C c) {
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) =>
        Expanded(
          child: PressScale(
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
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(c, 'Quick actions'),
        Row(
          children: [
            action(
              Icons.calendar_month_rounded,
              'Timetable',
              _blue,
              () => widget.onNavigate(1),
            ),
            action(
              Icons.school_rounded,
              'Grades',
              _teal,
              () => widget.onNavigate(2),
            ),
            action(
              Icons.campaign_rounded,
              'News',
              _purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(initialTab: 1),
                ),
              ),
            ),
            action(
              Icons.settings_rounded,
              'Settings',
              Colors.orange,
              () => widget.onNavigate(3),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ACADEMIC INFO / TIPS / DOWNLOAD
  // ══════════════════════════════════════════════════════════
  Widget _infoCard(_C c) {
    Widget row(IconData icon, String label, String value, Color color) => Row(
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
              Text(label, style: TextStyle(fontSize: 11, color: c.sub)),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(c, 'Academic info'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: c.shadow,
          ),
          child: Column(
            children: [
              row(Icons.account_balance_outlined, 'Department', _department, _teal),
              const SizedBox(height: 14),
              row(
                Icons.stairs_outlined,
                'Level',
                _level.isNotEmpty ? '$_level Level' : '',
                _purple,
              ),
              const SizedBox(height: 14),
              row(Icons.account_balance_rounded, 'School', _school, _blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tipsSection(_C c, bool grid) {
    Widget tip((String, String) t) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: c.shadow,
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
                color: c.dark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(c, 'Study tips'),
        if (grid)
          ResponsiveGrid(
            columns: 2,
            spacing: 12,
            runSpacing: 12,
            children: [for (final t in _tips) tip(t)],
          )
        else
          for (final t in _tips)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: tip(t)),
      ],
    );
  }

  Widget _downloadCard(_C c) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(22),
      boxShadow: c.shadow,
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
                      color: c.text,
                    ),
                  ),
                  Text(
                    'Take SchoolLife with you',
                    style: TextStyle(fontSize: 12, color: c.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              // NOTE: backend URL and APK file name are unchanged on purpose.
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
      ],
    ),
  );
}