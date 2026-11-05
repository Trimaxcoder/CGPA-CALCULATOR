// lib/services/academic_service.dart
import 'api_service.dart';

/// One school students have signed up with (super admin view).
class SchoolSummary {
  final String school;
  final int students;
  final List<String> sessions; // e.g. ["2025/2026", "2024/2025"]

  /// 'active' | 'break' | 'unconfigured'
  final String status;

  const SchoolSummary({
    required this.school,
    required this.students,
    required this.sessions,
    required this.status,
  });

  factory SchoolSummary.fromMap(Map<String, dynamic> m) => SchoolSummary(
        school:   m['school'] as String? ?? '',
        students: (m['students'] as num?)?.toInt() ?? 0,
        sessions: (m['sessions'] as List<dynamic>? ?? const []).cast<String>(),
        status:   m['status'] as String? ?? 'unconfigured',
      );
}

/// Start and end of one semester, as plain "YYYY-MM-DD" days.
class SemesterDates {
  final int number; // 1 or 2
  final String startDay;
  final String endDay;

  const SemesterDates({
    required this.number,
    required this.startDay,
    required this.endDay,
  });

  factory SemesterDates.fromMap(Map<String, dynamic> m) => SemesterDates(
        number:   (m['number'] as num).toInt(),
        startDay: m['startDay'] as String,
        endDay:   m['endDay'] as String,
      );

  Map<String, dynamic> toMap() => {
        'number':   number,
        'startDay': startDay,
        'endDay':   endDay,
      };
}

/// A department whose final-year level differs from the school's default.
class FinalLevelOverride {
  final String faculty;
  final String department;
  final String finalLevel; // "300" … "600"

  const FinalLevelOverride({
    required this.faculty,
    required this.department,
    required this.finalLevel,
  });

  factory FinalLevelOverride.fromMap(Map<String, dynamic> m) =>
      FinalLevelOverride(
        faculty:    m['faculty'] as String? ?? '',
        department: m['department'] as String? ?? '',
        finalLevel: m['finalLevel'] as String? ?? '400',
      );

  Map<String, dynamic> toMap() => {
        'faculty':    faculty,
        'department': department,
        'finalLevel': finalLevel,
      };
}

/// One academic session of one school.
class AcademicCalendar {
  final String id;
  final String school;
  final String session;
  final List<SemesterDates> semesters;
  final DateTime? promotedAt;

  /// Move students up automatically after the session ends.
  final bool autoPromote;

  /// Last level of most programs at this school ("300" … "600").
  final String finalLevel;
  final List<FinalLevelOverride> finalLevelOverrides;

  const AcademicCalendar({
    required this.id,
    required this.school,
    required this.session,
    required this.semesters,
    this.promotedAt,
    this.autoPromote = false,
    this.finalLevel = '400',
    this.finalLevelOverrides = const [],
  });

  /// A promoted session has ended and can no longer be changed.
  bool get isLocked => promotedAt != null;

  factory AcademicCalendar.fromMap(Map<String, dynamic> m) => AcademicCalendar(
        id:       m['id'] as String,
        school:   m['school'] as String? ?? '',
        session:  m['session'] as String? ?? '',
        semesters: (m['semesters'] as List<dynamic>? ?? const [])
            .map((e) => SemesterDates.fromMap(e as Map<String, dynamic>))
            .toList(),
        promotedAt: m['promotedAt'] != null
            ? DateTime.parse(m['promotedAt'] as String).toLocal()
            : null,
        autoPromote: m['autoPromote'] == true,
        finalLevel:  m['finalLevel'] as String? ?? '400',
        finalLevelOverrides:
            (m['finalLevelOverrides'] as List<dynamic>? ?? const [])
                .map((e) => FinalLevelOverride.fromMap(e as Map<String, dynamic>))
                .toList(),
      );
}

// ══════════════════════════════════════════════════════════════════════════
//  Promotion
// ══════════════════════════════════════════════════════════════════════════

class PromotionStats {
  final int total;
  final int promoted;
  final int graduated;
  final int repsMoved;
  final int repsEnded;
  final int skippedAlready;
  final int skippedLevel;

  const PromotionStats({
    this.total = 0,
    this.promoted = 0,
    this.graduated = 0,
    this.repsMoved = 0,
    this.repsEnded = 0,
    this.skippedAlready = 0,
    this.skippedLevel = 0,
  });

  factory PromotionStats.fromMap(Map<String, dynamic>? m) {
    int n(String k) => (m?[k] as num?)?.toInt() ?? 0;
    return PromotionStats(
      total:          n('total'),
      promoted:       n('promoted'),
      graduated:      n('graduated'),
      repsMoved:      n('repsMoved'),
      repsEnded:      n('repsEnded'),
      skippedAlready: n('skippedAlready'),
      skippedLevel:   n('skippedLevel'),
    );
  }
}

class PreviewLevel {
  final String level;
  final int count;

  /// 'promote' | 'graduate'
  final String outcome;

  const PreviewLevel({
    required this.level,
    required this.count,
    required this.outcome,
  });

  bool get graduates => outcome == 'graduate';

  factory PreviewLevel.fromMap(Map<String, dynamic> m) => PreviewLevel(
        level:   m['level'] as String? ?? '',
        count:   (m['count'] as num?)?.toInt() ?? 0,
        outcome: m['outcome'] as String? ?? 'promote',
      );
}

class PreviewDepartment {
  final String faculty;
  final String department;
  final String finalLevel;
  final List<PreviewLevel> levels;

  const PreviewDepartment({
    required this.faculty,
    required this.department,
    required this.finalLevel,
    required this.levels,
  });

  factory PreviewDepartment.fromMap(Map<String, dynamic> m) =>
      PreviewDepartment(
        faculty:    m['faculty'] as String? ?? '',
        department: m['department'] as String? ?? '',
        finalLevel: m['finalLevel'] as String? ?? '400',
        levels: (m['levels'] as List<dynamic>? ?? const [])
            .map((e) => PreviewLevel.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

/// What promotion would do right now. Nothing has changed yet.
class PromotionPreview {
  final String school;
  final String session;
  final String endsOn; // "YYYY-MM-DD" (Nigerian time)
  final DateTime dueAt;
  final bool ended;
  final bool alreadyPromoted;
  final bool autoPromote;
  final PromotionStats stats;
  final List<PreviewDepartment> departments;

  const PromotionPreview({
    required this.school,
    required this.session,
    required this.endsOn,
    required this.dueAt,
    required this.ended,
    required this.alreadyPromoted,
    required this.autoPromote,
    required this.stats,
    required this.departments,
  });

  factory PromotionPreview.fromMap(Map<String, dynamic> m) => PromotionPreview(
        school:  m['school'] as String? ?? '',
        session: m['session'] as String? ?? '',
        endsOn:  m['endsOn'] as String? ?? '',
        dueAt:   DateTime.parse(m['dueAt'] as String).toLocal(),
        ended:   m['ended'] == true,
        alreadyPromoted: m['alreadyPromoted'] == true,
        autoPromote:     m['autoPromote'] == true,
        stats: PromotionStats.fromMap(m['stats'] as Map<String, dynamic>?),
        departments: (m['departments'] as List<dynamic>? ?? const [])
            .map((e) => PreviewDepartment.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One past promotion run.
class PromotionRunInfo {
  final String id;
  final String school;
  final String session;
  final String mode; // 'auto' | 'manual'
  final String status;
  final PromotionStats stats;
  final DateTime createdAt;
  final DateTime? undoneAt;
  final bool canUndo;

  const PromotionRunInfo({
    required this.id,
    required this.school,
    required this.session,
    required this.mode,
    required this.status,
    required this.stats,
    required this.createdAt,
    required this.undoneAt,
    required this.canUndo,
  });

  factory PromotionRunInfo.fromMap(Map<String, dynamic> m) => PromotionRunInfo(
        id:      m['id'] as String,
        school:  m['school'] as String? ?? '',
        session: m['session'] as String? ?? '',
        mode:    m['mode'] as String? ?? 'manual',
        status:  m['status'] as String? ?? 'done',
        stats:   PromotionStats.fromMap(m['stats'] as Map<String, dynamic>?),
        createdAt: DateTime.parse(m['createdAt'] as String).toLocal(),
        undoneAt: m['undoneAt'] != null
            ? DateTime.parse(m['undoneAt'] as String).toLocal()
            : null,
        canUndo: m['canUndo'] == true,
      );
}

class AcademicService {
  static final _client = ApiClient();

  /// GET /academic/schools — super admin
  static Future<List<SchoolSummary>> fetchSchools() async {
    final data = await _client.get('/academic/schools');
    return (data['schools'] as List<dynamic>)
        .map((e) => SchoolSummary.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /academic/calendars?school=… — super admin
  static Future<List<AcademicCalendar>> fetchCalendars(String school) async {
    final path = Uri(
      path: '/academic/calendars',
      queryParameters: {'school': school},
    ).toString();
    final data = await _client.get(path);
    return (data['calendars'] as List<dynamic>)
        .map((e) => AcademicCalendar.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /academic/calendars — create or update one session.
  /// Promotion settings are only sent when given; anything left out keeps
  /// its current value on the server.
  static Future<AcademicCalendar> saveCalendar({
    required String school,
    required String session,
    required List<SemesterDates> semesters,
    bool? autoPromote,
    String? finalLevel,
    List<FinalLevelOverride>? finalLevelOverrides,
  }) async {
    final data = await _client.put('/academic/calendars', {
      'school':    school,
      'session':   session,
      'semesters': semesters.map((s) => s.toMap()).toList(),
      if (autoPromote != null) 'autoPromote': autoPromote,
      if (finalLevel != null) 'finalLevel': finalLevel,
      if (finalLevelOverrides != null)
        'finalLevelOverrides':
            finalLevelOverrides.map((o) => o.toMap()).toList(),
    });
    return AcademicCalendar.fromMap(data['calendar'] as Map<String, dynamic>);
  }

  /// DELETE /academic/calendars/:id
  static Future<void> deleteCalendar(String id) async {
    await _client.delete('/academic/calendars/$id');
  }

  // ── Promotion ─────────────────────────────────────────────────────────────

  /// GET /academic/calendars/:id/promotion/preview — changes nothing
  static Future<PromotionPreview> fetchPromotionPreview(
    String calendarId,
  ) async {
    final data =
        await _client.get('/academic/calendars/$calendarId/promotion/preview');
    return PromotionPreview.fromMap(data['preview'] as Map<String, dynamic>);
  }

  /// POST /academic/calendars/:id/promotion/run
  static Future<void> runPromotion(String calendarId) async {
    await _client.post(
      '/academic/calendars/$calendarId/promotion/run',
      {'confirm': true},
    );
  }

  /// GET /academic/promotions — recent runs, newest first
  static Future<List<PromotionRunInfo>> fetchPromotionRuns() async {
    final data = await _client.get('/academic/promotions');
    return (data['runs'] as List<dynamic>)
        .map((e) => PromotionRunInfo.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /academic/promotions/:id/undo — returns how many people were reverted
  static Future<int> undoPromotion(String runId) async {
    final data = await _client.post('/academic/promotions/$runId/undo', {});
    return (data['reverted'] as num?)?.toInt() ?? 0;
  }
}