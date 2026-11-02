// lib/models/term_info.dart

/// One semester of a school's academic calendar.
class TermSemester {
  final String term;     // "2025/2026-1"
  final String session;  // "2025/2026"
  final int semester;    // 1 or 2
  final DateTime startDate;
  final DateTime endDate;

  const TermSemester({
    required this.term,
    required this.session,
    required this.semester,
    required this.startDate,
    required this.endDate,
  });

  factory TermSemester.fromMap(Map<String, dynamic> m) => TermSemester(
        term:      m['term'] as String,
        session:   m['session'] as String,
        semester:  (m['semester'] as num).toInt(),
        // The server sends UTC; show it in the user's timezone.
        startDate: DateTime.parse(m['startDate'] as String).toLocal(),
        endDate:   DateTime.parse(m['endDate'] as String).toLocal(),
      );

  String get label => 'Semester $semester · $session';
}

/// Where the user's school is in its calendar right now.
class TermInfo {
  /// 'active' (a semester is running), 'break' (between semesters or the
  /// session has ended) or 'unconfigured' (no calendar set for this school).
  final String status;
  final TermSemester? current;
  final TermSemester? upcoming;
  final TermSemester? previous;
  final String? targetTerm;

  const TermInfo({
    required this.status,
    this.current,
    this.upcoming,
    this.previous,
    this.targetTerm,
  });

  static const unconfigured = TermInfo(status: 'unconfigured');

  factory TermInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return TermInfo.unconfigured;

    TermSemester? sem(dynamic v) =>
        v is Map<String, dynamic> ? TermSemester.fromMap(v) : null;

    return TermInfo(
      status:     m['status'] as String? ?? 'unconfigured',
      current:    sem(m['current']),
      upcoming:   sem(m['upcoming']),
      previous:   sem(m['previous']),
      targetTerm: m['targetTerm'] as String?,
    );
  }

  bool get isConfigured => status != 'unconfigured';
  bool get isActive => status == 'active';
  bool get isBreak => status == 'break';
}

/// "2025/2026-1" -> "Semester 1 · 2025/2026"
String termLabel(String term) {
  final i = term.lastIndexOf('-');
  if (i < 0) return term;
  return 'Semester ${term.substring(i + 1)} · ${term.substring(0, i)}';
}