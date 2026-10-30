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

  // ══════════════════════════════════════════════════════════════════════════
  //  USERNAME (the name shown in classes)
  // ══════════════════════════════════════════════════════════════════════════

  /// The username I set for classes, or '' when I use my full name.
  Future<String> myUsername() async {
    final data = await _client.get('/auth/username');
    return (data['username'] ?? '') as String;
  }

  /// Save a username. An empty string removes it, so classes show the full
  /// name again. Throws with a readable message if it is taken or invalid.
  Future<String> setUsername(String username) async {
    final data = await _client.post('/auth/username', {'username': username});
    return (data['username'] ?? '') as String;
  }

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

  /// Everything the class info screen shows: created date, who created it,
  /// admins, and shared photos, files and voice notes.
  Future<ClassInfo> info(String classId) async {
    final data = await _client.get('/classes/$classId/info');
    return ClassInfo.fromMap(data['info'] as Map<String, dynamic>);
  }

  /// Clear the chat for me only. Other members keep their messages.
  Future<DateTime> clearChat(String classId) async {
    final data = await _client.post('/classes/$classId/clear', {});
    return DateTime.tryParse('${data['clearedAt']}')?.toLocal() ??
        DateTime.now();
  }

  /// My own "disappearing messages" time for this class, in seconds:
  /// 0 (off), 86400 (24 hours), 604800 (7 days) or 7776000 (90 days).
  Future<int> setDisappearing(String classId, int seconds) async {
    final data = await _client.put('/classes/$classId/disappearing', {
      'seconds': seconds,
    });
    return (data['disappearAfter'] as num?)?.toInt() ?? seconds;
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
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (requireApproval != null) 'requireApproval': requireApproval,
      if (chatLocked != null) 'chatLocked': chatLocked,
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

  /// Search this class's messages (and file names). Newest first. Pass the
  /// id of the last result as [before] to get the next page.
  Future<MessagePage> searchMessages(
    String classId,
    String query, {
    String? before,
    int limit = 30,
  }) async {
    final params = [
      'q=${Uri.encodeQueryComponent(query)}',
      'limit=$limit',
      if (before != null) 'before=$before',
    ].join('&');
    final data = await _client.get('/classes/$classId/search?$params');
    return MessagePage(
      messages: _parseList(data['messages'], ChatMessage.fromMap),
      hasMore: data['hasMore'] == true,
    );
  }

  /// One message with the messages just before and after it, oldest first.
  Future<List<ChatMessage>> messageContext(
    String classId,
    String messageId,
  ) async {
    final data =
        await _client.get('/classes/$classId/messages/$messageId/context');
    return _parseList(data['messages'], ChatMessage.fromMap);
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

  Future<AnonSession> closeAnonSession(
    String classId,
    String sessionId,
  ) async {
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