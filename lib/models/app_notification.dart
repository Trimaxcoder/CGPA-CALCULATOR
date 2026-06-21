// lib/models/app_notification.dart
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // e.g. 'lecture', 'exam', 'general', 'admin'
  final DateTime receivedAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'],
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        type: m['type'] ?? 'general',
        receivedAt: DateTime.tryParse(m['receivedAt'] ?? '') ?? DateTime.now(),
        isRead: m['isRead'] ?? false,
      );
}