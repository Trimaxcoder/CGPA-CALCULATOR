



class StudentProfile {
  String name, matricNumber, department, faculty, email, school;
  StudentProfile({
    this.name = '',
    this.matricNumber = '',
    this.department = '',
    this.faculty = '',
    this.email = '',
    this.school = '',
  });
  bool get isEmpty => name.isEmpty;
  Map<String, dynamic> toMap() => {
    'name': name,
    'matricNumber': matricNumber,
    'department': department,
    'faculty': faculty,
    'email': email,
    'school': school,
  };
  factory StudentProfile.fromMap(Map<String, dynamic> m) => StudentProfile(
    name: m['name'] ?? '',
    matricNumber: m['matricNumber'] ?? '',
    department: m['department'] ?? '',
    faculty: m['faculty'] ?? '',
    email: m['email'] ?? '',
    school: m['school'] ?? '',
  );
}