// lib/models/class_models.dart
//
// Data classes for the "Join a class" feature. Every fromMap matches the JSON
// that the backend (routes/classes.js and socket/index.js) sends.

import 'dart:typed_data';

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
//  LAST MESSAGE (shown on the class list)
// ─────────────────────────────────────────────────────────────────────────────

class LastMessage {
  final String id;
  final String text; // already shortened by the server: "Photo", "Voice note"...
  final String senderId;
  final String senderName;
  final DateTime createdAt;
  final bool deleted;

  const LastMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.deleted,
  });

  factory LastMessage.fromMap(Map<String, dynamic> m) => LastMessage(
        id: (m['id'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        senderId: (m['senderId'] ?? '') as String,
        senderName: (m['senderName'] ?? 'Student') as String,
        createdAt: _parseDate(m['createdAt']),
        deleted: m['deleted'] == true,
      );
}

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

  /// Newest message, and how many messages from others I have not read.
  /// Only filled in by the class list, not by the other class calls.
  final LastMessage? lastMessage;
  final int unread;

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
    this.lastMessage,
    this.unread = 0,
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
        lastMessage: m['lastMessage'] is Map
            ? LastMessage.fromMap(_asMap(m['lastMessage']))
            : null,
        unread: (m['unread'] as num?)?.toInt() ?? 0,
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
    LastMessage? lastMessage,
    int? unread,
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
        lastMessage: lastMessage ?? this.lastMessage,
        unread: unread ?? this.unread,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MEMBER
// ─────────────────────────────────────────────────────────────────────────────

class ClassMember {
  final String userId;
  final String name;

  /// The @name other students type to tag this person ('' = none set)
  final String username;
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
    this.username = '',
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
        username: (m['username'] ?? '') as String,
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

/// A person tagged with @username in a message.
class Mention {
  final String userId;
  final String username;

  const Mention({required this.userId, required this.username});

  static List<Mention> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Mention>[];
    for (final e in raw) {
      if (e is Map && e['username'] != null) {
        out.add(Mention(
          userId: '${e['id'] ?? ''}',
          username: '${e['username']}',
        ));
      }
    }
    return out;
  }
}

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

/// A photo, document or voice note attached to a chat message.
class ChatAttachment {
  final String kind; // 'image' | 'file' | 'audio'
  final String url; // empty while it is still uploading
  final String name;
  final int size; // bytes
  final String mime;
  final int duration; // seconds, voice notes only

  /// Only on the sender's own device, while the file is uploading, so the
  /// photo can show instantly. Never sent to or received from the server.
  final Uint8List? localBytes;

  const ChatAttachment({
    required this.kind,
    required this.url,
    required this.name,
    required this.size,
    required this.mime,
    this.duration = 0,
    this.localBytes,
  });

  bool get isUploaded => url.isNotEmpty;
  bool get isImage => kind == 'image';
  bool get isAudio => kind == 'audio';
  bool get isFile => kind == 'file';

  factory ChatAttachment.fromMap(Map<String, dynamic> m) => ChatAttachment(
        kind: (m['kind'] ?? 'file') as String,
        url: (m['url'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        size: (m['size'] as num?)?.toInt() ?? 0,
        mime: (m['mime'] ?? '') as String,
        duration: (m['duration'] as num?)?.toInt() ?? 0,
      );

  /// What the socket sends to the server.
  Map<String, dynamic> toSendMap() => {
        'kind': kind,
        'url': url,
        'name': name,
        'size': size,
        'mime': mime,
        'duration': duration,
      };

  ChatAttachment copyWith({String? url, int? size, int? duration}) =>
      ChatAttachment(
        kind: kind,
        url: url ?? this.url,
        name: name,
        size: size ?? this.size,
        mime: mime,
        duration: duration ?? this.duration,
        localBytes: localBytes,
      );

  /// "Photo", "Voice note" or the file name.
  String get label {
    if (isImage) return 'Photo';
    if (isAudio) return 'Voice note';
    return name.isEmpty ? 'File' : name;
  }

  /// "340 KB", "2.1 MB"
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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
  final ChatAttachment? attachment;

  /// emoji -> ids of the people who reacted with it
  final Map<String, List<String>> reactions;

  /// When the text was last edited (null = never edited)
  final DateTime? editedAt;

  /// true when this message was forwarded from another chat
  final bool forwarded;

  /// People tagged with @username in the text
  final List<Mention> mentions;

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
    this.attachment,
    this.reactions = const {},
    this.editedAt,
    this.forwarded = false,
    this.mentions = const [],
  });

  /// true when this message tags me
  bool mentionsUser(String userId) =>
      userId.isNotEmpty && mentions.any((x) => x.userId == userId);

  /// The emoji I reacted with on this message, or '' if none.
  String myReaction(String myId) {
    if (myId.isEmpty) return '';
    for (final e in reactions.entries) {
      if (e.value.contains(myId)) return e.key;
    }
    return '';
  }

  /// Text for reply bars and pinned bars: the message text, or a short
  /// description when the message is only a photo, file or voice note.
  String get previewText {
    if (text.isNotEmpty) return text;
    return attachment?.label ?? '';
  }

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    final sender = _asMap(m['sender']);
    final reply = m['replyTo'];
    final att = m['attachment'];
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
      attachment: att is Map ? ChatAttachment.fromMap(_asMap(att)) : null,
      reactions: parseReactions(m['reactions']),
      editedAt: _parseDateOrNull(m['editedAt']),
      forwarded: m['forwarded'] == true,
      mentions: Mention.parseList(m['mentions']),
    );
  }

  /// {"👍": ["id", ...]}  (as sent by the server)  ->  a typed map.
  static Map<String, List<String>> parseReactions(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    raw.forEach((k, v) {
      if (v is List && v.isNotEmpty) {
        out['$k'] = v.map((e) => e.toString()).toList();
      }
    });
    return out;
  }

  ChatMessage copyWith({
    String? id,
    bool? deleted,
    bool? pinned,
    String? text,
    SendState? sendState,
    ChatAttachment? attachment,
    bool clearAttachment = false,
    Map<String, List<String>>? reactions,
    DateTime? editedAt,
    List<Mention>? mentions,
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
        attachment: clearAttachment ? null : (attachment ?? this.attachment),
        reactions: reactions ?? this.reactions,
        editedAt: editedAt ?? this.editedAt,
        forwarded: forwarded,
        mentions: mentions ?? this.mentions,
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
//  CLASS INFO (the screen opened by tapping the class name)
// ─────────────────────────────────────────────────────────────────────────────

class ClassAdmin {
  final String userId;
  final String name;
  final bool isOwner;

  const ClassAdmin({
    required this.userId,
    required this.name,
    required this.isOwner,
  });

  factory ClassAdmin.fromMap(Map<String, dynamic> m) => ClassAdmin(
        userId: (m['userId'] ?? '') as String,
        name: (m['name'] ?? 'Student') as String,
        isOwner: m['isOwner'] == true,
      );
}

class SharedImage {
  final String id;
  final String url;

  const SharedImage({required this.id, required this.url});

  factory SharedImage.fromMap(Map<String, dynamic> m) => SharedImage(
        id: (m['id'] ?? '') as String,
        url: (m['url'] ?? '') as String,
      );
}

class SharedFile {
  final String id;
  final String name;
  final String url;
  final int size;
  final String mime;

  const SharedFile({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.mime,
  });

  factory SharedFile.fromMap(Map<String, dynamic> m) => SharedFile(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        url: (m['url'] ?? '') as String,
        size: (m['size'] as num?)?.toInt() ?? 0,
        mime: (m['mime'] ?? '') as String,
      );

  String get label => name.isEmpty ? 'File' : name;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ClassInfo {
  final DateTime createdAt;
  final String createdByName;
  final List<ClassAdmin> admins;
  final DateTime myJoinedAt;
  final int pinnedCount;
  final int disappearAfter; // my "disappearing messages" time, seconds (0 = off)
  final int imageCount;
  final int fileCount;
  final int audioCount;
  final List<SharedImage> recentImages;
  final List<SharedFile> recentFiles;

  const ClassInfo({
    required this.createdAt,
    required this.createdByName,
    required this.admins,
    required this.myJoinedAt,
    required this.pinnedCount,
    required this.disappearAfter,
    required this.imageCount,
    required this.fileCount,
    required this.audioCount,
    required this.recentImages,
    required this.recentFiles,
  });

  int get mediaTotal => imageCount + fileCount + audioCount;

  factory ClassInfo.fromMap(Map<String, dynamic> m) {
    final media = _asMap(m['media']);
    return ClassInfo(
      createdAt: _parseDate(m['createdAt']),
      createdByName: (_asMap(m['createdBy'])['name'] ?? 'Unknown') as String,
      admins: ((m['admins'] as List?) ?? const [])
          .map((e) => ClassAdmin.fromMap(_asMap(e)))
          .toList(),
      myJoinedAt: _parseDate(m['myJoinedAt']),
      pinnedCount: (m['pinnedCount'] as num?)?.toInt() ?? 0,
      disappearAfter: (m['disappearAfter'] as num?)?.toInt() ?? 0,
      imageCount: (media['images'] as num?)?.toInt() ?? 0,
      fileCount: (media['files'] as num?)?.toInt() ?? 0,
      audioCount: (media['audio'] as num?)?.toInt() ?? 0,
      recentImages: ((media['recentImages'] as List?) ?? const [])
          .map((e) => SharedImage.fromMap(_asMap(e)))
          .toList(),
      recentFiles: ((media['recentFiles'] as List?) ?? const [])
          .map((e) => SharedFile.fromMap(_asMap(e)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESPONSE WRAPPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Result of GET /classes/:id
class ClassDetails {
  final ClassRoom room;
  final AnonSession? activeSession;
  final List<ChatMessage> pinned;

  /// Newest message any classmate's app has received / has seen. Used for the
  /// tick marks on my own messages. Null when nobody has yet.
  final String? deliveredUpTo;
  final String? readUpTo;

  /// My own chat settings for this class: how long until messages disappear
  /// for me (seconds, 0 = never), and when I last cleared the chat.
  final int disappearAfter;
  final DateTime? clearedAt;

  const ClassDetails({
    required this.room,
    required this.activeSession,
    required this.pinned,
    this.deliveredUpTo,
    this.readUpTo,
    this.disappearAfter = 0,
    this.clearedAt,
  });

  factory ClassDetails.fromMap(Map<String, dynamic> m) => ClassDetails(
        room: ClassRoom.fromMap(_asMap(m['class'])),
        activeSession: m['activeAnonSession'] == null
            ? null
            : AnonSession.fromMap(_asMap(m['activeAnonSession'])),
        pinned: ((m['pinned'] as List?) ?? const [])
            .map((e) => ChatMessage.fromMap(_asMap(e)))
            .toList(),
        deliveredUpTo: _asMap(m['receipts'])['delivered'] as String?,
        readUpTo: _asMap(m['receipts'])['read'] as String?,
        disappearAfter:
            (_asMap(m['my'])['disappearAfter'] as num?)?.toInt() ?? 0,
        clearedAt: _parseDateOrNull(_asMap(m['my'])['clearedAt']),
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