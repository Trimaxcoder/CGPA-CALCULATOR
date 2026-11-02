// lib/screens/academic_calendar_screen.dart
//
// Super admin only.
//   AcademicCalendarScreen  -> every school students have signed up with
//   SchoolCalendarScreen    -> one school's sessions, with add / edit / delete

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/academic_service.dart';
import '../utils/responsive.dart';
import '../widgets/app_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/page_header.dart';
import '../widgets/snackBar.dart';

const Color _primary = Color(0xFF1565C0);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

/// "2025-10-06" -> "6 Oct 2025"
String _prettyDay(String d) {
  final p = d.split('-');
  if (p.length != 3) return d;
  final m = int.tryParse(p[1]) ?? 1;
  final day = int.tryParse(p[2]) ?? 0;
  return '$day ${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
}

/// DateTime -> "2025-10-06" (the date as picked, no timezone shifting)
String _toDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A sensible default: Aug–Dec starts "this year/next", Jan–Jul is still
/// "last year/this".
String _suggestSession() {
  final n = DateTime.now();
  final start = n.month >= 8 ? n.year : n.year - 1;
  return '$start/${start + 1}';
}

({String label, Color color, IconData icon}) _statusStyle(String s) {
  switch (s) {
    case 'active':
      return (
        label: 'Semester running',
        color: Colors.green,
        icon: Icons.play_circle_rounded,
      );
    case 'break':
      return (
        label: 'On break',
        color: Colors.orange,
        icon: Icons.pause_circle_rounded,
      );
    default:
      return (
        label: 'Not set up',
        color: Colors.grey,
        icon: Icons.help_outline_rounded,
      );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Screen 1 — all schools
// ══════════════════════════════════════════════════════════════════════════

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  List<SchoolSummary> _schools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await AcademicService.fetchSchools();
      if (mounted) setState(() => _schools = list);
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(SchoolSummary s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SchoolCalendarScreen(school: s.school)),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    if (context.isExpanded) {
      return DesktopPage(
        title: 'Academic calendar',
        subtitle: 'Set each school\'s sessions and semester dates',
        maxWidth: 1100,
        actions: [
          DeskButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            isDark: isDark,
            onTap: _load,
          ),
        ],
        child: _body(isDark, desktop: true),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      body: Column(
        children: [
          MobileHeader(
            title: 'Academic calendar',
            subtitle: 'Sessions and semester dates per school',
            actions: [
              HeaderTile(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: () => _load(silent: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _body(isDark, desktop: false)),
        ],
      ),
    );
  }

  Widget _body(bool isDark, {required bool desktop}) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _StateMessage(
        isDark: isDark,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load schools',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_schools.isEmpty) {
      return _StateMessage(
        isDark: isDark,
        icon: Icons.school_outlined,
        title: 'No schools yet',
        subtitle: 'Schools appear here once students sign up.',
      );
    }

    final cards = [
      for (final s in _schools)
        _SchoolCard(school: s, isDark: isDark, onTap: () => _open(s)),
    ];

    if (desktop) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ResponsiveGrid(
            minItemWidth: 420,
            spacing: 14,
            runSpacing: 0,
            children: cards,
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: responsiveSidePadding(
            MediaQuery.sizeOf(context).width,
            maxWidth: 720,
          ),
          vertical: 8,
        ),
        children: cards,
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  final SchoolSummary school;
  final bool isDark;
  final VoidCallback onTap;

  const _SchoolCard({
    required this.school,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final st = _statusStyle(school.status);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: _primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school.school,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${school.students} student${school.students == 1 ? '' : 's'}'
                        ' · ${school.sessions.isEmpty ? 'No sessions set up' : school.sessions.join(' · ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: sub),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: st.color.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(st.icon, size: 13, color: st.color),
                            const SizedBox(width: 5),
                            Text(
                              st.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: st.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Screen 2 — one school's sessions
// ══════════════════════════════════════════════════════════════════════════

class SchoolCalendarScreen extends StatefulWidget {
  final String school;
  const SchoolCalendarScreen({super.key, required this.school});

  @override
  State<SchoolCalendarScreen> createState() => _SchoolCalendarScreenState();
}

class _SchoolCalendarScreenState extends State<SchoolCalendarScreen> {
  List<AcademicCalendar> _calendars = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await AcademicService.fetchCalendars(widget.school);
      if (mounted) setState(() => _calendars = list);
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(AcademicCalendar c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${c.session}?',
      message: 'This removes the semester dates for this session.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever_rounded,
      color: Colors.red,
    );
    if (!ok) return;

    try {
      await AcademicService.deleteCalendar(c.id);
      await _load(silent: true);
      if (mounted) AppSnackBar.auto(context, 'Session deleted');
    } catch (e) {
      if (mounted) AppSnackBar.auto(context, _clean(e));
    }
  }

  Future<void> _showEditor(bool isDark, {AcademicCalendar? editing}) async {
    final sessionCtrl = TextEditingController(
      text: editing?.session ?? _suggestSession(),
    );
    String? s1Start, s1End, s2Start, s2End;
    bool hasSecond = false;
    bool saving = false;

    if (editing != null) {
      for (final s in editing.semesters) {
        if (s.number == 1) {
          s1Start = s.startDay;
          s1End = s.endDay;
        }
        if (s.number == 2) {
          s2Start = s.startDay;
          s2End = s.endDay;
          hasSecond = true;
        }
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // stays phone-sized (and centered) on wide screens
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(
            String? current,
            void Function(String) assign,
          ) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.tryParse(current ?? '') ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) setS(() => assign(_toDay(picked)));
          }

          String? validate() {
            final session = sessionCtrl.text.trim();
            if (!RegExp(r'^\d{4}/\d{4}$').hasMatch(session)) {
              return 'Session must look like 2025/2026';
            }
            final a = int.parse(session.substring(0, 4));
            final b = int.parse(session.substring(5));
            if (b != a + 1) {
              return 'Session years must be consecutive, e.g. 2025/2026';
            }
            if (s1Start == null || s1End == null) {
              return 'Set both dates for semester 1';
            }
            if (s1End!.compareTo(s1Start!) <= 0) {
              return 'Semester 1 must end after it starts';
            }
            if (hasSecond) {
              if (s2Start == null || s2End == null) {
                return 'Set both dates for semester 2';
              }
              if (s2End!.compareTo(s2Start!) <= 0) {
                return 'Semester 2 must end after it starts';
              }
              if (s2Start!.compareTo(s1End!) <= 0) {
                return 'Semester 2 must start after semester 1 ends';
              }
            }
            return null;
          }

          Future<void> save() async {
            final err = validate();
            if (err != null) {
              AppSnackBar.auto(ctx, err);
              return;
            }
            setS(() => saving = true);
            try {
              await AcademicService.saveCalendar(
                school: widget.school,
                session: sessionCtrl.text.trim(),
                semesters: [
                  SemesterDates(number: 1, startDay: s1Start!, endDay: s1End!),
                  if (hasSecond)
                    SemesterDates(
                        number: 2, startDay: s2Start!, endDay: s2End!),
                ],
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) {
                setS(() => saving = false);
                AppSnackBar.auto(ctx, _clean(e));
              }
            }
          }

          Widget semester(
            String title,
            String? start,
            String? end,
            void Function(String) setStart,
            void Function(String) setEnd,
          ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 240,
                        child: _DateTile(
                          label: 'First day',
                          day: start,
                          isDark: isDark,
                          onTap: () => pick(start, setStart),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: _DateTile(
                          label: 'Last day (last exam)',
                          day: end,
                          isDark: isDark,
                          onTap: () => pick(end, setEnd),
                        ),
                      ),
                    ],
                  ),
                ],
              );

          return Padding(
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
                  const SizedBox(height: 16),
                  Text(
                    editing == null ? 'Add session' : 'Edit ${editing.session}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.school,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sessionCtrl,
                    enabled: editing == null, // a session can't be renamed
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Session',
                      hintText: '2025/2026',
                      prefixIcon: const Icon(Icons.event_note_rounded,
                          color: _primary, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  semester(
                    'Semester 1',
                    s1Start,
                    s1End,
                    (v) => s1Start = v,
                    (v) => s1End = v,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'This session has a second semester',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      Switch(
                        value: hasSecond,
                        onChanged: (v) => setS(() => hasSecond = v),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  if (hasSecond) ...[
                    const SizedBox(height: 8),
                    semester(
                      'Semester 2',
                      s2Start,
                      s2End,
                      (v) => s2Start = v,
                      (v) => s2End = v,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'When the last day passes, class notifications for this '
                    'school stop until the next semester starts. When the '
                    'session ends, students move up a level.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      await _load(silent: true);
      if (mounted) AppSnackBar.auto(context, '✅ Calendar saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    if (context.isExpanded) {
      return DesktopPage(
        title: widget.school,
        subtitle: 'Academic sessions',
        maxWidth: 900,
        actions: [
          DeskButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            isDark: isDark,
            onTap: _load,
          ),
          DeskButton(
            icon: Icons.add_rounded,
            label: 'Add session',
            isDark: isDark,
            onTap: () => _showEditor(isDark),
          ),
        ],
        child: _body(isDark, desktop: true),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(isDark),
        icon: const Icon(Icons.add),
        label: const Text('Add session'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          MobileHeader(
            title: 'Academic sessions',
            subtitle: widget.school,
            actions: [
              HeaderTile(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: () => _load(silent: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _body(isDark, desktop: false)),
        ],
      ),
    );
  }

  Widget _body(bool isDark, {required bool desktop}) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _StateMessage(
        isDark: isDark,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load sessions',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_calendars.isEmpty) {
      return _StateMessage(
        isDark: isDark,
        icon: Icons.event_busy_rounded,
        title: 'No sessions yet',
        subtitle:
            'Tap "Add session" to set this school\'s semester dates. Until you do, its timetable behaves as it does today.',
      );
    }

    final cards = [
      for (final c in _calendars)
        _SessionCard(
          cal: c,
          isDark: isDark,
          onEdit: () => _showEditor(isDark, editing: c),
          onDelete: () => _delete(c),
        ),
    ];

    final side = desktop
        ? 0.0
        : responsiveSidePadding(MediaQuery.sizeOf(context).width,
            maxWidth: 720);

    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, 8, side, 100),
        children: cards,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AcademicCalendar cal;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.cal,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      cal.session,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    if (cal.isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: sub),
                            const SizedBox(width: 4),
                            Text(
                              'Ended · students promoted',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!cal.isLocked) ...[
                IconButton(
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: _primary),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: Colors.red.shade300),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final s in cal.semesters)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withOpacity(isDark ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semester ${s.number}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_prettyDay(s.startDay)}  →  ${_prettyDay(s.endDay)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: text,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Small shared widgets
// ══════════════════════════════════════════════════════════════════════════

class _DateTile extends StatelessWidget {
  final String label;
  final String? day;
  final bool isDark;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.day,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 18, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      Text(
                        day == null ? 'Pick a date' : _prettyDay(day!),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: day == null
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87),
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
}

class _StateMessage extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 56, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      );
}