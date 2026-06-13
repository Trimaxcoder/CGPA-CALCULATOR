// grading_model.dart
// User-configurable grading system.
// Each school can define its own score boundaries and grade points.

import 'dart:convert';

class GradeRule {
  final String grade;   // "A", "B", "C", "D", "E", "F"
  int minScore;         // inclusive lower bound
  double gradePoint;    // e.g. 5.0, 4.0, ...

  GradeRule({
    required this.grade,
    required this.minScore,
    required this.gradePoint,
  });

  Map<String, dynamic> toMap() => {
        'grade': grade,
        'minScore': minScore,
        'gradePoint': gradePoint,
      };

  factory GradeRule.fromMap(Map<String, dynamic> m) => GradeRule(
        grade: m['grade'] ?? '',
        minScore: m['minScore'] ?? 0,
        gradePoint: (m['gradePoint'] as num?)?.toDouble() ?? 0.0,
      );

  GradeRule copyWith({String? grade, int? minScore, double? gradePoint}) =>
      GradeRule(
        grade: grade ?? this.grade,
        minScore: minScore ?? this.minScore,
        gradePoint: gradePoint ?? this.gradePoint,
      );
}

class GradingModel {
  // Ordered highest → lowest (A first, F last)
  List<GradeRule> rules;

  GradingModel({required this.rules});

  /// Nigerian 5.0-scale default (70=A, 60=B, 50=C, 45=D, 40=E)
  factory GradingModel.defaultNigerian5() => GradingModel(rules: [
        GradeRule(grade: 'A', minScore: 70, gradePoint: 5.0),
        GradeRule(grade: 'B', minScore: 60, gradePoint: 4.0),
        GradeRule(grade: 'C', minScore: 50, gradePoint: 3.0),
        GradeRule(grade: 'D', minScore: 45, gradePoint: 2.0),
        GradeRule(grade: 'E', minScore: 40, gradePoint: 1.0),
        GradeRule(grade: 'F', minScore: 0,  gradePoint: 0.0),
      ]);

  /// Alternative 4.0-scale default (75=A, 65=B, 55=C, 50=D, 45=E)
  factory GradingModel.defaultNigerian4() => GradingModel(rules: [
        GradeRule(grade: 'A', minScore: 75, gradePoint: 4.0),
        GradeRule(grade: 'B', minScore: 65, gradePoint: 3.0),
        GradeRule(grade: 'C', minScore: 55, gradePoint: 2.0),
        GradeRule(grade: 'D', minScore: 50, gradePoint: 1.0),
        GradeRule(grade: 'E', minScore: 45, gradePoint: 0.5),
        GradeRule(grade: 'F', minScore: 0,  gradePoint: 0.0),
      ]);

  double get maxGradePoint =>
      rules.map((r) => r.gradePoint).fold(0.0, (a, b) => a > b ? a : b);

  /// Evaluate grade letter for a score
  String getGrade(int score) {
    for (final rule in rules) {
      if (score >= rule.minScore) return rule.grade;
    }
    return 'F';
  }

  /// Evaluate grade point for a score
  double getPoint(int score) {
    for (final rule in rules) {
      if (score >= rule.minScore) return rule.gradePoint;
    }
    return 0.0;
  }

  Map<String, dynamic> toMap() =>
      {'rules': rules.map((r) => r.toMap()).toList()};

  factory GradingModel.fromMap(Map<String, dynamic> m) {
    final rawRules = m['rules'] as List<dynamic>? ?? [];
    return GradingModel(
      rules: rawRules
          .map((r) => GradeRule.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GradingModel.fromJson(String json) =>
      GradingModel.fromMap(jsonDecode(json) as Map<String, dynamic>);

  GradingModel copyWith({List<GradeRule>? rules}) =>
      GradingModel(rules: rules ?? this.rules);
}
