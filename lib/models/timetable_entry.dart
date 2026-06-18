class LectureEntry {
  final String id;
  final String courseCode;
  final String courseTitle;
  final String day;
  final String startTime;
  final String endTime;
  final String venue;
  final String classType; // normal | impromptu | test | meeting | other
  final String note;
  final bool isImportant;
  final String school;
  final String faculty;
  final String department;
  final String level;
  final String type; // lecture | exam
  final DateTime? date; // for exams
  final bool isEmergency;
  final bool isTest;
  final bool isAttendance;
  final bool isCancelled;

  LectureEntry({
    required this.id,
    required this.courseCode,
    required this.courseTitle,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.venue = '',
    this.classType = 'normal',
    this.note = '',
    this.isImportant = false,
    this.school = '',
    this.faculty = '',
    this.department = '',
    this.level = '',
    this.type = 'lecture',
    this.date,
    this.isEmergency = false,
    this.isTest = false,
    this.isAttendance = false,
    this.isCancelled = false,
  });

  factory LectureEntry.fromMap(Map<String, dynamic> m) => LectureEntry(
        id:          m['_id'] ?? '',
        courseCode:  m['courseCode'] ?? '',
        courseTitle: m['courseTitle'] ?? '',
        day:         m['day'] ?? '',
        startTime:   m['startTime'] ?? '',
        endTime:     m['endTime'] ?? '',
        venue:       m['venue'] ?? '',
        classType:   m['classType'] ?? 'normal',
        note:        m['note'] ?? '',
        isImportant: m['isImportant'] ?? false,
        school:      m['school'] ?? '',
        faculty:     m['faculty'] ?? '',
        department:  m['department'] ?? '',
        level:       m['level'] ?? '',
        type:        m['type'] ?? 'lecture',
        date:        m['date'] != null ? DateTime.tryParse(m['date']) : null,
        isEmergency: m['isEmergency'] ?? false,
        isTest:       m['isTest'] ?? false,
        isAttendance: m['isAttendance'] ?? false,
        isCancelled:  m['isCancelled'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'courseCode':  courseCode,
        'courseTitle': courseTitle,
        'day':         day,
        'startTime':   startTime,
        'endTime':     endTime,
        'venue':       venue,
        'classType':   classType,
        'note':        note,
        'isImportant': isImportant,
        'school':      school,
        'faculty':     faculty,
        'department':  department,
        'level':       level,
        'type':        type,
        if (date != null) 'date': date!.toIso8601String(),
        'isEmergency': isEmergency,
        'isTest':       isTest,
        'isAttendance': isAttendance,
        'isCancelled':  isCancelled,
      };
}

class PersonalEntry {
  final String id;
  final String title;
  final String day;
  final String startTime;
  final String endTime;
  final String color;
  final bool isBookmarked;
  final int reminderMinutes;
  final String note;

  PersonalEntry({
    required this.id,
    required this.title,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.color = '#4F46E5',
    this.isBookmarked = false,
    this.reminderMinutes = 0,
    this.note = '',
  });

  factory PersonalEntry.fromMap(Map<String, dynamic> m) => PersonalEntry(
        id:              m['_id'] ?? '',
        title:           m['title'] ?? '',
        day:             m['day'] ?? '',
        startTime:       m['startTime'] ?? '',
        endTime:         m['endTime'] ?? '',
        color:           m['color'] ?? '#4F46E5',
        isBookmarked:    m['isBookmarked'] ?? false,
        reminderMinutes: m['reminderMinutes'] ?? 0,
        note:            m['note'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'title':           title,
        'day':             day,
        'startTime':       startTime,
        'endTime':         endTime,
        'color':           color,
        'isBookmarked':    isBookmarked,
        'reminderMinutes': reminderMinutes,
        'note':            note,
      };

  PersonalEntry copyWith({bool? isBookmarked}) => PersonalEntry(
        id:              id,
        title:           title,
        day:             day,
        startTime:       startTime,
        endTime:         endTime,
        color:           color,
        isBookmarked:    isBookmarked ?? this.isBookmarked,
        reminderMinutes: reminderMinutes,
        note:            note,
      );
}