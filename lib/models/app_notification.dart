// lib/models/app_notification.dart
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data; // NEW — carries courseCode, examId, etc.
  final DateTime receivedAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'],
        title: map['title'],
        body: map['body'],
        type: map['type'] ?? 'general',
        data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : {},
        receivedAt: DateTime.parse(map['receivedAt']),
        isRead: map['isRead'] ?? false,
      );
}