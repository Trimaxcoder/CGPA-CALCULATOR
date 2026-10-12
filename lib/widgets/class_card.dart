// ══════════════════════════════════════════════════════════
//  CLASS CARD  (shared by Home "Today's classes" and the Timetable)
//  Time block on the left, course info in the middle, optional trailing
//  actions, optional footer (flag chips), live progress bar.
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../models/timetable_entry.dart';
import 'animations.dart';

enum ClassStatus { upcoming, ongoing, done, cancelled }

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

int classMinutes(String t) {
  final p = t.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
  return h * 60 + m;
}

int _nowMinutes() {
  final n = DateTime.now();
  return n.hour * 60 + n.minute;
}

/// Status right now. `null` when the class is on another day
/// (cancelled classes always report cancelled).
ClassStatus? classStatusOf(LectureEntry e) {
  if (e.isCancelled) return ClassStatus.cancelled;
  if (e.day != _days[DateTime.now().weekday - 1]) return null;
  final n = _nowMinutes();
  if (n < classMinutes(e.startTime)) return ClassStatus.upcoming;
  if (n >= classMinutes(e.endTime)) return ClassStatus.done;
  return ClassStatus.ongoing;
}

double classProgressOf(LectureEntry e) {
  final s = classMinutes(e.startTime), en = classMinutes(e.endTime);
  if (en <= s) return 0;
  return ((_nowMinutes() - s) / (en - s)).clamp(0.0, 1.0);
}

String formatMinutes(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

Color classTypeColor(String type) {
  switch (type) {
    case 'test':
      return Colors.red;
    case 'impromptu':
      return Colors.orange;
    case 'meeting':
      return Colors.purple;
    default:
      return const Color(0xFF1565C0);
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.entry,
    required this.isDark,
    this.status,
    this.progress = 0,
    this.trailing,
    this.footer,
    this.onTap,
  });

  final LectureEntry entry;
  final bool isDark;

  /// null = no status chip (e.g. a class on another day)
  final ClassStatus? status;

  /// 0–1, only drawn while [status] is ongoing
  final double progress;

  /// small actions on the right (mute, menu...)
  final Widget? trailing;

  /// extra row below the card body (flag chips...)
  final Widget? footer;

  final VoidCallback? onTap;

  static const Color _blue = Color(0xFF1565C0);

  String _duration() {
    final d = classMinutes(entry.endTime) - classMinutes(entry.startTime);
    return d <= 0 ? '' : formatMinutes(d);
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final st = status;
    final live = st == ClassStatus.ongoing;
    final cancelled = st == ClassStatus.cancelled;
    final done = st == ClassStatus.done;

    final base = classTypeColor(e.classType);
    final accent = cancelled
        ? Colors.red
        : done
        ? Colors.grey
        : base;

    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final dur = _duration();
    final special = e.classType != 'normal';

    // status chip
    String? chipText;
    Color chipColor = accent;
    if (st != null) {
      switch (st) {
        case ClassStatus.ongoing:
          chipText = 'LIVE';
          chipColor = Colors.green;
          break;
        case ClassStatus.upcoming:
          final left = classMinutes(e.startTime) - _nowMinutes();
          chipText = 'IN ${formatMinutes(left).toUpperCase()}';
          break;
        case ClassStatus.done:
          chipText = 'DONE';
          break;
        case ClassStatus.cancelled:
          chipText = 'CANCELLED';
          break;
      }
    }

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15181D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: live
            ? Border.all(color: _blue.withOpacity(0.55), width: 1.4)
            : (e.isImportant && !cancelled
                  ? Border.all(color: base.withOpacity(0.4), width: 1.2)
                  : null),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── time block ──
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        e.startTime,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        e.endTime,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent.withOpacity(0.7),
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
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dur,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── info ──
                Expanded(
                  child: Opacity(
                    opacity: done ? 0.6 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                e.courseCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: text,
                                  decoration: cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (special) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: base.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  e.classType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: base,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                        if (e.venue.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: accent.withOpacity(0.8),
                              ),
                              const SizedBox(width: 3),
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
                        if (chipText != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (live) ...[
                                  const PulseDot(color: Colors.green, size: 6),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  chipText,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: chipColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // ── live progress ──
          if (live)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: _blue.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation(_blue),
              ),
            ),

          // ── footer ──
          if (footer != null) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: footer!,
            ),
          ],
        ],
      ),
    );

    return onTap == null ? card : PressScale(onTap: onTap, child: card);
  }
}