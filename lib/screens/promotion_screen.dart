// lib/screens/promotion_screen.dart
//
// Super admin only. For one session of one school:
//   - preview exactly who would move up / graduate (nothing changes)
//   - set the final-year level for a department
//   - run the promotion now
//   - see past runs and undo one (within 30 days)

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
const Color _purple = Color(0xFF7C3AED);
const Color _teal = Color(0xFF0891B2);

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

String _prettyDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

class PromotionScreen extends StatefulWidget {
  final AcademicCalendar calendar;
  const PromotionScreen({super.key, required this.calendar});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  late AcademicCalendar _cal;
  PromotionPreview? _preview;
  List<PromotionRunInfo> _runs = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cal = widget.calendar;
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final preview = await AcademicService.fetchPromotionPreview(_cal.id);
      final allRuns = await AcademicService.fetchPromotionRuns();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _runs = allRuns
            .where((r) => r.school == _cal.school && r.session == _cal.session)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _run() async {
    final p = _preview!;
    final ok = await showConfirmDialog(
      context,
      title: 'Promote students now?',
      message:
          '${p.stats.promoted} will move up a level and ${p.stats.graduated} will graduate '
          '(${p.school}, ${p.session}). You can undo this for 30 days.',
      confirmLabel: 'Promote',
      icon: Icons.school_rounded,
      color: _primary,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await AcademicService.runPromotion(_cal.id);
      if (mounted) AppSnackBar.auto(context, '✅ Promotion complete');
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackBar.auto(context, _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo(PromotionRunInfo r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Undo this promotion?',
      message:
          'Students and reps go back to how they were. Anyone who already '
          'corrected their own level keeps their correction.',
      confirmLabel: 'Undo',
      icon: Icons.undo_rounded,
      color: Colors.red,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final n = await AcademicService.undoPromotion(r.id);
      if (mounted) {
        AppSnackBar.auto(context, 'Promotion undone ($n people restored)');
      }
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackBar.auto(context, _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editFinalLevel(PreviewDepartment d, bool isDark) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LevelSheet(department: d, isDark: isDark),
    );
    if (picked == null || picked == d.finalLevel) return;

    final updated = [
      for (final o in _cal.finalLevelOverrides)
        if (!(_same(o.faculty, d.faculty) && _same(o.department, d.department)))
          o,
      FinalLevelOverride(
        faculty: d.faculty,
        department: d.department,
        finalLevel: picked,
      ),
    ];

    setState(() => _busy = true);
    try {
      _cal = await AcademicService.saveCalendar(
        school: _cal.school,
        session: _cal.session,
        semesters: _cal.semesters,
        finalLevelOverrides: updated,
      );
      if (mounted) {
        AppSnackBar.auto(context, '${d.department}: final year set to $picked');
      }
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackBar.auto(context, _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    if (context.isExpanded) {
      return DesktopPage(
        title: 'Promotion',
        subtitle: '${_cal.school} · ${_cal.session}',
        maxWidth: 900,
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
            title: 'Promotion',
            subtitle: '${_cal.school} · ${_cal.session}',
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

    if (_error != null || _preview == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 52, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 14),
              Text(
                _error ?? 'Could not load',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _preview!;
    final side = desktop
        ? 0.0
        : responsiveSidePadding(MediaQuery.sizeOf(context).width,
            maxWidth: 720);

    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          side,
          4,
          side,
          MediaQuery.of(context).padding.bottom + 40,
        ),
        children: [
          _statusCard(p, isDark),
          const SizedBox(height: 14),
          _statsGrid(p.stats, isDark),
          if (p.stats.skippedAlready > 0 || p.stats.skippedLevel > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                [
                  if (p.stats.skippedAlready > 0)
                    '${p.stats.skippedAlready} already handled',
                  if (p.stats.skippedLevel > 0)
                    '${p.stats.skippedLevel} with a level that isn\'t 100–900 (left alone)',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ),
          const SizedBox(height: 18),
          _runSection(p, isDark),
          const SizedBox(height: 22),
          _sectionTitle('By department', isDark),
          _departments(p, isDark, desktop),
          if (_runs.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionTitle('History', isDark),
            for (final r in _runs) _runTile(r, isDark),
          ],
        ],
      ),
    );
  }

  // ── Pieces ────────────────────────────────────────────────────────────────

  Widget _panel(bool isDark, {required Widget child, Color? border}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
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
        ),
        child: child,
      );

  Widget _sectionTitle(String t, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      );

  Widget _statusCard(PromotionPreview p, bool isDark) {
    final IconData icon;
    final Color color;
    final String title;
    final String body;

    if (p.alreadyPromoted) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      title = 'Students have been moved up';
      body =
          'This session was promoted. If something looks wrong you can undo it for 30 days (see History).';
    } else if (p.ended) {
      icon = Icons.school_rounded;
      color = _primary;
      title = 'This session has ended';
      body = p.autoPromote
          ? 'Auto-promote is on: students move up automatically with the next morning check. You can also run it now.'
          : 'Auto-promote is off. Check the numbers below, then run it yourself.';
    } else {
      icon = Icons.event_rounded;
      color = Colors.orange;
      title = 'Session ends on ${_prettyDay(p.endsOn)}';
      body = p.autoPromote
          ? 'Students will move up automatically the day after. You can check what will happen below.'
          : 'Auto-promote is off, so nothing happens by itself. After the session ends you can run it from here.';
    }

    return _panel(
      isDark,
      border: color.withOpacity(0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(PromotionStats s, bool isDark) {
    final tiles = [
      ('Moving up', s.promoted, _primary, Icons.trending_up_rounded),
      ('Graduating', s.graduated, _purple, Icons.school_rounded),
      ('Reps moving up', s.repsMoved, _teal, Icons.verified_user_rounded),
      ('Reps ending', s.repsEnded, Colors.orange, Icons.person_off_rounded),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15181D) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(t.$4, color: t.$3, size: 20),
                      const SizedBox(height: 10),
                      Text(
                        '${t.$2}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        t.$1,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _runSection(PromotionPreview p, bool isDark) {
    final canRun = p.ended && !p.alreadyPromoted && p.stats.total > 0 && !_busy;

    String? hint;
    if (p.alreadyPromoted) {
      hint = 'Already promoted.';
    } else if (!p.ended) {
      hint = 'Available once the session has ended.';
    } else if (p.stats.total == 0) {
      hint =
          'No students were found for this school. Check that the school name matches what students entered.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canRun ? _run : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.school_rounded, size: 20),
            label: const Text('Promote students now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ),
      ],
    );
  }

  Widget _departments(PromotionPreview p, bool isDark, bool desktop) {
    if (p.departments.isEmpty) {
      return _panel(
        isDark,
        child: Text(
          'No students with a recognised level (100–900) were found.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }

    final cards = [
      for (final d in p.departments) _departmentCard(d, p, isDark),
    ];

    if (desktop) {
      return ResponsiveGrid(
        minItemWidth: 380,
        spacing: 14,
        runSpacing: 0,
        children: cards,
      );
    }
    return Column(children: cards);
  }

  Widget _departmentCard(PreviewDepartment d, PromotionPreview p, bool isDark) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black54;
    final editable = !p.alreadyPromoted && !_cal.isLocked && !_busy;

    return _panel(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.faculty.isEmpty
                      ? (d.department.isEmpty ? 'No department' : d.department)
                      : '${d.faculty} · ${d.department}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: editable ? () => _editFinalLevel(d, isDark) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Final year: ${d.finalLevel}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                      if (editable) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined,
                            size: 13, color: _primary),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in d.levels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      l.level,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                  ),
                  Icon(
                    l.graduates
                        ? Icons.school_rounded
                        : Icons.arrow_forward_rounded,
                    size: 15,
                    color: l.graduates ? _purple : _primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.graduates
                          ? 'Graduates'
                          : 'Moves to ${(int.tryParse(l.level) ?? 0) + 100}',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ),
                  Text(
                    '${l.count} student${l.count == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _runTile(PromotionRunInfo r, bool isDark) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return _panel(
      isDark,
      child: Row(
        children: [
          Icon(
            r.undoneAt != null ? Icons.undo_rounded : Icons.history_rounded,
            color: r.undoneAt != null ? Colors.grey : _primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.mode == 'auto' ? 'Automatic' : 'Manual'} · ${_prettyDate(r.createdAt)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.undoneAt != null
                      ? 'Undone on ${_prettyDate(r.undoneAt!)}'
                      : '${r.stats.promoted} moved up · ${r.stats.graduated} graduated',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
          if (r.canUndo)
            TextButton(
              onPressed: _busy ? null : () => _undo(r),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Undo'),
            ),
        ],
      ),
    );
  }
}

class _LevelSheet extends StatelessWidget {
  final PreviewDepartment department;
  final bool isDark;

  const _LevelSheet({required this.department, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const levels = ['300', '400', '500', '600', '700'];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
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
            'Final year for ${department.department.isEmpty ? 'this department' : department.department}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Students at this level (or above) graduate when the session ends. Everyone below moves up one level.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final l in levels)
                GestureDetector(
                  onTap: () => Navigator.pop(context, l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: l == department.finalLevel
                          ? _primary
                          : _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: l == department.finalLevel
                          ? null
                          : Border.all(color: _primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: l == department.finalLevel
                            ? Colors.white
                            : _primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}