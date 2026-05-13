// uniport_courses.dart
// University of Port Harcourt — Course Data
// Faculty of Science: Mathematics & Statistics, Computer Science
// Expand other faculties/departments below following the same structure.

class CourseData {
  final String code;
  final String title;
  final int unit;

  const CourseData({
    required this.code,
    required this.title,
    required this.unit,
  });

  Map<String, dynamic> toMap() =>
      {'code': code, 'title': title, 'unit': unit};
}

class SemesterData {
  final String label; // "First Semester" | "Second Semester"
  final List<CourseData> courses;
  const SemesterData({required this.label, required this.courses});
}

class LevelData {
  final String level; // "100", "200", ...
  final List<SemesterData> semesters;
  const LevelData({required this.level, required this.semesters});
}

class DepartmentData {
  final String name;
  final List<LevelData> levels;
  const DepartmentData({required this.name, required this.levels});
}

class FacultyData {
  final String name;
  final List<DepartmentData> departments;
  const FacultyData({required this.name, required this.departments});
}

class UniversityData {
  final String name;
  final List<FacultyData> faculties;
  const UniversityData({required this.name, required this.faculties});
}

// ─────────────────────────────────────────────────────────
//  UNIVERSITY OF PORT HARCOURT DATA
// ─────────────────────────────────────────────────────────

const UniversityData uniportData = UniversityData(
  name: 'University of Port Harcourt',
  faculties: [
    FacultyData(
      name: 'Faculty of Science',
      departments: [
        // ══════════════════════════════════════════════════
        //  MATHEMATICS & STATISTICS
        // ══════════════════════════════════════════════════
        DepartmentData(
          name: 'Mathematics and Statistics',
          levels: [
            // ── 100 Level ──
            LevelData(level: '100', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'MTH 101', title: 'Elementary Mathematics I', unit: 3),
                CourseData(code: 'MTH 103', title: 'Elementary Mathematics III', unit: 2),
                CourseData(code: 'PHY 101', title: 'General Physics I', unit: 3),
                CourseData(code: 'PHY 107', title: 'Practical Physics I', unit: 1),
                CourseData(code: 'CHM 101', title: 'General Chemistry I', unit: 3),
                CourseData(code: 'CHM 107', title: 'Practical Chemistry I', unit: 1),
                CourseData(code: 'BIO 101', title: 'General Biology I', unit: 3),
                CourseData(code: 'CSC 101', title: 'Introduction to Computer Science', unit: 2),
                CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
                CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'MTH 102', title: 'Elementary Mathematics II', unit: 3),
                CourseData(code: 'MTH 104', title: 'Elementary Mathematics IV', unit: 2),
                CourseData(code: 'PHY 102', title: 'General Physics II', unit: 3),
                CourseData(code: 'PHY 108', title: 'Practical Physics II', unit: 1),
                CourseData(code: 'CHM 102', title: 'General Chemistry II', unit: 3),
                CourseData(code: 'CHM 108', title: 'Practical Chemistry II', unit: 1),
                CourseData(code: 'BIO 102', title: 'General Biology II', unit: 3),
                CourseData(code: 'STA 102', title: 'Introduction to Statistics', unit: 2),
                CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
                CourseData(code: 'GST 114', title: 'History and Philosophy of Science', unit: 2),
              ]),
            ]),
            // ── 200 Level ──
            LevelData(level: '200', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'MTH 201', title: 'Mathematical Methods I', unit: 3),
                CourseData(code: 'MTH 203', title: 'Linear Algebra I', unit: 3),
                CourseData(code: 'MTH 205', title: 'Real Analysis I', unit: 3),
                CourseData(code: 'MTH 207', title: 'Vector Analysis', unit: 3),
                CourseData(code: 'STA 201', title: 'Probability I', unit: 3),
                CourseData(code: 'CSC 201', title: 'Computer Programming I', unit: 3),
                CourseData(code: 'GST 211', title: 'Communication in English III', unit: 2),
                CourseData(code: 'GST 213', title: 'Philosophy and Logic', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'MTH 202', title: 'Mathematical Methods II', unit: 3),
                CourseData(code: 'MTH 204', title: 'Linear Algebra II', unit: 3),
                CourseData(code: 'MTH 206', title: 'Real Analysis II', unit: 3),
                CourseData(code: 'MTH 208', title: 'Ordinary Differential Equations', unit: 3),
                CourseData(code: 'STA 202', title: 'Probability II', unit: 3),
                CourseData(code: 'STA 204', title: 'Statistical Methods I', unit: 3),
                CourseData(code: 'CSC 202', title: 'Computer Programming II', unit: 3),
                CourseData(code: 'GST 212', title: 'Communication in English IV', unit: 2),
              ]),
            ]),
            // ── 300 Level ──
            LevelData(level: '300', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'MTH 301', title: 'Complex Analysis I', unit: 3),
                CourseData(code: 'MTH 303', title: 'Abstract Algebra I', unit: 3),
                CourseData(code: 'MTH 305', title: 'Numerical Analysis I', unit: 3),
                CourseData(code: 'MTH 307', title: 'Partial Differential Equations', unit: 3),
                CourseData(code: 'STA 301', title: 'Statistical Inference I', unit: 3),
                CourseData(code: 'STA 303', title: 'Regression Analysis', unit: 3),
                CourseData(code: 'STA 305', title: 'Design of Experiments I', unit: 3),
                CourseData(code: 'GST 311', title: 'Entrepreneurship I', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'MTH 302', title: 'Complex Analysis II', unit: 3),
                CourseData(code: 'MTH 304', title: 'Abstract Algebra II', unit: 3),
                CourseData(code: 'MTH 306', title: 'Numerical Analysis II', unit: 3),
                CourseData(code: 'MTH 308', title: 'Functional Analysis', unit: 3),
                CourseData(code: 'STA 302', title: 'Statistical Inference II', unit: 3),
                CourseData(code: 'STA 304', title: 'Time Series Analysis', unit: 3),
                CourseData(code: 'STA 306', title: 'Design of Experiments II', unit: 3),
                CourseData(code: 'GST 312', title: 'Entrepreneurship II', unit: 2),
              ]),
            ]),
            // ── 400 Level ──
            LevelData(level: '400', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'MTH 401', title: 'Measure Theory', unit: 3),
                CourseData(code: 'MTH 403', title: 'Topology', unit: 3),
                CourseData(code: 'MTH 405', title: 'Operations Research I', unit: 3),
                CourseData(code: 'MTH 407', title: 'Mathematical Modelling', unit: 3),
                CourseData(code: 'STA 401', title: 'Multivariate Analysis', unit: 3),
                CourseData(code: 'STA 403', title: 'Stochastic Processes', unit: 3),
                CourseData(code: 'STA 405', title: 'Sampling Theory', unit: 3),
                CourseData(code: 'MTH 499', title: 'Research Project I', unit: 3),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'MTH 402', title: 'Differential Geometry', unit: 3),
                CourseData(code: 'MTH 404', title: 'Graph Theory', unit: 3),
                CourseData(code: 'MTH 406', title: 'Operations Research II', unit: 3),
                CourseData(code: 'STA 402', title: 'Biostatistics', unit: 3),
                CourseData(code: 'STA 404', title: 'Econometrics', unit: 3),
                CourseData(code: 'STA 406', title: 'Non-Parametric Methods', unit: 3),
                CourseData(code: 'MTH 400', title: 'Research Project II', unit: 6),
              ]),
            ]),
          ],
        ),

        // ══════════════════════════════════════════════════
        //  COMPUTER SCIENCE
        // ══════════════════════════════════════════════════
        DepartmentData(
          name: 'Computer Science',
          levels: [
            // ── 100 Level ──
            LevelData(level: '100', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CSC 101', title: 'Introduction to Computer Science', unit: 3),
                CourseData(code: 'MTH 101', title: 'Elementary Mathematics I', unit: 3),
                CourseData(code: 'MTH 103', title: 'Elementary Mathematics III', unit: 2),
                CourseData(code: 'PHY 101', title: 'General Physics I', unit: 3),
                CourseData(code: 'PHY 107', title: 'Practical Physics I', unit: 1),
                CourseData(code: 'CHM 101', title: 'General Chemistry I', unit: 3),
                CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
                CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CSC 102', title: 'Introduction to Programming', unit: 3),
                CourseData(code: 'MTH 102', title: 'Elementary Mathematics II', unit: 3),
                CourseData(code: 'MTH 104', title: 'Elementary Mathematics IV', unit: 2),
                CourseData(code: 'PHY 102', title: 'General Physics II', unit: 3),
                CourseData(code: 'PHY 108', title: 'Practical Physics II', unit: 1),
                CourseData(code: 'STA 102', title: 'Introduction to Statistics', unit: 2),
                CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
                CourseData(code: 'GST 114', title: 'History and Philosophy of Science', unit: 2),
              ]),
            ]),
            // ── 200 Level ──
            LevelData(level: '200', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CSC 201', title: 'Computer Programming I', unit: 3),
                CourseData(code: 'CSC 203', title: 'Discrete Mathematics', unit: 3),
                CourseData(code: 'CSC 205', title: 'Data Structures I', unit: 3),
                CourseData(code: 'MTH 201', title: 'Mathematical Methods I', unit: 3),
                CourseData(code: 'MTH 203', title: 'Linear Algebra I', unit: 3),
                CourseData(code: 'GST 211', title: 'Communication in English III', unit: 2),
                CourseData(code: 'GST 213', title: 'Philosophy and Logic', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CSC 202', title: 'Computer Programming II', unit: 3),
                CourseData(code: 'CSC 204', title: 'Computer Organisation', unit: 3),
                CourseData(code: 'CSC 206', title: 'Data Structures II', unit: 3),
                CourseData(code: 'CSC 208', title: 'Introduction to Operating Systems', unit: 3),
                CourseData(code: 'MTH 202', title: 'Mathematical Methods II', unit: 3),
                CourseData(code: 'STA 202', title: 'Probability II', unit: 3),
                CourseData(code: 'GST 212', title: 'Communication in English IV', unit: 2),
              ]),
            ]),
            // ── 300 Level ──
            LevelData(level: '300', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CSC 301', title: 'Algorithm and Complexity', unit: 3),
                CourseData(code: 'CSC 303', title: 'Database Systems I', unit: 3),
                CourseData(code: 'CSC 305', title: 'Software Engineering I', unit: 3),
                CourseData(code: 'CSC 307', title: 'Computer Networks I', unit: 3),
                CourseData(code: 'CSC 309', title: 'Systems Programming', unit: 3),
                CourseData(code: 'MTH 305', title: 'Numerical Analysis I', unit: 3),
                CourseData(code: 'GST 311', title: 'Entrepreneurship I', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CSC 302', title: 'Compiler Construction', unit: 3),
                CourseData(code: 'CSC 304', title: 'Database Systems II', unit: 3),
                CourseData(code: 'CSC 306', title: 'Software Engineering II', unit: 3),
                CourseData(code: 'CSC 308', title: 'Computer Networks II', unit: 3),
                CourseData(code: 'CSC 310', title: 'Artificial Intelligence', unit: 3),
                CourseData(code: 'CSC 312', title: 'Human-Computer Interaction', unit: 3),
                CourseData(code: 'GST 312', title: 'Entrepreneurship II', unit: 2),
              ]),
            ]),
            // ── 400 Level ──
            LevelData(level: '400', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CSC 401', title: 'Machine Learning', unit: 3),
                CourseData(code: 'CSC 403', title: 'Information Security', unit: 3),
                CourseData(code: 'CSC 405', title: 'Mobile Application Development', unit: 3),
                CourseData(code: 'CSC 407', title: 'Cloud Computing', unit: 3),
                CourseData(code: 'CSC 409', title: 'Computer Graphics', unit: 3),
                CourseData(code: 'CSC 499', title: 'Research Project I', unit: 3),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CSC 402', title: 'Deep Learning', unit: 3),
                CourseData(code: 'CSC 404', title: 'Distributed Systems', unit: 3),
                CourseData(code: 'CSC 406', title: 'Internet of Things', unit: 3),
                CourseData(code: 'CSC 408', title: 'Big Data Analytics', unit: 3),
                CourseData(code: 'CSC 410', title: 'Natural Language Processing', unit: 3),
                CourseData(code: 'CSC 400', title: 'Research Project II', unit: 6),
              ]),
            ]),
          ],
        ),

        // ══════════════════════════════════════════════════
        //  PHYSICS
        // ══════════════════════════════════════════════════
        DepartmentData(
          name: 'Physics',
          levels: [
            LevelData(level: '100', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'PHY 101', title: 'General Physics I', unit: 3),
                CourseData(code: 'PHY 107', title: 'Practical Physics I', unit: 1),
                CourseData(code: 'MTH 101', title: 'Elementary Mathematics I', unit: 3),
                CourseData(code: 'MTH 103', title: 'Elementary Mathematics III', unit: 2),
                CourseData(code: 'CHM 101', title: 'General Chemistry I', unit: 3),
                CourseData(code: 'CHM 107', title: 'Practical Chemistry I', unit: 1),
                CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
                CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'PHY 102', title: 'General Physics II', unit: 3),
                CourseData(code: 'PHY 108', title: 'Practical Physics II', unit: 1),
                CourseData(code: 'MTH 102', title: 'Elementary Mathematics II', unit: 3),
                CourseData(code: 'MTH 104', title: 'Elementary Mathematics IV', unit: 2),
                CourseData(code: 'CHM 102', title: 'General Chemistry II', unit: 3),
                CourseData(code: 'BIO 102', title: 'General Biology II', unit: 3),
                CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
                CourseData(code: 'GST 114', title: 'History and Philosophy of Science', unit: 2),
              ]),
            ]),
            LevelData(level: '200', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'PHY 201', title: 'Classical Mechanics', unit: 3),
                CourseData(code: 'PHY 203', title: 'Electricity & Magnetism I', unit: 3),
                CourseData(code: 'PHY 205', title: 'Waves & Optics', unit: 3),
                CourseData(code: 'PHY 207', title: 'Practical Physics III', unit: 1),
                CourseData(code: 'MTH 201', title: 'Mathematical Methods I', unit: 3),
                CourseData(code: 'MTH 207', title: 'Vector Analysis', unit: 3),
                CourseData(code: 'GST 211', title: 'Communication in English III', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'PHY 202', title: 'Thermodynamics', unit: 3),
                CourseData(code: 'PHY 204', title: 'Electricity & Magnetism II', unit: 3),
                CourseData(code: 'PHY 206', title: 'Modern Physics', unit: 3),
                CourseData(code: 'PHY 208', title: 'Practical Physics IV', unit: 1),
                CourseData(code: 'MTH 202', title: 'Mathematical Methods II', unit: 3),
                CourseData(code: 'MTH 208', title: 'Ordinary Differential Equations', unit: 3),
                CourseData(code: 'GST 212', title: 'Communication in English IV', unit: 2),
              ]),
            ]),
            LevelData(level: '300', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'PHY 301', title: 'Quantum Mechanics I', unit: 3),
                CourseData(code: 'PHY 303', title: 'Solid State Physics I', unit: 3),
                CourseData(code: 'PHY 305', title: 'Electronics I', unit: 3),
                CourseData(code: 'PHY 307', title: 'Statistical Mechanics', unit: 3),
                CourseData(code: 'MTH 307', title: 'Partial Differential Equations', unit: 3),
                CourseData(code: 'GST 311', title: 'Entrepreneurship I', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'PHY 302', title: 'Quantum Mechanics II', unit: 3),
                CourseData(code: 'PHY 304', title: 'Solid State Physics II', unit: 3),
                CourseData(code: 'PHY 306', title: 'Electronics II', unit: 3),
                CourseData(code: 'PHY 308', title: 'Electrodynamics', unit: 3),
                CourseData(code: 'PHY 310', title: 'Nuclear Physics', unit: 3),
                CourseData(code: 'GST 312', title: 'Entrepreneurship II', unit: 2),
              ]),
            ]),
            LevelData(level: '400', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'PHY 401', title: 'Atomic & Molecular Physics', unit: 3),
                CourseData(code: 'PHY 403', title: 'Plasma Physics', unit: 3),
                CourseData(code: 'PHY 405', title: 'Astrophysics', unit: 3),
                CourseData(code: 'PHY 407', title: 'Geophysics', unit: 3),
                CourseData(code: 'PHY 499', title: 'Research Project I', unit: 3),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'PHY 402', title: 'Laser Physics', unit: 3),
                CourseData(code: 'PHY 404', title: 'Medical Physics', unit: 3),
                CourseData(code: 'PHY 406', title: 'Computational Physics', unit: 3),
                CourseData(code: 'PHY 400', title: 'Research Project II', unit: 6),
              ]),
            ]),
          ],
        ),

        // ══════════════════════════════════════════════════
        //  CHEMISTRY
        // ══════════════════════════════════════════════════
        DepartmentData(
          name: 'Chemistry',
          levels: [
            LevelData(level: '100', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CHM 101', title: 'General Chemistry I', unit: 3),
                CourseData(code: 'CHM 107', title: 'Practical Chemistry I', unit: 1),
                CourseData(code: 'MTH 101', title: 'Elementary Mathematics I', unit: 3),
                CourseData(code: 'PHY 101', title: 'General Physics I', unit: 3),
                CourseData(code: 'BIO 101', title: 'General Biology I', unit: 3),
                CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
                CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CHM 102', title: 'General Chemistry II', unit: 3),
                CourseData(code: 'CHM 108', title: 'Practical Chemistry II', unit: 1),
                CourseData(code: 'MTH 102', title: 'Elementary Mathematics II', unit: 3),
                CourseData(code: 'PHY 102', title: 'General Physics II', unit: 3),
                CourseData(code: 'BIO 102', title: 'General Biology II', unit: 3),
                CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
                CourseData(code: 'GST 114', title: 'History and Philosophy of Science', unit: 2),
              ]),
            ]),
            LevelData(level: '200', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CHM 201', title: 'Physical Chemistry I', unit: 3),
                CourseData(code: 'CHM 203', title: 'Organic Chemistry I', unit: 3),
                CourseData(code: 'CHM 205', title: 'Inorganic Chemistry I', unit: 3),
                CourseData(code: 'CHM 207', title: 'Practical Chemistry III', unit: 1),
                CourseData(code: 'MTH 201', title: 'Mathematical Methods I', unit: 3),
                CourseData(code: 'GST 211', title: 'Communication in English III', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CHM 202', title: 'Physical Chemistry II', unit: 3),
                CourseData(code: 'CHM 204', title: 'Organic Chemistry II', unit: 3),
                CourseData(code: 'CHM 206', title: 'Inorganic Chemistry II', unit: 3),
                CourseData(code: 'CHM 208', title: 'Practical Chemistry IV', unit: 1),
                CourseData(code: 'CHM 210', title: 'Analytical Chemistry I', unit: 3),
                CourseData(code: 'GST 212', title: 'Communication in English IV', unit: 2),
              ]),
            ]),
            LevelData(level: '300', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CHM 301', title: 'Quantum Chemistry', unit: 3),
                CourseData(code: 'CHM 303', title: 'Spectroscopy', unit: 3),
                CourseData(code: 'CHM 305', title: 'Organic Chemistry III', unit: 3),
                CourseData(code: 'CHM 307', title: 'Inorganic Chemistry III', unit: 3),
                CourseData(code: 'CHM 309', title: 'Practical Chemistry V', unit: 1),
                CourseData(code: 'GST 311', title: 'Entrepreneurship I', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CHM 302', title: 'Chemical Kinetics', unit: 3),
                CourseData(code: 'CHM 304', title: 'Electrochemistry', unit: 3),
                CourseData(code: 'CHM 306', title: 'Industrial Chemistry', unit: 3),
                CourseData(code: 'CHM 308', title: 'Environmental Chemistry', unit: 3),
                CourseData(code: 'CHM 310', title: 'Practical Chemistry VI', unit: 1),
                CourseData(code: 'GST 312', title: 'Entrepreneurship II', unit: 2),
              ]),
            ]),
            LevelData(level: '400', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'CHM 401', title: 'Advanced Organic Chemistry', unit: 3),
                CourseData(code: 'CHM 403', title: 'Advanced Physical Chemistry', unit: 3),
                CourseData(code: 'CHM 405', title: 'Polymer Chemistry', unit: 3),
                CourseData(code: 'CHM 407', title: 'Biochemistry', unit: 3),
                CourseData(code: 'CHM 499', title: 'Research Project I', unit: 3),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'CHM 402', title: 'Medicinal Chemistry', unit: 3),
                CourseData(code: 'CHM 404', title: 'Petroleum Chemistry', unit: 3),
                CourseData(code: 'CHM 406', title: 'Advanced Analytical Chemistry', unit: 3),
                CourseData(code: 'CHM 400', title: 'Research Project II', unit: 6),
              ]),
            ]),
          ],
        ),

        // ══════════════════════════════════════════════════
        //  BIOLOGY
        // ══════════════════════════════════════════════════
        DepartmentData(
          name: 'Biology',
          levels: [
            LevelData(level: '100', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'BIO 101', title: 'General Biology I', unit: 3),
                CourseData(code: 'BIO 107', title: 'Practical Biology I', unit: 1),
                CourseData(code: 'CHM 101', title: 'General Chemistry I', unit: 3),
                CourseData(code: 'PHY 101', title: 'General Physics I', unit: 3),
                CourseData(code: 'MTH 101', title: 'Elementary Mathematics I', unit: 3),
                CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
                CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'BIO 102', title: 'General Biology II', unit: 3),
                CourseData(code: 'BIO 108', title: 'Practical Biology II', unit: 1),
                CourseData(code: 'CHM 102', title: 'General Chemistry II', unit: 3),
                CourseData(code: 'PHY 102', title: 'General Physics II', unit: 3),
                CourseData(code: 'MTH 102', title: 'Elementary Mathematics II', unit: 3),
                CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
                CourseData(code: 'GST 114', title: 'History and Philosophy of Science', unit: 2),
              ]),
            ]),
            LevelData(level: '200', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'BIO 201', title: 'Cell Biology', unit: 3),
                CourseData(code: 'BIO 203', title: 'Genetics', unit: 3),
                CourseData(code: 'BIO 205', title: 'Ecology I', unit: 3),
                CourseData(code: 'BIO 207', title: 'Zoology I', unit: 3),
                CourseData(code: 'BIO 209', title: 'Botany I', unit: 3),
                CourseData(code: 'GST 211', title: 'Communication in English III', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'BIO 202', title: 'Microbiology', unit: 3),
                CourseData(code: 'BIO 204', title: 'Biochemistry I', unit: 3),
                CourseData(code: 'BIO 206', title: 'Ecology II', unit: 3),
                CourseData(code: 'BIO 208', title: 'Zoology II', unit: 3),
                CourseData(code: 'BIO 210', title: 'Botany II', unit: 3),
                CourseData(code: 'GST 212', title: 'Communication in English IV', unit: 2),
              ]),
            ]),
            LevelData(level: '300', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'BIO 301', title: 'Molecular Biology', unit: 3),
                CourseData(code: 'BIO 303', title: 'Physiology I', unit: 3),
                CourseData(code: 'BIO 305', title: 'Evolution', unit: 3),
                CourseData(code: 'BIO 307', title: 'Immunology', unit: 3),
                CourseData(code: 'GST 311', title: 'Entrepreneurship I', unit: 2),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'BIO 302', title: 'Bioinformatics', unit: 3),
                CourseData(code: 'BIO 304', title: 'Physiology II', unit: 3),
                CourseData(code: 'BIO 306', title: 'Toxicology', unit: 3),
                CourseData(code: 'BIO 308', title: 'Parasitology', unit: 3),
                CourseData(code: 'GST 312', title: 'Entrepreneurship II', unit: 2),
              ]),
            ]),
            LevelData(level: '400', semesters: [
              SemesterData(label: 'First Semester', courses: [
                CourseData(code: 'BIO 401', title: 'Conservation Biology', unit: 3),
                CourseData(code: 'BIO 403', title: 'Neuroscience', unit: 3),
                CourseData(code: 'BIO 405', title: 'Biotechnology', unit: 3),
                CourseData(code: 'BIO 499', title: 'Research Project I', unit: 3),
              ]),
              SemesterData(label: 'Second Semester', courses: [
                CourseData(code: 'BIO 402', title: 'Genomics & Proteomics', unit: 3),
                CourseData(code: 'BIO 404', title: 'Environmental Management', unit: 3),
                CourseData(code: 'BIO 400', title: 'Research Project II', unit: 6),
              ]),
            ]),
          ],
        ),
      ],
    ),
  ],
);

// ─────────────────────────────────────────────────────────
//  LOOKUP HELPERS
// ─────────────────────────────────────────────────────────

/// Returns all faculties in the university
List<String> getFaculties() =>
    uniportData.faculties.map((f) => f.name).toList();

/// Returns departments for a given faculty name
List<String> getDepartments(String facultyName) {
  final faculty = uniportData.faculties
      .where((f) => f.name == facultyName)
      .firstOrNull;
  return faculty?.departments.map((d) => d.name).toList() ?? [];
}

/// Returns levels for a given faculty + department
List<String> getLevels(String facultyName, String deptName) {
  final dept = _getDept(facultyName, deptName);
  return dept?.levels.map((l) => l.level).toList() ?? [];
}

/// Returns semesters for a given faculty + department + level
List<String> getSemesters(
    String facultyName, String deptName, String level) {
  final lvl = _getLevel(facultyName, deptName, level);
  return lvl?.semesters.map((s) => s.label).toList() ?? [];
}

/// Returns courses for a given faculty + department + level + semester
List<CourseData> getCourses(
    String facultyName, String deptName, String level, String semester) {
  final sem = _getSemester(facultyName, deptName, level, semester);
  return sem?.courses ?? [];
}

// Private helpers
DepartmentData? _getDept(String faculty, String dept) {
  final f = uniportData.faculties.where((f) => f.name == faculty).firstOrNull;
  return f?.departments.where((d) => d.name == dept).firstOrNull;
}

LevelData? _getLevel(String faculty, String dept, String level) {
  final d = _getDept(faculty, dept);
  return d?.levels.where((l) => l.level == level).firstOrNull;
}

SemesterData? _getSemester(
    String faculty, String dept, String level, String semester) {
  final l = _getLevel(faculty, dept, level);
  return l?.semesters.where((s) => s.label == semester).firstOrNull;
}
