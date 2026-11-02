// lib/widgets/term_banner.dart
//
// Shows students and course reps where the school is in its calendar:
//   - semester break            -> class updates are paused, next start date
//   - semester running, but no  -> students: "your rep hasn't set it up yet"
//     timetable for it yet         reps: a "Set up semester" button
//   - semester running          -> a slim "Semester 1 · 2025/2026 · ends …" line
// Shows nothing for schools that have no academic calendar.

import 'package:flutter/material.dart';
import '../models/term_info.dart';
import '../services/timetable_service.dart';
import 'snackBar.dart';

const Color _primary = Color(0xFF1565C0);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

class TermBanner extends StatelessWidget {
  final TermInfo? term;
  final bool setupNeeded;
  final bool preparing;
  final bool isAdmin;
  final bool isDark;

  /// Called after a rep copies a timetable, so the screen can reload.
  final VoidCallback onSetupDone;

  /// Space around the banner. Only applied when something is shown.
  final EdgeInsets padding;

  const TermBanner({
    super.key,
    required this.term,
    required this.setupNeeded,
    required this.preparing,
    required this.isAdmin,
    required this.isDark,
    required this.onSetupDone,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final t = term;
    if (t == null || !t.isConfigured) return const SizedBox.shrink();

    Widget? child;

    if (t.isBreak) {
      final next = t.upcoming;
      if (isAdmin) {
        child = next != null
            ? _card(
                context,
                icon: Icons.pause_circle_rounded,
                color: Colors.orange,
                title: 'Semester break',
                body: preparing
                    ? 'You\'re preparing ${next.label}. Students will see it when the semester starts on ${_day(next.startDate)}.'
                    : 'Class updates are paused. ${next.label} starts on ${_day(next.startDate)}. Set it up now so it\'s ready.',
                action: 'Set up semester',
              )
            : _card(
                context,
                icon: Icons.hourglass_empty_rounded,
                color: Colors.orange,
                title: 'Waiting for the new session',
                body:
                    'Class updates are paused. The super admin needs to add the new session calendar before you can set up the next semester.',
              );
      } else {
        child = _card(
          context,
          icon: Icons.pause_circle_rounded,
          color: Colors.orange,
          title: 'Semester break',
          body: next != null
              ? 'Class updates are paused. ${next.label} starts on ${_day(next.startDate)}.'
              : 'Class updates are paused until the new session starts.',
        );
      }
    } else if (t.isActive && t.current != null) {
      final cur = t.current!;
      if (setupNeeded) {
        child = isAdmin
            ? _card(
                context,
                icon: Icons.playlist_add_rounded,
                color: _primary,
                title: 'This semester has no timetable yet',
                body:
                    '${cur.label} is running. Copy last time\'s classes, or add them one by one.',
                action: 'Set up semester',
              )
            : _card(
                context,
                icon: Icons.schedule_rounded,
                color: _primary,
                title: 'Timetable not published yet',
                body:
                    'Your course rep hasn\'t set up the ${cur.label} timetable yet. You\'ll get updates once it\'s ready.',
              );
      } else {
        child = _slim(cur);
      }
    }

    if (child == null) return const SizedBox.shrink();
    return Padding(padding: padding, child: child);
  }

  Widget _slim(TermSemester cur) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _primary.withOpacity(isDark ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_rounded,
                size: 16, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${cur.label} · ends ${_day(cur.endDate)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    String? action,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => showSemesterSetupSheet(
                        context,
                        isDark: isDark,
                        onDone: onSetupDone,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(action),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════
//  Set-up sheet (course reps)
// ══════════════════════════════════════════════════════════════════════════

Future<void> showSemesterSetupSheet(
  BuildContext context, {
  required bool isDark,
  required VoidCallback onDone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // stays phone-sized (and centered) on wide screens
    constraints: const BoxConstraints(maxWidth: 560),
    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SetupSheet(isDark: isDark, onDone: onDone),
  );
}

class _SetupSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onDone;
  const _SetupSheet({required this.isDark, required this.onDone});

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  final _svc = TimetableService();

  SemesterSetup? _setup;
  bool _loading = true;
  bool _copying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _svc.getSemesterSetup();
      if (mounted) setState(() => _setup = s);
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    setState(() => _copying = true);
    try {
      final n = await _svc.carryOverLastSemester();
      if (!mounted) return;
      AppSnackBar.auto(
        context,
        '✅ Copied $n class${n == 1 ? '' : 'es'}. Students are not notified.',
      );
      Navigator.pop(context);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _copying = false);
        AppSnackBar.auto(context, _clean(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black54;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 24,
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
            ..._content(text, sub),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Color text, Color sub) {
    if (_loading) {
      return const [
        SizedBox(height: 24),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 24),
      ];
    }

    if (_error != null) {
      return [
        Text('Could not load', style: _title(text)),
        const SizedBox(height: 6),
        Text(_error!, style: _body(sub)),
        const SizedBox(height: 12),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ];
    }

    final s = _setup!;
    final target = s.targetTerm;

    // No semester to set up yet
    if (target == null) {
      return [
        Text('Nothing to set up yet', style: _title(text)),
        const SizedBox(height: 6),
        Text(
          'The super admin needs to add the new session calendar first.',
          style: _body(sub),
        ),
        const SizedBox(height: 16),
        _closeButton(),
      ];
    }

    final label = termLabel(target);

    // Already has classes
    if (s.lectureCount > 0) {
      return [
        Text(label, style: _title(text)),
        const SizedBox(height: 6),
        Text(
          'This semester already has ${s.lectureCount} '
          'class${s.lectureCount == 1 ? '' : 'es'}. You can keep adding or '
          'editing them from the timetable.',
          style: _body(sub),
        ),
        const SizedBox(height: 16),
        _closeButton(),
      ];
    }

    // Can copy from an earlier semester
    if (s.sourceTerm != null) {
      return [
        Text('Set up $label', style: _title(text)),
        const SizedBox(height: 6),
        Text(
          'Copy your class timetable from ${termLabel(s.sourceTerm!)} '
          '(${s.sourceCount} class${s.sourceCount == 1 ? '' : 'es'})?',
          style: _body(sub),
        ),
        const SizedBox(height: 6),
        Text(
          'Alerts are reset and students aren\'t notified. You can edit '
          'everything afterwards.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: sub.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _copying ? null : _copy,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _copying
                  ? 'Copying…'
                  : 'Copy ${s.sourceCount} class${s.sourceCount == 1 ? '' : 'es'}',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _copying ? null : () => Navigator.pop(context),
            child: const Text('I\'ll build it myself'),
          ),
        ),
      ];
    }

    // Nothing to copy
    return [
      Text('Set up $label', style: _title(text)),
      const SizedBox(height: 6),
      Text(
        'There\'s no earlier timetable to copy from. Use "Add Class" to build '
        'this semester\'s timetable.',
        style: _body(sub),
      ),
      const SizedBox(height: 16),
      _closeButton(),
    ];
  }

  TextStyle _title(Color c) =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c);

  TextStyle _body(Color c) => TextStyle(fontSize: 13.5, height: 1.45, color: c);

  Widget _closeButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Close'),
        ),
      );
}