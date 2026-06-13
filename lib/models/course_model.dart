


class Course {
  String id;
  String? serverId;
  String name;
  String title;
  int score;
  int unit;
  int year;
  int semester;

  Course(this.name, this.title, this.score, this.unit, this.year, this.semester)
    : id =
          '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode}_${_idCounter++}';

  static int _idCounter = 0;

  Course.withId(
    this.id,
    this.name,
    this.title,
    this.score,
    this.unit,
    this.year,
    this.semester,
  );

  factory Course.fromServerMap(Map<String, dynamic> m) => Course.withId(
    m['clientId'] as String? ?? '',
    m['name'] as String? ?? '',
    m['title'] as String? ?? '',
    (m['score'] as num).toInt(),
    (m['unit'] as num).toInt(),
    (m['year'] as num).toInt(),
    (m['semester'] as num).toInt(),
  )..serverId = m['_id'] as String?;

  Map<String, dynamic> toMap() => {
    'id': id,
    'serverId': serverId,
    'name': name,
    'title': title,
    'score': score,
    'unit': unit,
    'year': year,
    'semester': semester,
  };

  factory Course.fromMap(Map<String, dynamic> m) {
    final c = Course.withId(
      m['id'] ??
          '${DateTime.now().microsecondsSinceEpoch}_${(m['name'] ?? '').hashCode}',
      m['name'] ?? '',
      m['title'] ?? '',
      m['score'] ?? 0,
      m['unit'] ?? 1,
      m['year'] ?? 1,
      m['semester'] ?? 1,
    );
    c.serverId = m['serverId'] as String?;
    return c;
  }
}