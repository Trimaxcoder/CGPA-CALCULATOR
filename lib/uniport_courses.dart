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
  "University of Port Harcourt",
  "Abia State University",
  "Abubakar Tafawa Balewa University",
  "Abdu Gusau Polytechnic",
  "Abia State Polytechnic",
  "Abraham Adesanya Polytechnic",
  "Abubakar Tatari Ali Polytechnic",
  "Achievers University",
  "A.D. Rufa'i College of Education",
  "Adamawa State Polytechnic",
  "Adamawa State University",
  "Adamu Augie College of Education",
  "Adamu Tafawa Balewa College of Education",
  "Adeleke University",
  "Adekunle Ajasin University",
  "Afe Babalola University",
  "African University of Science and Technology",
  "Ahmadu Bello University",
  "Ajayi Crowther University",
  "Akwa Ibom State College of Education",
  "Akwa Ibom State Polytechnic",
  "Akwa Ibom State University",
  "Al-Hikmah University",
  "Al-Qalam University",
  "Alvan Ikoku Federal College of Education",
  "Ambrose Alli University",
  "American University of Nigeria",
  "Aminu Saleh College of Education",
  "Anambra State Polytechnic",
  "Augustine University",
  "Auchi Polytechnic",
  "Babcock University",
  "Bamidele Olumilua University of Education, Science and Technology",
  "Bauchi State University",
  "Bayelsa State Polytechnic",
  "Bayero University Kano",
  "Baze University",
  "Bells University of Technology",
  "Benson Idahosa University",
  "Benue State Polytechnic",
  "Bingham University",
  "Bowen University",
  "Caleb University",
  "Captain Elechi Amadi Polytechnic",
  "Caritas University",
  "Chrisland University",
  "Coal City University",
  "College of Education Akwanga",
  "College of Education Gindiri",
  "College of Education Ikere-Ekiti",
  "College of Education Warri",
  "Covenant University",
  "Crawford University",
  "Crescent University",
  "Delta State College of Education Mosogar",
  "Delta State Polytechnic Ogwashi-Uku",
  "Delta State Polytechnic Otefe-Oghara",
  "Delta State Polytechnic Ozoro",
  "Delta State University",
  "Dominican University",
  "Ebonyi State University",
  "Edo State Polytechnic",
  "Edwin Clark University",
  "Ekiti State Polytechnic",
  "Ekiti State University",
  "Elizade University",
  "Emmanuel Alayande College of Education",
  "Enugu State Polytechnic",
  "Enugu State University of Science and Technology",
  "Evangel University",
  "Federal College of Education Abeokuta",
  "Federal College of Education Eha-Amufu",
  "Federal College of Education Kano",
  "Federal College of Education Katsina",
  "Federal College of Education Kontagora",
  "Federal College of Education Obudu",
  "Federal College of Education Okene",
  "Federal College of Education Pankshin",
  "Federal College of Education Potiskum",
  "Federal College of Education Special Oyo",
  "Federal College of Education Technical Akoka",
  "Federal College of Education Technical Asaba",
  "Federal College of Education Technical Bichi",
  "Federal College of Education Technical Gombe",
  "Federal College of Education Technical Omoku",
  "Federal College of Education Yola",
  "Federal College of Education Zaria",
  "Federal Polytechnic Ado-Ekiti",
  "Federal Polytechnic Bali",
  "Federal Polytechnic Bauchi",
  "Federal Polytechnic Bida",
  "Federal Polytechnic Damaturu",
  "Federal Polytechnic Ede",
  "Federal Polytechnic Idah",
  "Federal Polytechnic Ilaro",
  "Federal Polytechnic Kaura Namoda",
  "Federal Polytechnic Mubi",
  "Federal Polytechnic Nasarawa",
  "Federal Polytechnic Nekede",
  "Federal Polytechnic Offa",
  "Federal Polytechnic Oko",
  "Federal Polytechnic Ukana",
  "Federal University Dutse",
  "Federal University Dutsin-Ma",
  "Federal University Gashua",
  "Federal University Kashere",
  "Federal University Lafia",
  "Federal University Lokoja",
  "Federal University Otuoke",
  "Federal University Wukari",
  "Federal University of Agriculture Abeokuta",
  "Federal University of Agriculture Makurdi",
  "Federal University of Petroleum Resources Effurun",
  "Federal University of Technology Akure",
  "Federal University of Technology Minna",
  "Federal University of Technology Owerri",
  "Fountain University",
  "Godfrey Okoye University",
  "Gregory University",
  "Hussaini Adamu Federal Polytechnic",
  "Igbinedion University",
  "Imo State University",
  "Institute of Management and Technology Enugu",
  "Isa Kaita College of Education",
  "Jigawa State College of Education Gumel",
  "Joseph Ayo Babalola University",
  "Kaduna Polytechnic",
  "Kaduna State University",
  "Kano State Polytechnic",
  "Kano University of Science and Technology",
  "Kashim Ibrahim College of Education",
  "Kebbi State University of Science and Technology",
  "Kenule Beeson Saro-Wiwa Polytechnic",
  "Kogi State College of Education Ankpa",
  "Kogi State Polytechnic",
  "Kogi State University",
  "Kwara State Polytechnic",
  "Kwara State University",
  "Ladoke Akintola University of Technology",
  "Lagos State University",
  "Landmark University",
  "Lead City University",
  "Madonna University",
  "Michael Okpara University of Agriculture",
  "Michael Otedola College of Primary Education",
  "Moshood Abiola Polytechnic",
  "Mountain Top University",
  "Nasarawa State Polytechnic",
  "Nasarawa State University",
  "National Open University of Nigeria",
  "Niger Delta University",
  "Niger State Polytechnic",
  "Nile University of Nigeria",
  "Nnamdi Azikiwe University",
  "Novena University",
  "Nwafor Orizu College of Education",
  "Obafemi Awolowo University",
  "Oduduwa University",
  "Ogun State Institute of Technology",
  "Olabisi Onabanjo University",
  "Osun State Polytechnic",
  "Pan-Atlantic University",
  "Plateau State Polytechnic",
  "Ramat Polytechnic",
  "Redeemer's University",
  "Renaissance University",
  "Rivers State Polytechnic",
  "Rivers State University",
  "Rufus Giwa Polytechnic",
  "Sa'adatu Rimi College of Education",
  "Samuel Adegboyega University",
  "Shehu Shagari College of Education",
  "Skyline University Nigeria",
  "Sokoto State University",
  "Tai Solarin College of Education",
  "Tai Solarin University of Education",
  "The Polytechnic Ibadan",
  "Umar Suleiman College of Education",
  "University of Abuja",
  "University of Benin",
  "University of Calabar",
  "University of Ibadan",
  "University of Ilorin",
  "University of Jos",
  "University of Lagos",
  "University of Maiduguri",
  "University of Nigeria Nsukka",
  "University of Uyo",
  "Usmanu Danfodiyo University",
  "Veritas University",
  "Waziri Umaru Federal Polytechnic",
  "Yaba College of Technology",
  "Yobe State Polytechnic",
  "Yobe State University",
  "Zamfara State College of Education Maru",
  "Zamfara State University"
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
          levels: [],
        ),
          
        DepartmentData(
          name: 'Agricultural Economics and Agribusiness Management',
          levels: [],
        ),

        DepartmentData(
          name: 'Agricultural Extension and Development Studies',
          levels: [],
        ),

          DepartmentData(
          name: 'Agricultural Economics and Extension',
          levels: [],
        ),

        DepartmentData(
          name: 'Fisheries',
          levels: [],
        ),

         DepartmentData(
          name: 'Food, Nutrition and Home Science',
          levels: [],
        ),

         DepartmentData(
          name: 'Forestry and Wildlife Management',
          levels: [],
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





    // ── 2. COMMUNICATION AND MEDIA STUDIES ──
    FacultyData(
      name: 'Communication and Media Studies',
      departments: [
        DepartmentData(name: 'Advertising and Public Relations', levels: []),
        DepartmentData(name: 'Broadcasting', levels: []),
        DepartmentData(name: 'Film and Multimedia Studies', levels: []),
        DepartmentData(name: 'Journalism and Media Studies', levels: []),
      ],
    ),


    // ── 3. DENTISTRY ──
    FacultyData(
      name: 'Dentistry', 
      departments: [
        DepartmentData(name: 'Dentistry and Dental Surgery', levels: []),
      ],
    ),





    // ── 4. SCHOOL OF SCIENCE LABORATORY TECHNOLOGY ──
    FacultyData(
      name: 'School of Science Laboratory Technology', 
      departments: [
        DepartmentData(name: 'Biochemistry and Chemistry Technology', levels: []),
        DepartmentData(name: 'Biology and Biotechnology', levels: []),
        DepartmentData(name: 'Biomedical Technology', levels: []),
        DepartmentData(name: 'Geology and Mining Technology', levels: []),
        DepartmentData(name: 'Industrial Chemistry and Petroleum Technology', levels: []),
        DepartmentData(name: 'Microbiology Technology', levels: []),
        DepartmentData(name: 'Physics with Electronic Technology', levels: []),
        DepartmentData(name: 'Physics with Production Technology', levels: []),
      ],
    ),



    // ── 5. SPORTS INSTITUTE ──
    FacultyData(
      name: 'Sports Institute', 
      departments: [
        DepartmentData(name: 'Sports Institute', levels: []),
      ],
    ),





    // ── 6. EDUCATION ──
    FacultyData(
      name: 'Faculty of Education',
      departments: [
        DepartmentData(
          name: 'Educational Management and Planning',
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
        DepartmentData(name: 'Adult and Non-formal Education', levels: []),
        DepartmentData(name: 'Business Education', levels: []),
        DepartmentData(name: 'Early Childhood and Primary Education', levels: []),
        DepartmentData(name: 'Educational Foundations', levels: []),
        DepartmentData(name: 'Sport and Exercise Science', levels: []),
        DepartmentData(name: 'Educational Physhology, Guidance and Counselling', levels: []),
        DepartmentData(name: 'Health Education and Promotion', levels: []),
        DepartmentData(name: 'Health Promotion, Environmental and Safety Education', levels: []),
        DepartmentData(name: 'Human Kinetics and Health Education', levels: []),
        DepartmentData(name: 'Institute of Education', levels: []),
        DepartmentData(name: 'Primary Eduction Studies', levels: []),
        DepartmentData(name: 'Science Education', levels: []),
      ],
    ),







    // ── 7. ENGINEERING ──
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
          name: 'Electrical Engineering',
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
        DepartmentData(name: 'Electronic Engineering', levels: []),
        DepartmentData(name: 'Engineering Management', levels: []),
        DepartmentData(name: 'Environmental Engineering', levels: []),
        DepartmentData(name: 'Gas Engineering', levels: []),
        DepartmentData(name: 'Mechatronic Engineering', levels: []),
        DepartmentData(name: 'Petroleum Engineering', levels: []),
        DepartmentData(name: 'Computer Engineering', levels: []),
      ],
    ),


   


    // ── 8. ALLIED HEALTH SCIENCE ──
    FacultyData(
      name: 'Allied Health Science',
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
        
      ],
    ),




    // ── 9. HUMANITIES ──
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
        DepartmentData(name: 'Comparative Literature', levels: []),
        DepartmentData(name: 'English Studies', levels: []),
        DepartmentData(name: 'Fine Arts and Designs', levels: []),
        DepartmentData(name: 'Foriegn Languages and Literature', levels: []),
        DepartmentData(name: 'Historic and Diplomatic Studies', levels: []),
        DepartmentData(name: 'Linguistics and Communication Studies', levels: []),
        DepartmentData(name: 'Music', levels: []),
        DepartmentData(name: 'Religious and Cultural Studies', levels: []),
      ],
    ),




    // ── 10. LAW ──
    FacultyData(
      name: 'Faculty of Law',
      departments: [
        DepartmentData(
          name: 'Civil Law',
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






    // ── 11. MANAGEMENT SCIENCES ──
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
        DepartmentData(name: 'Employment Relations and Human Resource Management', levels: []),
        DepartmentData(name: 'Hospitality and Tourism Management', levels: []),
        DepartmentData(name: 'Innovation and Entreprenuership', levels: []),
        DepartmentData(name: 'Insurance', levels: []),
        DepartmentData(name: 'Management', levels: []),
        DepartmentData(name: 'Marketing', levels: []),
        DepartmentData(name: 'Procurement Management', levels: []),
        DepartmentData(name: 'Project Management', levels: []),
      ],
      
    ),






    // ── 12. CLINICAL SCIENCES ──
    FacultyData(
      name: 'Clinical Sciences',
      departments: [
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
        DepartmentData(name: 'Anestheology', levels: []),
        DepartmentData(name: 'Mental Health', levels: []),
        DepartmentData(name: 'Nursing Science', levels: []),
        DepartmentData(name: 'Obstetrics and Gynaecology', levels: []),
        DepartmentData(name: 'Paediatrics and Child Health', levels: []),
        DepartmentData(name: 'Preventive and Social Medicine', levels: []),
        DepartmentData(name: 'Radiology', levels: []),
        DepartmentData(name: 'Sports Medicine', levels: []),
      ],
    ),



    // ── 13. BASIC MEDICAL SCIENCES ──
    FacultyData(
      name: 'Basic Medical Sciences',
      departments: [
        DepartmentData(name: 'Anatomical Pathology', levels: []),
        DepartmentData(name: 'Chemical Pathology', levels: []),
        DepartmentData(name: 'Haematology and Immunology', levels: []),
        DepartmentData(name: 'Human Anatomy', levels: []),
        DepartmentData(name: 'Human Physiology', levels: []),
        DepartmentData(name: 'Medical Microbiology and Parasitology', levels: []),
        DepartmentData(name: 'Pharmacology', levels: []),
      ],
    ),






    // ── 14. PHARMACEUTICAL SCIENCES ──
    FacultyData(
      name: 'Pharmaceutical Sciences',
      departments: [
       DepartmentData(name: 'Clinical Pharmacy and Management', levels: []),
       DepartmentData(name: 'Experimental Pharmacology and Toxicology', levels: []),
       DepartmentData(name: 'Natural Medicine Technology', levels: []),
       DepartmentData(name: 'Pharmaceutical and Medicinal Chemistry', levels: []),
       DepartmentData(name: 'Pharmaceutical Microbiology and Biotechnology', levels: []),
       DepartmentData(name: 'Pharmaceutics and Pharmaceutical Technology', levels: []),
       DepartmentData(name: 'Pharmacognosy and Polytotherapy', levels: []),
      ],
    ),






    // ── 15. SCIENCE ──
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
          name: 'Pure and Industrial Chemistry',
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
                      unit: 3,
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
        DepartmentData(name: 'Animal and Environmental Biology', levels: []),
        DepartmentData(name: 'Geology', levels: []),
        DepartmentData(name: 'Microbiology', levels: []),
        DepartmentData(name: 'Plant Science and Biotechnology', levels: []),
      ],
    ),







    // ── 16. SOCIAL SCIENCES ──
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
          name: 'Political Science and Administrative Studies',
          levels: [],
        ),
        DepartmentData(
          name: 'Sociology',
          levels: [],
        ),
        DepartmentData(name: 'Geography and Environmental Management', levels: []),
        DepartmentData(name: 'Library and Infomation Science', levels: []),
        DepartmentData(name: 'Public Administration', levels: []),
        DepartmentData(name: 'Social Works', levels: []),

      ],
    ),





// ── 17. COMPUTING ──
    FacultyData(
      name: 'Computing', 
      departments: [
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
        DepartmentData(name: 'Cyber Security', levels: []),
        DepartmentData(name: 'Information Technology', levels: []),
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
