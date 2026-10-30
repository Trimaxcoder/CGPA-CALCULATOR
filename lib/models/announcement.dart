// lib/models/announcement.dart

class Announcement {
  final String id;

  /// 'global' = posted by the super admin for everyone
  /// 'class'  = posted by a course rep for one class
  final String scope;

  final String adminName;
  final String school;
  final String faculty;
  final String department;

  /// "100" | "200" … (empty for global; legacy documents may hold "all")
  final String level;

  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? editedAt;

  const Announcement({
    required this.id,
    this.scope = 'class',
    required this.adminName,
    required this.school,
    required this.faculty,
    required this.department,
    required this.level,
    required this.title,
    required this.message,
    required this.createdAt,
    this.editedAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> m) => Announcement(
        id:         m['_id'] as String,
        scope:      m['scope'] as String? ?? 'class',
        adminName:  m['adminName'] as String? ?? 'Admin',
        school:     m['school']     as String? ?? '',
        faculty:    m['faculty']    as String? ?? '',
        department: m['department'] as String? ?? '',
        level:      m['level']      as String? ?? '',
        title:      m['title']      as String? ?? '',
        message:    m['message']    as String? ?? '',
        // The server sends UTC; convert so times show in the user's timezone.
        createdAt:  DateTime.parse(m['createdAt'] as String).toLocal(),
        editedAt:   m['editedAt'] != null
            ? DateTime.parse(m['editedAt'] as String).toLocal()
            : null,
      );

  bool get isGlobal => scope == 'global';
  bool get wasEdited => editedAt != null;

  String get levelLabel {
    if (isGlobal) return 'Everyone';
    if (level.isEmpty || level == 'all') return 'All levels'; // legacy
    return 'Level $level';
  }

  Announcement copyWith({String? title, String? message, DateTime? editedAt}) =>
      Announcement(
        id: id,
        scope: scope,
        adminName: adminName,
        school: school,
        faculty: faculty,
        department: department,
        level: level,
        title: title ?? this.title,
        message: message ?? this.message,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
      );
}