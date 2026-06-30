// lib/models/announcement.dart

class Announcement {
  final String id;
  final String adminName;
  final String school;
  final String faculty;
  final String department;
  final String level; // "all" | "100" | "200" …
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? editedAt;

  const Announcement({
    required this.id,
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
        adminName:  m['adminName'] as String? ?? 'Admin',
        school:     m['school']     as String? ?? '',
        faculty:    m['faculty']    as String? ?? '',
        department: m['department'] as String? ?? '',
        level:      m['level']      as String? ?? 'all',
        title:      m['title']      as String? ?? '',
        message:    m['message']    as String? ?? '',
        createdAt:  DateTime.parse(m['createdAt'] as String),
        editedAt:   m['editedAt'] != null
            ? DateTime.parse(m['editedAt'] as String)
            : null,
      );

  String get levelLabel => level == 'all' ? 'All levels' : 'Level $level';
  bool get wasEdited => editedAt != null;

  Announcement copyWith({String? title, String? message, DateTime? editedAt}) =>
      Announcement(
        id: id,
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