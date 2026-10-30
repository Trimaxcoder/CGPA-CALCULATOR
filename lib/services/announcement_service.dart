// lib/services/announcement_service.dart
import 'api_service.dart';
import '../models/announcement.dart';

/// What the logged-in user is allowed to post, as decided by the server.
class PostingRights {
  final bool isAdmin;
  final bool isSuperAdmin;
  final String department;
  final String level;

  const PostingRights({
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.department,
    required this.level,
  });

  factory PostingRights.fromStatus(Map<String, dynamic> m) {
    final scope = m['adminScope'] as Map<String, dynamic>?;
    return PostingRights(
      isAdmin:      m['isAdmin'] == true,
      isSuperAdmin: m['isSuperAdmin'] == true,
      department:   scope?['department'] as String? ?? '',
      level:        scope?['level'] as String? ?? '',
    );
  }

  /// A rep can post only when their verified class is set.
  bool get canPostClass =>
      isAdmin && department.isNotEmpty && level.isNotEmpty;
  bool get canPostGlobal => isSuperAdmin;
  bool get canPost => canPostClass || canPostGlobal;

  String get classLabel => '$department · $level Level';
}

class AnnouncementService {
  static final _client = ApiClient();

  // Longest we wait for the announcements feed before giving up.
  // The store catches the timeout, so the app keeps its cached list.
  static const _feedTimeout = Duration(seconds: 12);

  /// GET /announcements — one page of the scoped feed.
  /// [scope]: 'global' | 'class' | null (both). Pass [before] = the previous
  /// page's nextCursor to load older announcements.
  static Future<({List<Announcement> items, bool hasMore, String? nextCursor})>
      fetchPage({String? scope, String? before, int limit = 20}) async {
    final path = Uri(
      path: '/announcements',
      queryParameters: {
        'limit': '$limit',
        if (scope != null) 'scope': scope,
        if (before != null) 'before': before,
      },
    ).toString();

    final data = await _client.get(path).timeout(_feedTimeout);
    final list = data['announcements'] as List<dynamic>;
    return (
      items: list
          .map((e) => Announcement.fromMap(e as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// Same behaviour as before: the latest announcements for this user
  /// (global + own class), up to 50.
  static Future<List<Announcement>> fetchAnnouncements() async {
    final page = await fetchPage(limit: 50);
    return page.items;
  }

  /// GET /announcements/:id — used when opening one from a push notification
  static Future<Announcement> fetchAnnouncement(String id) async {
    final data = await _client.get('/announcements/$id');
    return Announcement.fromMap(data['announcement'] as Map<String, dynamic>);
  }

  /// GET /announcements/mine — what this admin / super admin has posted
  static Future<List<Announcement>> fetchMyAnnouncements() async {
    final data = await _client.get('/announcements/mine');
    final list = data['announcements'] as List<dynamic>;
    return list
        .map((e) => Announcement.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /admin/status — tells the compose screen who the user is and,
  /// for reps, which class they are verified for.
  static Future<PostingRights> fetchPostingRights() async {
    final data = await _client.get('/admin/status');
    return PostingRights.fromStatus(data);
  }

  /// POST /announcements
  /// [scope]: 'class' (course rep, goes to their own class — the server
  /// decides which) or 'global' (super admin, goes to everyone).
  static Future<({Announcement announcement, int notifiedCount})>
      postAnnouncement({
    required String title,
    required String message,
    required String scope,
  }) async {
    final data = await _client.post('/announcements', {
      'title':   title,
      'message': message,
      'scope':   scope,
    });
    return (
      announcement: Announcement.fromMap(
          data['announcement'] as Map<String, dynamic>),
      notifiedCount: data['notifiedCount'] as int? ?? 0,
    );
  }

  /// PUT /announcements/:id
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

  /// DELETE /announcements/:id — hard delete for everyone
  static Future<void> deleteAnnouncement(String id) async {
    await _client.delete('/announcements/$id');
  }
}