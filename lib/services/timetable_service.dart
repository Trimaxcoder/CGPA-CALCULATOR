import '../models/term_info.dart';
import '../services/api_service.dart';

/// Lecture timetable plus where the school is in its calendar.
class TimetableResult {
  final List<Map<String, dynamic>> entries;
  final TermInfo term;

  /// A semester is running but this class has no timetable for it yet.
  final bool setupNeeded;

  /// Course rep only: the entries shown are the next semester's (a preview).
  final bool preparing;

  const TimetableResult({
    required this.entries,
    required this.term,
    required this.setupNeeded,
    required this.preparing,
  });
}

/// What a course rep sees when setting up a semester.
class SemesterSetup {
  final TermInfo term;
  final String? targetTerm;     // the semester being set up
  final int lectureCount;       // classes already in it
  final int examCount;
  final String? sourceTerm;     // earlier semester that could be copied
  final int sourceCount;        // how many classes it has

  const SemesterSetup({
    required this.term,
    required this.targetTerm,
    required this.lectureCount,
    required this.examCount,
    required this.sourceTerm,
    required this.sourceCount,
  });

  factory SemesterSetup.fromMap(Map<String, dynamic> m) {
    final target = m['target'] as Map<String, dynamic>?;
    final source = m['source'] as Map<String, dynamic>?;
    return SemesterSetup(
      term:         TermInfo.fromMap(m['term'] as Map<String, dynamic>?),
      targetTerm:   target?['term'] as String?,
      lectureCount: (target?['lectureCount'] as num?)?.toInt() ?? 0,
      examCount:    (target?['examCount'] as num?)?.toInt() ?? 0,
      sourceTerm:   source?['term'] as String?,
      sourceCount:  (source?['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TimetableService {
  final _client = ApiClient();

  // ── Lecture ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLectures() async {
    final data = await _client.get('/timetable/lecture');
    return List<Map<String, dynamic>>.from(data['entries']);
  }

  /// Same as [getLectures] but also returns the semester state, so the
  /// timetable screen can explain an empty timetable.
  Future<TimetableResult> getLectureTimetable() async {
    final data = await _client.get('/timetable/lecture');
    return TimetableResult(
      entries:     List<Map<String, dynamic>>.from(data['entries']),
      term:        TermInfo.fromMap(data['term'] as Map<String, dynamic>?),
      setupNeeded: data['setupNeeded'] == true,
      preparing:   data['preparing'] == true,
    );
  }

  Future<Map<String, dynamic>> addLecture(Map<String, dynamic> entry) async {
    final data = await _client.post('/timetable/lecture', entry);
    return data['entry'];
  }

  Future<Map<String, dynamic>> updateLecture(
    String id,
    Map<String, dynamic> entry,
  ) async {
    final data = await _client.put('/timetable/lecture/$id', entry);
    return data['entry'];
  }

  Future<void> deleteLecture(String id) async {
    await _client.delete('/timetable/lecture/$id');
  }

  // ── Semester set-up (course reps) ─────────────────────────────────────────
  Future<SemesterSetup> getSemesterSetup() async {
    final data = await _client.get('/timetable/setup');
    return SemesterSetup.fromMap(data);
  }

  /// Copies the class timetable from the earlier semester into this one.
  /// Returns how many classes were copied.
  Future<int> carryOverLastSemester() async {
    final data = await _client.post('/timetable/setup/carry-over', {});
    return (data['copied'] as num?)?.toInt() ?? 0;
  }

  // ── Exam ──────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExams() async {
    final data = await _client.get('/timetable/exam');
    return List<Map<String, dynamic>>.from(data['entries']);
  }

  Future<Map<String, dynamic>> addExam(Map<String, dynamic> entry) async {
    final data = await _client.post('/timetable/exam', entry);
    return data['entry'];
  }

  Future<Map<String, dynamic>> updateExam(
    String id,
    Map<String, dynamic> entry,
  ) async {
    final data = await _client.put('/timetable/exam/$id', entry);
    return data['entry'];
  }

  Future<void> deleteExam(String id) async {
    await _client.delete('/timetable/exam/$id');
  }

  // ── Personal ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPersonal() async {
    final data = await _client.get('/timetable/personal');
    return List<Map<String, dynamic>>.from(data['entries']);
  }

  Future<Map<String, dynamic>> addPersonal(Map<String, dynamic> entry) async {
    final data = await _client.post('/timetable/personal', entry);
    return data['entry'];
  }

  Future<Map<String, dynamic>> updatePersonal(
    String id,
    Map<String, dynamic> entry,
  ) async {
    final data = await _client.put('/timetable/personal/$id', entry);
    return data['entry'];
  }

  Future<void> deletePersonal(String id) async {
    await _client.delete('/timetable/personal/$id');
  }

  Future<Map<String, dynamic>> toggleBookmark(String id) async {
    final data = await _client.put('/timetable/personal/$id/bookmark', {});
    return data['entry'];
  }

  Future<Map<String, dynamic>> toggleEmergency(String id) async {
    final data = await _client.put('/timetable/lecture/$id/emergency', {});
    return data['entry'];
  }

  Future<Map<String, dynamic>> toggleAlert(String id, String type) async {
    final data = await _client.put('/timetable/lecture/$id/alert/$type', {});
    return data['entry'];
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final data = await _client.get('/reminders');
    return List<Map<String, dynamic>>.from(data['reminders']);
  }

  Future<Map<String, dynamic>> setReminder(
    String lectureId,
    bool enabled,
    int minutesBefore,
  ) async {
    final data = await _client.put('/reminders/$lectureId', {
      'enabled': enabled,
      'minutesBefore': minutesBefore,
    });
    return data['reminder'];
  }

  // ── Admin ─────────────────────────────────────────────────────────────────
  Future<void> requestAdmin(Map<String, dynamic> body) async {
    await _client.post('/admin/request', body);
  }

  Future<Map<String, dynamic>> getAdminStatus() async {
    return await _client.get('/admin/status');
  }

  // ── Super Admin ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final data = await _client.get('/admin/pending');
    return List<Map<String, dynamic>>.from(data['requests']);
  }

  Future<void> reviewRequest(
    String id,
    String status, {
    String reviewNote = '',
  }) async {
    await _client.put('/admin/review/$id', {
      'status': status,
      'reviewNote': reviewNote,
    });
  }

  Future<void> resignAdmin() async {
    await _client.post('/admin/resign', {});
  }

  Future<void> revokeAdmin(String userId) async {
    await _client.delete('/admin/revoke/$userId');
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final data = await _client.get('/admin/all');
    return List<Map<String, dynamic>>.from(data['admins']);
  }

  // ── Notifications token ───────────────────────────────────────────────────
  Future<void> saveNotificationToken({
    required String token,
    required String school,
    required String faculty,
    required String department,
    required String level,
  }) async {
    await _client.post('/notifications/token', {
      'token': token,
      'school': school,
      'faculty': faculty,
      'department': department,
      'level': level,
    });
  }
}