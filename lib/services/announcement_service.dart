// lib/services/announcement_service.dart
import 'api_service.dart';
import '../models/announcement.dart';

class AnnouncementService {
  static final _client = ApiClient();

  /// GET /announcements — scoped feed for the logged-in user
  static Future<List<Announcement>> fetchAnnouncements() async {
    final data = await _client.get('/announcements');
    final list = data['announcements'] as List<dynamic>;
    return list
        .map((e) => Announcement.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /announcements/mine — admin's own sent announcements
  static Future<List<Announcement>> fetchMyAnnouncements() async {
    final data = await _client.get('/announcements/mine');
    final list = data['announcements'] as List<dynamic>;
    return list
        .map((e) => Announcement.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /announcements — admin only
  static Future<({Announcement announcement, int notifiedCount})>
      postAnnouncement({
    required String title,
    required String message,
    required String level,
  }) async {
    final data = await _client.post('/announcements', {
      'title':   title,
      'message': message,
      'level':   level,
    });
    return (
      announcement: Announcement.fromMap(
          data['announcement'] as Map<String, dynamic>),
      notifiedCount: data['notifiedCount'] as int? ?? 0,
    );
  }

  /// PUT /announcements/:id — admin edits their own announcement
  static Future<Announcement> editAnnouncement({
    required String id,
    required String title,
    required String message,
    bool resend = false,
  }) async {
    final data = await _client.put('/announcements/$id', {
      'title':   title,
      'message': message,
      'resend':  resend,
    });
    return Announcement.fromMap(data['announcement'] as Map<String, dynamic>);
  }

  /// DELETE /announcements/:id — admin only, hard delete for everyone
  static Future<void> deleteAnnouncement(String id) async {
    await _client.delete('/announcements/$id');
  }
}