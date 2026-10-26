// lib/services/class_service.dart
//
// REST calls for the "Join a class" feature. Built on your existing ApiClient,
// so login tokens, automatic token refresh and error messages all work the
// same way as the rest of the app. Sending chat messages and anonymous posts
// happens over the socket (class_socket.dart), not here.

import '../models/class_models.dart';
import 'api_service.dart';

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return <T>[];
  return raw.map((e) => parse(e as Map<String, dynamic>)).toList();
}

class ClassService {
  final _client = ApiClient();

  // ══════════════════════════════════════════════════════════════════════════
  //  CLASSES
  // ══════════════════════════════════════════════════════════════════════════

  /// Classes I'm in, including ones still waiting for approval.
  Future<List<ClassRoom>> myClasses() async {
    final data = await _client.get('/classes');
    return _parseList(data['classes'], ClassRoom.fromMap);
  }

  Future<ClassRoom> create({
    required String name,
    String description = '',
    bool requireApproval = false,
  }) async {
    final data = await _client.post('/classes', {
      'name': name,
      'description': description,
      'requireApproval': requireApproval,
    });
    return ClassRoom.fromMap(data['class'] as Map<String, dynamic>);
  }

  /// Join with a 6-character code. If the class needs approval, the returned
  /// room has isPending == true.
  Future<ClassRoom> join(String code) async {
    final data = await _client.post('/classes/join', {'code': code});
    return ClassRoom.fromMap(data['class'] as Map<String, dynamic>);
  }

  /// Class details + the open anonymous session (if any) + pinned messages.
  Future<ClassDetails> details(String classId) async {
    final data = await _client.get('/classes/$classId');
    return ClassDetails.fromMap(data);
  }

  /// Admin: change class settings. Only the fields you pass are changed.
  Future<ClassRoom> update(
    String classId, {
    String? name,
    String? description,
    bool? requireApproval,
    bool? chatLocked,
  }) async {
    final data = await _client.put('/classes/$classId', {
      'name': ?name,
      'description': ?description,
      'requireApproval': ?requireApproval,
      'chatLocked': ?chatLocked,
    });
    return ClassRoom.fromMap(data['class'] as Map<String, dynamic>);
  }

  /// Admin: make a new join code. The old code and link stop working.
  Future<({String joinCode, String inviteLink})> regenerateCode(
    String classId,
  ) async {
    final data = await _client.post('/classes/$classId/regenerate-code', {});
    return (
      joinCode: data['joinCode'] as String,
      inviteLink: data['inviteLink'] as String,
    );
  }

  /// Owner only: closes the class for everyone.
  Future<void> archive(String classId) async {
    await _client.post('/classes/$classId/archive', {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MEMBERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Admins also see people who are waiting for approval.
  Future<List<ClassMember>> members(String classId) async {
    final data = await _client.get('/classes/$classId/members');
    return _parseList(data['members'], ClassMember.fromMap);
  }

  /// Admin actions: 'approve' | 'promote' | 'demote' | 'mute' | 'unmute'
  Future<void> memberAction(
    String classId,
    String userId,
    String action,
  ) async {
    await _client.put('/classes/$classId/members/$userId', {'action': action});
  }

  /// Leave the class (pass your own id), cancel a join request, or, for
  /// admins, remove someone else.
  Future<void> removeMember(String classId, String userId) async {
    await _client.delete('/classes/$classId/members/$userId');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHAT HISTORY, PINS, REPORTS
  // ══════════════════════════════════════════════════════════════════════════

  /// One page of history, oldest first. To load older messages, pass the id
  /// of the oldest message you already have as [before].
  Future<MessagePage> messages(
    String classId, {
    String? before,
    int limit = 30,
  }) async {
    final query = 'limit=$limit${before != null ? '&before=$before' : ''}';
    final data = await _client.get('/classes/$classId/messages?$query');
    return MessagePage(
      messages: _parseList(data['messages'], ChatMessage.fromMap),
      hasMore: data['hasMore'] == true,
    );
  }

  /// Admin: pin or unpin a message.
  Future<void> pinMessage(
    String classId,
    String messageId, {
    required bool pinned,
  }) async {
    await _client.put('/classes/$classId/messages/$messageId/pin', {
      'pinned': pinned,
    });
  }

  Future<void> reportMessage(String classId, String messageId) async {
    await _client.post('/classes/$classId/messages/$messageId/report', {});
  }

  /// Admin: messages that members have reported.
  Future<List<ChatMessage>> reportedMessages(String classId) async {
    final data = await _client.get('/classes/$classId/reports');
    return _parseList(data['reports'], ChatMessage.fromMap);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ANONYMOUS SESSIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Admin: start an anonymous session (only one can be open at a time).
  Future<AnonSession> openAnonSession(
    String classId, {
    String prompt = '',
  }) async {
    final data = await _client.post('/classes/$classId/anon', {
      'prompt': prompt,
    });
    return AnonSession.fromMap(data['session'] as Map<String, dynamic>);
  }

  Future<AnonSession> closeAnonSession(String classId, String sessionId) async {
    final data = await _client.post(
      '/classes/$classId/anon/$sessionId/close',
      {},
    );
    return AnonSession.fromMap(data['session'] as Map<String, dynamic>);
  }

  /// Recent sessions, newest first.
  Future<List<AnonSession>> anonSessions(String classId) async {
    final data = await _client.get('/classes/$classId/anon');
    return _parseList(data['sessions'], AnonSession.fromMap);
  }

  /// Posts in a session, newest first. To load older posts, pass the id of
  /// the oldest post you already have as [before].
  Future<AnonPostPage> anonPosts(
    String classId,
    String sessionId, {
    String? before,
    int limit = 50,
  }) async {
    final query = 'limit=$limit${before != null ? '&before=$before' : ''}';
    final data = await _client.get(
      '/classes/$classId/anon/$sessionId/posts?$query',
    );
    return AnonPostPage(
      session: AnonSession.fromMap(data['session'] as Map<String, dynamic>),
      posts: _parseList(data['posts'], AnonPost.fromMap),
      hasMore: data['hasMore'] == true,
    );
  }

  /// Admin: hide a post. With [block] the sender can't post again in this
  /// session, and the admin never learns who they are.
  Future<void> hideAnonPost(
    String classId,
    String sessionId,
    String postId, {
    bool block = false,
  }) async {
    await _client.delete(
      '/classes/$classId/anon/$sessionId/posts/$postId'
      '${block ? '?block=true' : ''}',
    );
  }
}
