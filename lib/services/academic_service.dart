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

/// One academic session of one school.
class AcademicCalendar {
  final String id;
  final String school;
  final String session;
  final List<SemesterDates> semesters;
  final DateTime? promotedAt;

  const AcademicCalendar({
    required this.id,
    required this.school,
    required this.session,
    required this.semesters,
    this.promotedAt,
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

  /// PUT /academic/calendars — create or update one session
  static Future<AcademicCalendar> saveCalendar({
    required String school,
    required String session,
    required List<SemesterDates> semesters,
  }) async {
    final data = await _client.put('/academic/calendars', {
      'school':    school,
      'session':   session,
      'semesters': semesters.map((s) => s.toMap()).toList(),
    });
    return AcademicCalendar.fromMap(data['calendar'] as Map<String, dynamic>);
  }

  /// DELETE /academic/calendars/:id
  static Future<void> deleteCalendar(String id) async {
    await _client.delete('/academic/calendars/$id');
  }
}