// lib/services/muted_courses_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class MutedCoursesStore {
  static final MutedCoursesStore _instance = MutedCoursesStore._internal();
  factory MutedCoursesStore() => _instance;
  MutedCoursesStore._internal();

  static const _key = 'muted_course_codes';
  Set<String> _muted = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = (prefs.getStringList(_key) ?? []).toSet();
  }

  bool isMuted(String courseCode) => _muted.contains(courseCode.trim().toUpperCase());

  Future<void> toggle(String courseCode) async {
    final code = courseCode.trim().toUpperCase();
    if (_muted.contains(code)) {
      _muted.remove(code);
    } else {
      _muted.add(code);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _muted.toList());
  }
}