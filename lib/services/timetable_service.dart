import '../services/api_service.dart';

class TimetableService {
  final _client = ApiClient();

  // ── Lecture ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLectures() async {
    final data = await _client.get('/timetable/lecture');
    return List<Map<String, dynamic>>.from(data['entries']);
  }

  Future<Map<String, dynamic>> addLecture(Map<String, dynamic> entry) async {
    final data = await _client.post('/timetable/lecture', entry);
    return data['entry'];
  }

  Future<Map<String, dynamic>> updateLecture(
      String id, Map<String, dynamic> entry) async {
    final data = await _client.put('/timetable/lecture/$id', entry);
    return data['entry'];
  }

  Future<void> deleteLecture(String id) async {
    await _client.delete('/timetable/lecture/$id');
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
      String id, Map<String, dynamic> entry) async {
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
      String id, Map<String, dynamic> entry) async {
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

Future<void> reviewRequest(String id, String status, {String reviewNote = ''}) async {
  await _client.put('/admin/review/$id', {
    'status':     status,
    'reviewNote': reviewNote,
  });
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