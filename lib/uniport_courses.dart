// uniport_courses.dart
// Nigerian University Course Data
// University of Port Harcourt — 15 Faculties + Nigerian schools list

class CourseData {
  final String code;
  final String title;
  final int unit;

  const CourseData({
    required this.code,
    required this.title,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {'code': code, 'title': title, 'unit': unit};
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
//  NIGERIAN SCHOOLS LIST (UniPort first, then alphabetical)
// ─────────────────────────────────────────────────────────

const List<String> nigerianUniversities = [
  'University of Port Harcourt',
  'Abia State University',
  'Ahmadu Bello University',
  'Ambrose Alli University',
  'Bayero University Kano',
  'Benson Idahosa University',
  'Covenant University',
  'Delta State University',
  'Enugu State University of Science and Technology',
  'Federal University of Technology Akure',
  'Federal University of Technology Minna',
  'Federal University of Technology Owerri',
  'Imo State University',
  'Lagos State University',
  'Nnamdi Azikiwe University',
  'Obafemi Awolowo University',
  'Rivers State University',
  'University of Abuja',
  'University of Benin',
  'University of Calabar',
  'University of Ibadan',
  'University of Ilorin',
  'University of Jos',
  'University of Lagos',
  'University of Maiduguri',
  'University of Nigeria Nsukka',
];

// ─────────────────────────────────────────────────────────
//  SHARED GST COURSES
// ─────────────────────────────────────────────────────────

const _gst100_1 = <CourseData>[
  CourseData(code: 'GST 111', title: 'Communication in English I', unit: 2),
  CourseData(code: 'GST 113', title: 'Nigerian Peoples and Culture', unit: 2),
];
const _gst100_2 = <CourseData>[
  CourseData(code: 'GST 112', title: 'Communication in English II', unit: 2),
  CourseData(
    code: 'GST 114',
    title: 'History and Philosophy of Science',
    unit: 2,
  ),
];
const _gst200_1 = <CourseData>[
  CourseData(
    code: 'GST 211',
    title: 'Logic, Philosophy and Human Existence',
    unit: 2,
  ),
];
const _gst200_2 = <CourseData>[
  CourseData(
    code: 'GST 212',
    title: 'Peace Studies and Conflict Resolution',
    unit: 2,
  ),
];
const _gst300 = <CourseData>[
  CourseData(code: 'GST 312', title: 'Entrepreneurship Studies', unit: 2),
];

// ─────────────────────────────────────────────────────────
//  UNIVERSITY OF PORT HARCOURT
// ─────────────────────────────────────────────────────────

const UniversityData uniportData = UniversityData(
  name: 'University of Port Harcourt',
  faculties: [
    // ── 1. AGRICULTURE ──
    FacultyData(
      name: 'Faculty of Agriculture',
      departments: [
        DepartmentData(
          name: 'Crop and Soil Science',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'AGR 101',
                      title: 'Introduction to Agriculture',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'AGR 102',
                      title: 'Fundamentals of Crop Production',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 102',
                      title: 'Introduction to Statistics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 201',
                      title: 'Introduction to Soil Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSS 203',
                      title: 'Crop Physiology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'AGR 201',
                      title: 'Agricultural Ecology',
                      unit: 2,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 202',
                      title: 'Soil Chemistry and Mineralogy',
                      unit: 3,
                    ),
                    CourseData(code: 'CSS 204', title: 'Weed Science', unit: 3),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 301',
                      title: 'Soil Fertility and Plant Nutrition',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSS 303',
                      title: 'Crop Improvement I',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 302',
                      title: 'Soil Conservation and Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSS 304',
                      title: 'Crop Protection',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 401',
                      title: 'Advanced Soil Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSS 403',
                      title: 'Research Methods in Agriculture',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSS 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'CSS 402',
                      title: 'Land Evaluation and Use',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Animal Science',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'AGR 101',
                      title: 'Introduction to Agriculture',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 102',
                      title: 'Introduction to Animal Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 201',
                      title: 'Animal Nutrition I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ANS 203',
                      title: 'Animal Genetics',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 202',
                      title: 'Animal Nutrition II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ANS 204',
                      title: 'Livestock Production',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 301',
                      title: 'Poultry Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ANS 303',
                      title: 'Animal Breeding',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 302',
                      title: 'Meat Science and Technology',
                      unit: 3,
                    ),
                    CourseData(code: 'ANS 304', title: 'Aquaculture', unit: 3),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 401',
                      title: 'Animal Feed and Feeding',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ANS 403',
                      title: 'Research Methods',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ANS 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'ANS 402',
                      title: 'Range Management',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 2. ARTS ──
    FacultyData(
      name: 'Faculty of Arts',
      departments: [
        DepartmentData(
          name: 'English and Literary Studies',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 101',
                      title: 'Introduction to Literature',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ENG 103',
                      title: 'Use of English I',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 102',
                      title: 'Introduction to Linguistics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ENG 104',
                      title: 'Use of English II',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 201',
                      title: 'Introduction to Poetry',
                      unit: 3,
                    ),
                    CourseData(code: 'ENG 203', title: 'Phonology', unit: 3),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 202',
                      title: 'Introduction to Drama',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ENG 204',
                      title: 'Morphology and Syntax',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 301',
                      title: 'African Literature in English',
                      unit: 3,
                    ),
                    CourseData(code: 'ENG 303', title: 'Semantics', unit: 3),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 302',
                      title: 'Caribbean Literature',
                      unit: 3,
                    ),
                    CourseData(code: 'ENG 304', title: 'Stylistics', unit: 3),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ENG 401',
                      title: 'Research Methods in English',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ENG 403',
                      title: 'Advanced Linguistics',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'ENG 498', title: 'Long Essay', unit: 6),
                    CourseData(
                      code: 'ENG 402',
                      title: 'Creative Writing',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'History and Diplomatic Studies',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'HIS 101',
                      title: 'African History I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'HIS 103',
                      title: 'Introduction to Diplomatic Studies',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'HIS 102',
                      title: 'African History II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'HIS 104',
                      title: 'World History',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'HIS 201',
                      title: 'History of West Africa I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'HIS 203',
                      title: 'History of International Relations',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'HIS 202',
                      title: 'History of West Africa II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'HIS 204',
                      title: 'Nigerian History',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 3. EDUCATION ──
    FacultyData(
      name: 'Faculty of Education',
      departments: [
        DepartmentData(
          name: 'Educational Management',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 101',
                      title: 'Introduction to Education',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EDU 103',
                      title: 'History of Education',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 102',
                      title: 'Sociology of Education',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EDU 104',
                      title: 'Philosophy of Education',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 201',
                      title: 'Educational Psychology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EDM 201',
                      title: 'Principles of Educational Management',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 202',
                      title: 'Educational Psychology II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EDM 202',
                      title: 'School Administration',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Curriculum Studies and Educational Technology',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 101',
                      title: 'Introduction to Education',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CST 101',
                      title: 'Introduction to Curriculum Studies',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EDU 102',
                      title: 'Sociology of Education',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ETH 102',
                      title: 'Educational Technology Basics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CST 201',
                      title: 'Curriculum Theory',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ETH 201',
                      title: 'Instructional Technology',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CST 202',
                      title: 'Curriculum Development',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ETH 202',
                      title: 'Media in Education',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 4. ENGINEERING ──
    FacultyData(
      name: 'Faculty of Engineering',
      departments: [
        DepartmentData(
          name: 'Chemical Engineering',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHM 102',
                      title: 'General Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 102',
                      title: 'Intro to Chemical Engineering',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 201',
                      title: 'Material and Energy Balances',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 203',
                      title: 'Chemical Engineering Thermodynamics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 205',
                      title: 'Fluid Mechanics',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 202',
                      title: 'Transport Phenomena',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 204',
                      title: 'Chemical Engineering Thermodynamics II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 301',
                      title: 'Chemical Reaction Engineering I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 303',
                      title: 'Heat Transfer',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 302',
                      title: 'Chemical Reaction Engineering II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHE 304',
                      title: 'Mass Transfer',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 401',
                      title: 'Process Control',
                      unit: 3,
                    ),
                    CourseData(code: 'CHE 403', title: 'Plant Design', unit: 3),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHE 498',
                      title: 'Final Year Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'CHE 402',
                      title: 'Safety Engineering',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Civil Engineering',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CVE 101',
                      title: 'Engineering Drawing',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CVE 102',
                      title: 'Intro to Civil Engineering',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CVE 201',
                      title: 'Structural Mechanics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CVE 203',
                      title: 'Engineering Geology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CVE 205',
                      title: 'Fluid Mechanics I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CVE 202',
                      title: 'Structural Mechanics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CVE 204',
                      title: 'Soil Mechanics',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Electrical and Electronic Engineering',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ENG 101',
                      title: 'Technical Drawing',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 102',
                      title: 'General Physics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 101',
                      title: 'Introduction to Computing',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 201',
                      title: 'Circuit Theory I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 203',
                      title: 'Engineering Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 205',
                      title: 'Workshop Practice',
                      unit: 2,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 202',
                      title: 'Circuit Theory II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 204',
                      title: 'Engineering Mathematics II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 301',
                      title: 'Electromagnetic Fields',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 303',
                      title: 'Electronics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 305',
                      title: 'Signals and Systems',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 302',
                      title: 'Electronics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 304',
                      title: 'Power Systems I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 306',
                      title: 'Control Systems I',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 401',
                      title: 'Power Electronics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 403',
                      title: 'Communications Engineering',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 405',
                      title: 'Digital Electronics',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 402',
                      title: 'Machine Design',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 404',
                      title: 'Microprocessors',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '500',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 501',
                      title: 'Advanced Power Systems',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 503',
                      title: 'Renewable Energy Systems',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EEE 505',
                      title: 'Engineering Project Management',
                      unit: 2,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EEE 598',
                      title: 'Final Year Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'EEE 502',
                      title: 'High Voltage Engineering',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Mechanical Engineering',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MEE 101',
                      title: 'Engineering Drawing',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 102',
                      title: 'General Physics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MEE 102',
                      title: 'Workshop Technology',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MEE 201',
                      title: 'Engineering Mechanics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MEE 203',
                      title: 'Thermodynamics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MEE 205',
                      title: 'Material Science',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MEE 202',
                      title: 'Engineering Mechanics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MEE 204',
                      title: 'Thermodynamics II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 5. ENVIRONMENTAL SCIENCES ──
    FacultyData(
      name: 'Faculty of Environmental Sciences',
      departments: [
        DepartmentData(
          name: 'Architecture',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ARC 101',
                      title: 'Introduction to Architecture',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ARC 103',
                      title: 'Architectural Drawing',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ARC 102',
                      title: 'Architectural Design I',
                      unit: 4,
                    ),
                    CourseData(
                      code: 'ARC 104',
                      title: 'Building Materials',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ARC 201',
                      title: 'Architectural Design II',
                      unit: 4,
                    ),
                    CourseData(
                      code: 'ARC 203',
                      title: 'Environmental Science',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ARC 202',
                      title: 'Architectural Design III',
                      unit: 4,
                    ),
                    CourseData(
                      code: 'ARC 204',
                      title: 'Structural Systems',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Estate Management',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EST 101',
                      title: 'Introduction to Estate Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 101',
                      title: 'Introduction to Economics',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EST 102',
                      title: 'Building Technology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 102',
                      title: 'Microeconomics I',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'EST 201',
                      title: 'Land Law and Administration',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EST 203',
                      title: 'Property Valuation I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'EST 202',
                      title: 'Urban and Regional Planning',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'EST 204',
                      title: 'Property Valuation II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 6. HEALTH SCIENCES AND TECHNOLOGY ──
    FacultyData(
      name: 'Faculty of Health Sciences and Technology',
      departments: [
        DepartmentData(
          name: 'Medical Laboratory Science',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MLS 101',
                      title: 'Introduction to Medical Lab Science',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MLS 102',
                      title: 'Basic Microbiology',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MLS 201',
                      title: 'Haematology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MLS 203',
                      title: 'Clinical Chemistry I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MLS 202',
                      title: 'Haematology II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MLS 204',
                      title: 'Medical Microbiology I',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Nursing Science',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'NUR 101',
                      title: 'Introduction to Nursing',
                      unit: 3,
                    ),
                    CourseData(code: 'ANT 101', title: 'Anatomy I', unit: 3),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'NUR 102',
                      title: 'Fundamentals of Nursing Practice',
                      unit: 4,
                    ),
                    CourseData(code: 'ANT 102', title: 'Anatomy II', unit: 3),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'NUR 201',
                      title: 'Adult Health Nursing I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'NUR 203',
                      title: 'Pharmacology for Nurses',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'NUR 202',
                      title: 'Adult Health Nursing II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'NUR 204',
                      title: 'Community Health Nursing',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 7. HUMANITIES ──
    FacultyData(
      name: 'Faculty of Humanities',
      departments: [
        DepartmentData(
          name: 'Philosophy',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PHI 101',
                      title: 'Introduction to Philosophy',
                      unit: 3,
                    ),
                    CourseData(code: 'PHI 103', title: 'Logic I', unit: 3),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'PHI 102', title: 'Ethics I', unit: 3),
                    CourseData(code: 'PHI 104', title: 'Logic II', unit: 3),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(code: 'PHI 201', title: 'Epistemology', unit: 3),
                    CourseData(
                      code: 'PHI 203',
                      title: 'African Philosophy',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'PHI 202', title: 'Metaphysics', unit: 3),
                    CourseData(
                      code: 'PHI 204',
                      title: 'Political Philosophy',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Theatre and Film Studies',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'TFS 101',
                      title: 'Introduction to Theatre',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'TFS 103',
                      title: 'Elements of Drama',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'TFS 102', title: 'Stagecraft', unit: 3),
                    CourseData(
                      code: 'TFS 104',
                      title: 'Introduction to Film',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'TFS 201',
                      title: 'History of Theatre',
                      unit: 3,
                    ),
                    CourseData(code: 'TFS 203', title: 'Directing I', unit: 3),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'TFS 202',
                      title: 'African Drama',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'TFS 204',
                      title: 'Film Analysis',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 8. LAW ──
    FacultyData(
      name: 'Faculty of Law',
      departments: [
        DepartmentData(
          name: 'Law',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 101',
                      title: 'Introduction to Law',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 103',
                      title: 'Nigerian Legal System',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 105',
                      title: 'Legal Methods',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 102',
                      title: 'Constitutional Law I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 104',
                      title: 'Law of Torts I',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 201',
                      title: 'Law of Contract I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 203',
                      title: 'Constitutional Law II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 205',
                      title: 'Criminal Law I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 202',
                      title: 'Law of Contract II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 204',
                      title: 'Criminal Law II',
                      unit: 3,
                    ),
                    CourseData(code: 'LAW 206', title: 'Land Law', unit: 3),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 301',
                      title: 'Equity and Trusts',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 303',
                      title: 'Commercial Law',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 302',
                      title: 'Administrative Law',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 304',
                      title: 'Law of Evidence',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 401',
                      title: 'International Law',
                      unit: 3,
                    ),
                    CourseData(code: 'LAW 403', title: 'Company Law', unit: 3),
                    CourseData(
                      code: 'LAW 405',
                      title: 'Jurisprudence',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 402',
                      title: 'Petroleum Law',
                      unit: 3,
                    ),
                    CourseData(code: 'LAW 404', title: 'Labour Law', unit: 3),
                    CourseData(code: 'LAW 498', title: 'Law Project', unit: 4),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '500',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 501',
                      title: 'Advanced Constitutional Law',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 503',
                      title: 'Conflict of Laws',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'LAW 502',
                      title: 'Clinical Legal Education',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'LAW 504',
                      title: 'Environmental Law',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 9. MANAGEMENT SCIENCES ──
    FacultyData(
      name: 'Faculty of Management Sciences',
      departments: [
        DepartmentData(
          name: 'Accounting',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 101',
                      title: 'Introduction to Financial Accounting',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 101',
                      title: 'Introduction to Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 102',
                      title: 'Principles of Accounting',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 102',
                      title: 'Microeconomics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BUS 102',
                      title: 'Business Mathematics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 201',
                      title: 'Intermediate Accounting I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ACC 203',
                      title: 'Cost Accounting',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BUS 201',
                      title: 'Business Statistics',
                      unit: 2,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 202',
                      title: 'Intermediate Accounting II',
                      unit: 3,
                    ),
                    CourseData(code: 'ACC 204', title: 'Taxation I', unit: 3),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 301',
                      title: 'Advanced Accounting I',
                      unit: 3,
                    ),
                    CourseData(code: 'ACC 303', title: 'Auditing I', unit: 3),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 302',
                      title: 'Advanced Accounting II',
                      unit: 3,
                    ),
                    CourseData(code: 'ACC 304', title: 'Auditing II', unit: 3),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 401',
                      title: 'Public Sector Accounting',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ACC 403',
                      title: 'Financial Reporting',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ACC 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'ACC 402',
                      title: 'Accounting Information Systems',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Banking and Finance',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BFN 101',
                      title: 'Introduction to Banking',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 101',
                      title: 'Introduction to Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BFN 102',
                      title: 'Money and Banking',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ACC 102',
                      title: 'Principles of Accounting',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BFN 201',
                      title: 'Commercial Banking',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BFN 203',
                      title: 'Financial Markets',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BFN 202',
                      title: 'Central Banking',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BFN 204',
                      title: 'Investment Analysis',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Business Administration',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BUS 101',
                      title: 'Introduction to Business',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 101',
                      title: 'Introduction to Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BUS 102',
                      title: 'Business Mathematics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MGT 102',
                      title: 'Principles of Management',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MGT 201',
                      title: 'Organizational Behaviour',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MKT 201',
                      title: 'Principles of Marketing',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MGT 202',
                      title: 'Human Resource Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'FIN 202',
                      title: 'Financial Management',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 10. COLLEGE OF MEDICINE ──
    FacultyData(
      name: 'College of Medicine',
      departments: [
        DepartmentData(
          name: 'Dentistry',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'DEN 101',
                      title: 'Introduction to Dental Science',
                      unit: 2,
                    ),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'ANT 102', title: 'Anatomy I', unit: 4),
                    CourseData(
                      code: 'BCH 102',
                      title: 'Biochemistry I',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(code: 'DEN 201', title: 'Oral Anatomy', unit: 3),
                    CourseData(code: 'ANT 201', title: 'Anatomy II', unit: 3),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'DEN 202',
                      title: 'Oral Histology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHS 202',
                      title: 'Physiology II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Medicine and Surgery',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MED 101',
                      title: 'Introduction to Medicine',
                      unit: 2,
                    ),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'ANT 102', title: 'Anatomy I', unit: 4),
                    CourseData(code: 'PHS 102', title: 'Physiology I', unit: 4),
                    CourseData(
                      code: 'BCH 102',
                      title: 'Biochemistry I',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(code: 'ANT 201', title: 'Anatomy II', unit: 4),
                    CourseData(
                      code: 'PHS 201',
                      title: 'Physiology II',
                      unit: 4,
                    ),
                    CourseData(
                      code: 'BCH 201',
                      title: 'Biochemistry II',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'ANT 202', title: 'Anatomy III', unit: 3),
                    CourseData(
                      code: 'PHS 202',
                      title: 'Physiology III',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PAT 202',
                      title: 'Introduction to Pathology',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 11. PHARMACY ──
    FacultyData(
      name: 'Faculty of Pharmacy',
      departments: [
        DepartmentData(
          name: 'Pharmacy',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PHM 101',
                      title: 'Introduction to Pharmacy',
                      unit: 2,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PHM 102',
                      title: 'Pharmaceutical Botany',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 102',
                      title: 'General Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PHM 201',
                      title: 'Pharmaceutics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHM 203',
                      title: 'Pharmacognosy I',
                      unit: 3,
                    ),
                    CourseData(code: 'BCH 201', title: 'Biochemistry', unit: 3),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PHM 202',
                      title: 'Pharmaceutics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHM 204',
                      title: 'Pharmaceutical Chemistry',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 12. PETROLEUM AND ENERGY STUDIES ──
    FacultyData(
      name: 'Faculty of Petroleum and Energy Studies',
      departments: [
        DepartmentData(
          name: 'Geology',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'GEO 101',
                      title: 'Physical Geology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'GEO 102',
                      title: 'Historical Geology',
                      unit: 3,
                    ),
                    CourseData(code: 'GEO 104', title: 'Mineralogy', unit: 3),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'GEO 201',
                      title: 'Structural Geology',
                      unit: 3,
                    ),
                    CourseData(code: 'GEO 203', title: 'Petrology I', unit: 3),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'GEO 202', title: 'Stratigraphy', unit: 3),
                    CourseData(code: 'GEO 204', title: 'Geochemistry', unit: 3),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Petroleum Engineering',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PET 101',
                      title: 'Introduction to Petroleum Engineering',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'GEO 102',
                      title: 'Fundamentals of Geology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PET 102',
                      title: 'Petroleum Exploration',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PET 201',
                      title: 'Reservoir Engineering I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PET 203',
                      title: 'Drilling Engineering I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PET 205',
                      title: 'Fluid Mechanics',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PET 202',
                      title: 'Reservoir Engineering II',
                      unit: 3,
                    ),
                    CourseData(code: 'PET 204', title: 'Well Logging', unit: 3),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 13. SCIENCE ──
    FacultyData(
      name: 'Faculty of Science',
      departments: [
        DepartmentData(
          name: 'Biochemistry',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BIO 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 102',
                      title: 'General Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 102',
                      title: 'Introduction to Statistics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'BCH 201',
                      title: 'Introduction to Biochemistry',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BCH 203',
                      title: 'Carbohydrate Biochemistry',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 203',
                      title: 'Organic Chemistry I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'BCH 202',
                      title: 'Protein Biochemistry',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'BCH 204',
                      title: 'Lipid Biochemistry',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Chemistry',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 107',
                      title: 'Practical Chemistry I',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHM 102',
                      title: 'General Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 108',
                      title: 'Practical Chemistry II',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'BIO 102',
                      title: 'General Biology II',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CHM 201',
                      title: 'Physical Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 203',
                      title: 'Organic Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 205',
                      title: 'Analytical Chemistry I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CHM 202',
                      title: 'Physical Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 204',
                      title: 'Organic Chemistry II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Computer Science',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 101',
                      title: 'Introduction to Computer Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 103',
                      title: 'Computer Lab Practicals I',
                      unit: 1,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 102',
                      title: 'Introduction to Programming',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 104',
                      title: 'Computer Lab Practicals II',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'STA 102',
                      title: 'Introduction to Statistics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 201',
                      title: 'Structured Programming',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 203',
                      title: 'Data Structures and Algorithms',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 205',
                      title: 'Discrete Mathematics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 203',
                      title: 'Linear Algebra I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 202',
                      title: 'Object-Oriented Programming',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 204',
                      title: 'Computer Organization',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 206',
                      title: 'Operating Systems I',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 301',
                      title: 'Database Systems',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 303',
                      title: 'Computer Networks',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 305',
                      title: 'Software Engineering',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 307',
                      title: 'Algorithm Analysis',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 302',
                      title: 'Compiler Construction',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 304',
                      title: 'Artificial Intelligence',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 306',
                      title: 'Web Technologies',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 308',
                      title: 'Human-Computer Interaction',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 401',
                      title: 'Machine Learning',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 403',
                      title: 'Information Security',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 405',
                      title: 'Mobile Computing',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'CSC 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'CSC 402',
                      title: 'Cloud Computing',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 404',
                      title: 'Distributed Systems',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Mathematics and Statistics',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 110',
                      title: 'Algebra and Trigonometry',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 120',
                      title: 'Calculus',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 101',
                      title: 'Mechanics and Properties of Matter',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 102',
                      title: 'Practical Physics I',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'CHM 130',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'GES 100',
                      title: 'Communication Skills in English',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'FSB 101',
                      title: 'General Biology I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 101',
                      title: 'Introduction to Computer Science',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 114',
                      title: 'Introduction to Set, Logic and Algebra',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 124',
                      title: 'Coordinate Geometry',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 112',
                      title: 'Electricity and Magnetism',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 103',
                      title: 'Practical Physics II',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'CHM 131',
                      title: 'General Chemistry II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'GES 103',
                      title: 'Nigerian People and Culture',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 160',
                      title: 'Descriptive Statistics',
                      unit: 2,
                    ),
                    CourseData(
                      code: 'STA 190',
                      title: 'Lab for Descriptive Statistics',
                      unit: 1,
                    ),
                      CourseData(
                      code: 'STA 121',
                      title: 'Statistical Inference 1',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 210',
                      title: 'Linear Algebra 1',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 220',
                      title: 'Real Analysis',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 230',
                      title: 'Group Theorem I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 270',
                      title: 'Numerical Analysis',
                      unit: 2,
                    ),
                    CourseData(
                      code: 'STA 260',
                      title: 'Probability I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 261',
                      title: 'Statistical inference II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CSC 280',
                      title: 'Computer Programming',
                      unit: 2,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 202',
                      title: 'Mathematical Methods II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 204',
                      title: 'Linear Algebra II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 206',
                      title: 'Real Analysis II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 202',
                      title: 'Probability II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 204',
                      title: 'Statistical Inference I',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 301',
                      title: 'Complex Analysis',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 303',
                      title: 'Ordinary Differential Equations',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 301',
                      title: 'Statistical Inference II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 303',
                      title: 'Regression Analysis',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 302',
                      title: 'Partial Differential Equations',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 304',
                      title: 'Abstract Algebra',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 302',
                      title: 'Design of Experiments',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 304',
                      title: 'Time Series Analysis',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 401',
                      title: 'Functional Analysis',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 403',
                      title: 'Numerical Analysis',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 401',
                      title: 'Multivariate Analysis',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MTH 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(code: 'MTH 402', title: 'Topology', unit: 3),
                    CourseData(
                      code: 'STA 402',
                      title: 'Operations Research',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Physics',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PHY 101',
                      title: 'General Physics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 107',
                      title: 'Practical Physics I',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'CHM 101',
                      title: 'General Chemistry I',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PHY 102',
                      title: 'General Physics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 108',
                      title: 'Practical Physics II',
                      unit: 1,
                    ),
                    CourseData(
                      code: 'MTH 102',
                      title: 'Elementary Mathematics II',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PHY 201',
                      title: 'Classical Mechanics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 203',
                      title: 'Electricity and Magnetism I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 205',
                      title: 'Mathematical Physics I',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PHY 202',
                      title: 'Waves and Optics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 204',
                      title: 'Electricity and Magnetism II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PHY 206',
                      title: 'Mathematical Physics II',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 14. SOCIAL SCIENCES ──
    FacultyData(
      name: 'Faculty of Social Sciences',
      departments: [
        DepartmentData(
          name: 'Economics',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 101',
                      title: 'Introduction to Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MTH 101',
                      title: 'Elementary Mathematics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ACC 101',
                      title: 'Introduction to Accounting',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 102',
                      title: 'Microeconomics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 104',
                      title: 'Macroeconomics I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'STA 102',
                      title: 'Introduction to Statistics',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 201',
                      title: 'Microeconomics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 203',
                      title: 'Macroeconomics II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 205',
                      title: 'Introduction to Econometrics',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 202',
                      title: 'Development Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 204',
                      title: 'International Economics',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '300',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 301',
                      title: 'Monetary Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 303',
                      title: 'Labour Economics',
                      unit: 3,
                    ),
                    ..._gst300,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 302',
                      title: 'Industrial Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 304',
                      title: 'Nigerian Economic History',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '400',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 401',
                      title: 'Advanced Econometrics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'ECO 403',
                      title: 'Environmental Economics',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'ECO 498',
                      title: 'Research Project',
                      unit: 6,
                    ),
                    CourseData(
                      code: 'ECO 402',
                      title: 'Agricultural Economics',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Political and Administrative Studies',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PAS 101',
                      title: 'Introduction to Political Science',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PAS 103',
                      title: 'Introduction to Public Administration',
                      unit: 3,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PAS 102',
                      title: 'Comparative Politics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PAS 104',
                      title: 'Nigerian Government and Politics',
                      unit: 3,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'PAS 201',
                      title: 'Political Theory I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PAS 203',
                      title: 'International Relations',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'PAS 202',
                      title: 'Political Theory II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'PAS 204',
                      title: 'African Politics',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
        DepartmentData(
          name: 'Sociology',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'SOC 101',
                      title: 'Introduction to Sociology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'SOC 103',
                      title: 'Social Anthropology',
                      unit: 2,
                    ),
                    ..._gst100_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'SOC 102',
                      title: 'Social Psychology',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'SOC 104',
                      title: 'Nigerian Society and Culture',
                      unit: 2,
                    ),
                    ..._gst100_2,
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'SOC 201',
                      title: 'Social Theory I',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'SOC 203',
                      title: 'Social Research Methods',
                      unit: 3,
                    ),
                    ..._gst200_1,
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'SOC 202',
                      title: 'Social Theory II',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'SOC 204',
                      title: 'Sociology of Development',
                      unit: 3,
                    ),
                    ..._gst200_2,
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── 15. GRADUATE SCHOOL OF MANAGEMENT ──
    FacultyData(
      name: 'Graduate School of Management',
      departments: [
        DepartmentData(
          name: 'Master of Business Administration',
          levels: [
            LevelData(
              level: '100',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MBA 501',
                      title: 'Managerial Economics',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 503',
                      title: 'Financial Accounting for Managers',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 505',
                      title: 'Organizational Theory',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 507',
                      title: 'Business Research Methods',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(
                      code: 'MBA 502',
                      title: 'Marketing Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 504',
                      title: 'Financial Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 506',
                      title: 'Human Resource Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 508',
                      title: 'Operations Management',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
            LevelData(
              level: '200',
              semesters: [
                SemesterData(
                  label: 'First Semester',
                  courses: [
                    CourseData(
                      code: 'MBA 601',
                      title: 'Strategic Management',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 603',
                      title: 'Entrepreneurship and Innovation',
                      unit: 3,
                    ),
                    CourseData(
                      code: 'MBA 605',
                      title: 'Corporate Governance',
                      unit: 3,
                    ),
                  ],
                ),
                SemesterData(
                  label: 'Second Semester',
                  courses: [
                    CourseData(code: 'MBA 698', title: 'MBA Thesis', unit: 6),
                    CourseData(
                      code: 'MBA 602',
                      title: 'Business Ethics',
                      unit: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

// ─────────────────────────────────────────────────────────
//  LOOKUP HELPERS
// ─────────────────────────────────────────────────────────

/// All Nigerian universities for school picker
List<String> getAllSchools() => List.from(nigerianUniversities);

/// All faculties (sorted alphabetically)
List<String> getFaculties() {
  final list = uniportData.faculties.map((f) => f.name).toList();
  list.sort();
  return list;
}

/// Departments for a given faculty (sorted alphabetically)
List<String> getDepartments(String facultyName) {
  final faculty = uniportData.faculties
      .where((f) => f.name == facultyName)
      .firstOrNull;
  final list = faculty?.departments.map((d) => d.name).toList() ?? [];
  list.sort();
  return list;
}

/// Levels for a given faculty + department
List<String> getLevels(String facultyName, String deptName) {
  final dept = _getDept(facultyName, deptName);
  return dept?.levels.map((l) => l.level).toList() ?? [];
}

/// Semesters for a given faculty + department + level
List<String> getSemesters(String facultyName, String deptName, String level) {
  final lvl = _getLevel(facultyName, deptName, level);
  return lvl?.semesters.map((s) => s.label).toList() ?? [];
}

/// Courses for a given faculty + department + level + semester
List<CourseData> getCourses(
  String facultyName,
  String deptName,
  String level,
  String semester,
) {
  final sem = _getSemester(facultyName, deptName, level, semester);
  return sem?.courses ?? [];
}

DepartmentData? _getDept(String faculty, String dept) {
  final f = uniportData.faculties.where((f) => f.name == faculty).firstOrNull;
  return f?.departments.where((d) => d.name == dept).firstOrNull;
}

LevelData? _getLevel(String faculty, String dept, String level) {
  final d = _getDept(faculty, dept);
  return d?.levels.where((l) => l.level == level).firstOrNull;
}

SemesterData? _getSemester(
  String faculty,
  String dept,
  String level,
  String semester,
) {
  final l = _getLevel(faculty, dept, level);
  return l?.semesters.where((s) => s.label == semester).firstOrNull;
}
