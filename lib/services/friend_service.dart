// lib/services/friend_service.dart
//
// Friends: finding people, friend requests, blocking, and opening a private
// chat. Built on your existing ApiClient like ClassService.

import '../models/class_models.dart';
import 'api_service.dart';

/// One student as another student sees them.
class Person {
  final String id;
  final String name; // the username if they set one, else their name
  final String username;
  final String department;
  final String level;

  /// 'none' | 'friends' | 'sent' | 'received' | 'blocked' | 'self'
  final String relation;

  /// The private chat with this person (only when you are friends)
  final String? classId;

  const Person({
    required this.id,
    required this.name,
    required this.username,
    required this.department,
    required this.level,
    required this.relation,
    this.classId,
  });

  bool get isFriend => relation == 'friends';
  bool get isSelf => relation == 'self';

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// "Computer Science · 300 level" (whatever is filled in)
  String get detail => [
        if (department.isNotEmpty) department,
        if (level.isNotEmpty) level,
      ].join(' · ');

  factory Person.fromMap(Map<String, dynamic> m) => Person(
        id: m['id'] as String,
        name: (m['name'] ?? 'Student') as String,
        username: (m['username'] ?? '') as String,
        department: (m['department'] ?? '') as String,
        level: (m['level'] ?? '') as String,
        relation: (m['relation'] ?? 'none') as String,
        classId: m['classId'] as String?,
      );

  Person withRelation(String relation, {String? classId}) => Person(
        id: id,
        name: name,
        username: username,
        department: department,
        level: level,
        relation: relation,
        classId: classId ?? this.classId,
      );
}

class FriendsData {
  final List<Person> friends;
  final List<Person> incoming; // asked me
  final List<Person> outgoing; // I asked
  final List<Person> blocked;

  const FriendsData({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.blocked = const [],
  });
}

List<Person> _people(dynamic raw) {
  if (raw is! List) return <Person>[];
  return raw.map((e) => Person.fromMap(e as Map<String, dynamic>)).toList();
}

class FriendService {
  final _client = ApiClient();

  Future<FriendsData> load() async {
    final data = await _client.get('/friends');
    return FriendsData(
      friends: _people(data['friends']),
      incoming: _people(data['incoming']),
      outgoing: _people(data['outgoing']),
      blocked: _people(data['blocked']),
    );
  }

  /// By name or username. At least 2 characters.
  Future<List<Person>> search(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final data = await _client.get('/friends/search?q=$q');
    return _people(data['people']);
  }

  Future<Person> person(String userId) async {
    final data = await _client.get('/friends/person/$userId');
    return Person.fromMap(data['person'] as Map<String, dynamic>);
  }

  /// Returns the new relation: 'sent', or 'friends' if they had already
  /// asked you.
  Future<String> sendRequest(String userId) async {
    final data = await _client.post('/friends/request', {'userId': userId});
    return (data['relation'] ?? 'sent') as String;
  }

  Future<void> accept(String userId) async {
    await _client.put('/friends/request/$userId', {'action': 'accept'});
  }

  Future<void> decline(String userId) async {
    await _client.put('/friends/request/$userId', {'action': 'decline'});
  }

  Future<void> cancelRequest(String userId) async {
    await _client.delete('/friends/request/$userId');
  }

  Future<void> unfriend(String userId) async {
    await _client.delete('/friends/$userId');
  }

  Future<void> block(String userId) async {
    await _client.post('/friends/block', {'userId': userId});
  }

  Future<void> unblock(String userId) async {
    await _client.delete('/friends/block/$userId');
  }

  /// The private chat with a friend, ready to open in ClassScreen.
  Future<ClassRoom> openChat(String userId) async {
    final data = await _client.post('/friends/$userId/chat', {});
    return ClassRoom.fromMap(data['class'] as Map<String, dynamic>);
  }

  Future<bool> getFindable() async {
    final data = await _client.get('/friends/settings');
    return data['findable'] != false;
  }

  Future<void> setFindable(bool value) async {
    await _client.put('/friends/settings', {'findable': value});
  }
}