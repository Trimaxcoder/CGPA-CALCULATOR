// lib/models/class_models.dart
//
// Data classes for the "Join a class" feature. Every fromMap matches the JSON
// that the backend (routes/classes.js and socket/index.js) sends.

DateTime _parseDate(dynamic v) {
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d.toLocal();
  }
  return DateTime.now();
}

DateTime? _parseDateOrNull(dynamic v) {
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  return null;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

// ─────────────────────────────────────────────────────────────────────────────
//  CLASS
// ─────────────────────────────────────────────────────────────────────────────

class ClassRoom {
  final String id;
  final String name;
  final String description;
  final bool requireApproval;
  final bool chatLocked; // true = only admins can post
  final bool archived;
  final int memberCount;
  final String? myRole; // 'admin' | 'member'
  final String? myStatus; // 'active' | 'pending'
  final bool isOwner;
  final String? joinCode; // only present for active members
  final String? inviteLink; // only present for active members
  final DateTime createdAt;

  const ClassRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.requireApproval,
    required this.chatLocked,
    required this.archived,
    required this.memberCount,
    required this.myRole,
    required this.myStatus,
    required this.isOwner,
    required this.joinCode,
    required this.inviteLink,
    required this.createdAt,
  });

  bool get isAdmin => myRole == 'admin' && myStatus == 'active';
  bool get isPending => myStatus == 'pending';
  bool get isActive => myStatus == 'active';

  factory ClassRoom.fromMap(Map<String, dynamic> m) => ClassRoom(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        requireApproval: m['requireApproval'] == true,
        chatLocked: m['chatLocked'] == true,
        archived: m['archived'] == true,
        memberCount: (m['memberCount'] as num?)?.toInt() ?? 0,
        myRole: m['myRole'] as String?,
        myStatus: m['myStatus'] as String?,
        isOwner: m['isOwner'] == true,
        joinCode: m['joinCode'] as String?,
        inviteLink: m['inviteLink'] as String?,
        createdAt: _parseDate(m['createdAt']),
      );

  ClassRoom copyWith({
    String? name,
    String? description,
    bool? requireApproval,
    bool? chatLocked,
    bool? archived,
    int? memberCount,
    String? myStatus,
    String? joinCode,
    String? inviteLink,
  }) =>
      ClassRoom(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        requireApproval: requireApproval ?? this.requireApproval,
        chatLocked: chatLocked ?? this.chatLocked,
        archived: archived ?? this.archived,
        memberCount: memberCount ?? this.memberCount,
        myRole: myRole,
        myStatus: myStatus ?? this.myStatus,
        isOwner: isOwner,
        joinCode: joinCode ?? this.joinCode,
        inviteLink: inviteLink ?? this.inviteLink,
        createdAt: createdAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MEMBER
// ─────────────────────────────────────────────────────────────────────────────

class ClassMember {
  final String userId;
  final String name;
  final String department;
  final String level;
  final String role; // 'admin' | 'member'
  final String status; // 'active' | 'pending'
  final bool muted;
  final bool isOwner;
  final DateTime joinedAt;

  const ClassMember({
    required this.userId,
    required this.name,
    required this.department,
    required this.level,
    required this.role,
    required this.status,
    required this.muted,
    required this.isOwner,
    required this.joinedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isPending => status == 'pending';

  factory ClassMember.fromMap(Map<String, dynamic> m) => ClassMember(
        userId: m['userId'] as String,
        name: (m['name'] ?? 'Student') as String,
        department: (m['department'] ?? '') as String,
        level: (m['level'] ?? '') as String,
        role: (m['role'] ?? 'member') as String,
        status: (m['status'] ?? 'active') as String,
        muted: m['muted'] == true,
        isOwner: m['isOwner'] == true,
        joinedAt: _parseDate(m['joinedAt']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHAT MESSAGE
// ─────────────────────────────────────────────────────────────────────────────

/// Local-only status used for instant ("optimistic") sending in the chat UI.
enum SendState { sent, sending, failed }

class ReplyPreview {
  final String id;
  final String text;
  final bool deleted;
  final String senderName;

  const ReplyPreview({
    required this.id,
    required this.text,
    required this.deleted,
    required this.senderName,
  });

  factory ReplyPreview.fromMap(Map<String, dynamic> m) => ReplyPreview(
        id: (m['id'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        deleted: m['deleted'] == true,
        senderName: (m['senderName'] ?? 'Student') as String,
      );
}

class ChatMessage {
  /// Server id. For a message that is still sending, this holds the clientId
  /// until the server confirms it.
  final String id;
  final String? clientId;
  final String classId;
  final String senderId;
  final String senderName;
  final String text;
  final bool deleted;
  final bool pinned;
  final ReplyPreview? replyTo;
  final DateTime createdAt;
  final SendState sendState;

  const ChatMessage({
    required this.id,
    required this.clientId,
    required this.classId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.deleted,
    required this.pinned,
    required this.replyTo,
    required this.createdAt,
    this.sendState = SendState.sent,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    final sender = _asMap(m['sender']);
    final reply = m['replyTo'];
    return ChatMessage(
      id: m['id'] as String,
      clientId: m['clientId'] as String?,
      classId: (m['classId'] ?? '') as String,
      senderId: (sender['id'] ?? '') as String,
      senderName: (sender['name'] ?? 'Student') as String,
      text: (m['text'] ?? '') as String,
      deleted: m['deleted'] == true,
      pinned: m['pinned'] == true,
      replyTo: reply is Map ? ReplyPreview.fromMap(_asMap(reply)) : null,
      createdAt: _parseDate(m['createdAt']),
    );
  }

  ChatMessage copyWith({
    String? id,
    bool? deleted,
    bool? pinned,
    String? text,
    SendState? sendState,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        clientId: clientId,
        classId: classId,
        senderId: senderId,
        senderName: senderName,
        text: text ?? this.text,
        deleted: deleted ?? this.deleted,
        pinned: pinned ?? this.pinned,
        replyTo: replyTo,
        createdAt: createdAt,
        sendState: sendState ?? this.sendState,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ANONYMOUS SESSION + POSTS
// ─────────────────────────────────────────────────────────────────────────────

class AnonSession {
  final String id;
  final String classId;
  final String prompt;
  final String status; // 'open' | 'closed'
  final int postCount;
  final DateTime createdAt;
  final DateTime? closedAt;

  const AnonSession({
    required this.id,
    required this.classId,
    required this.prompt,
    required this.status,
    required this.postCount,
    required this.createdAt,
    required this.closedAt,
  });

  bool get isOpen => status == 'open';

  factory AnonSession.fromMap(Map<String, dynamic> m) => AnonSession(
        id: m['id'] as String,
        classId: (m['classId'] ?? '') as String,
        prompt: (m['prompt'] ?? '') as String,
        status: (m['status'] ?? 'open') as String,
        postCount: (m['postCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(m['createdAt']),
        closedAt: _parseDateOrNull(m['closedAt']),
      );

  AnonSession copyWith({String? status, int? postCount, DateTime? closedAt}) =>
      AnonSession(
        id: id,
        classId: classId,
        prompt: prompt,
        status: status ?? this.status,
        postCount: postCount ?? this.postCount,
        createdAt: createdAt,
        closedAt: closedAt ?? this.closedAt,
      );
}

/// An anonymous post. There is deliberately NO author field: the server never
/// sends one, and the app must never invent one.
class AnonPost {
  final String id;
  final String sessionId;
  final String classId;
  final String text;
  final DateTime createdAt; // rounded to the minute by the server

  const AnonPost({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.text,
    required this.createdAt,
  });

  factory AnonPost.fromMap(Map<String, dynamic> m) => AnonPost(
        id: m['id'] as String,
        sessionId: (m['sessionId'] ?? '') as String,
        classId: (m['classId'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        createdAt: _parseDate(m['createdAt']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESPONSE WRAPPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Result of GET /classes/:id
class ClassDetails {
  final ClassRoom room;
  final AnonSession? activeSession;
  final List<ChatMessage> pinned;

  const ClassDetails({
    required this.room,
    required this.activeSession,
    required this.pinned,
  });

  factory ClassDetails.fromMap(Map<String, dynamic> m) => ClassDetails(
        room: ClassRoom.fromMap(_asMap(m['class'])),
        activeSession: m['activeAnonSession'] == null
            ? null
            : AnonSession.fromMap(_asMap(m['activeAnonSession'])),
        pinned: ((m['pinned'] as List?) ?? const [])
            .map((e) => ChatMessage.fromMap(_asMap(e)))
            .toList(),
      );
}

/// One page of chat history, oldest message first.
class MessagePage {
  final List<ChatMessage> messages;
  final bool hasMore;

  const MessagePage({required this.messages, required this.hasMore});
}

/// One page of anonymous posts, newest first.
class AnonPostPage {
  final AnonSession session;
  final List<AnonPost> posts;
  final bool hasMore;

  const AnonPostPage({
    required this.session,
    required this.posts,
    required this.hasMore,
  });
}