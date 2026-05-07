import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(MyApp());
}

/* ================= MODEL ================= */

class Course {
  String name;
  int score;
  int unit;
  int year;
  int semester;

  Course(this.name, this.score, this.unit, this.year, this.semester);

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "score": score,
      "unit": unit,
      "year": year,
      "semester": semester,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      map["name"] ?? "",
      map["score"] ?? 0,
      map["unit"] ?? 1,
      map["year"] ?? 1,
      map["semester"] ?? 1,
    );
  }
}

/* ================= LOGIC ================= */

String getGrade(int score) {
  if (score >= 70) return "A";
  if (score >= 60) return "B";
  if (score >= 50) return "C";
  if (score >= 45) return "D";
  if (score >= 40) return "E";
  return "F";
}

double getPoint(int score) {
  if (score >= 70) return 5.0;
  if (score >= 60) return 4.0;
  if (score >= 50) return 3.0;
  if (score >= 45) return 2.0;
  return 0.0;
}

Color getColor(int score) {
  if (score >= 70) return Colors.green;
  if (score >= 50) return Colors.orange;
  return Colors.red;
}

/* ================= APP ================= */

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Course> courses = [];

  final nameController = TextEditingController();
  final scoreController = TextEditingController();
  final unitController = TextEditingController();

  int selectedYear = 1;
  int selectedSemester = 1;

  bool isDarkMode = false;

  PageController pageController = PageController();
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> exportPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "CGPA REPORT",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Overall CGPA: ${calculateCGPA().toStringAsFixed(2)}"),
              pw.SizedBox(height: 20),
              ...courses.map(
                (c) => pw.Text(
                  "${c.name} | ${c.score} | Unit ${c.unit} | Y${c.year} S${c.semester}",
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList("courses");

    if (data != null) {
      courses = data.map((e) => Course.fromMap(jsonDecode(e))).toList();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPage = getCurrentIndex();
      pageController.jumpToPage(currentPage);
    });

    setState(() {});
  }

  Future<void> saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> data = courses.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList("courses", data);
  }

  int getCurrentIndex() {
    return (selectedYear - 1) * 2 + (selectedSemester - 1);
  }

  List<Course> getSemesterCourses(int year, int semester) {
    return courses
        .where((c) => c.year == year && c.semester == semester)
        .toList();
  }

  double calculateGPA(List<Course> list) {
    if (list.isEmpty) return 0;

    double total = 0;
    int units = 0;

    for (var c in list) {
      total += getPoint(c.score) * c.unit;
      units += c.unit;
    }

    return total / units;
  }

  double calculateCGPA() {
    return calculateGPA(courses);
  }

  void addCourse() {
    String name = nameController.text.trim().toUpperCase();
    int score = int.tryParse(scoreController.text) ?? -1;
    int unit = int.tryParse(unitController.text) ?? 0;

    if (name.isEmpty || score < 0 || score > 100 || unit <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid input")));
      return;
    }

    setState(() {
      courses.add(Course(name, score, unit, selectedYear, selectedSemester));
      currentPage = getCurrentIndex();
      pageController.jumpToPage(currentPage);
    });

    saveCourses();

    nameController.clear();
    scoreController.clear();
    unitController.clear();
  }

  /* ================= DELETE WITH CONFIRM ================= */
  void deleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Course"),
        content: Text("Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                courses.remove(course); // ✅ correct removal
              });

              saveCourses();
              Navigator.pop(ctx);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void editCourse(int index, List<Course> list) {
    var c = list[index];

    nameController.text = c.name;
    scoreController.text = c.score.toString();
    unitController.text = c.unit.toString();
    selectedYear = c.year;
    selectedSemester = c.semester;

    setState(() {
      courses.remove(c);
    });
  }

  /* ================= CLEAR ALL ================= */

  void clearAllCourses() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Clear All Courses"),
        content: Text("This will delete EVERYTHING."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
          ),

          TextButton(
            onPressed: () async {
              // CLOSE DIALOG
              Navigator.of(ctx).pop();

              // CLEAR MEMORY
              courses.clear();

              // SAVE EMPTY LIST
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove("courses");

              // RESET PAGE
              currentPage = 0;

              // REFRESH UI
              setState(() {});

              // MOVE TO FIRST PAGE SAFELY
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (pageController.hasClients) {
                  pageController.jumpToPage(0);
                }
              });

              // SUCCESS MESSAGE
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("All courses cleared")));
            },
            child: Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  /* ================= INDICATOR ================= */

  Widget buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(14, (index) {
        bool active = index == currentPage;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 3),
          width: active ? 14 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
        appBar: AppBar(
          title: Text("CGPA Calcul"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () {
                setState(() => isDarkMode = !isDarkMode);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_forever),
              onPressed: clearAllCourses,
            ),
            IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: exportPDF),
          ],
        ),
        body: Column(
          children: [
            SizedBox(height: 10),

            /* INPUT */
            Padding(
              padding: EdgeInsets.all(12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<int>(
                              value: selectedYear,
                              isExpanded: true,
                              items: List.generate(7, (i) => i + 1)
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text("Year $e"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedYear = v!),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<int>(
                              value: selectedSemester,
                              isExpanded: true,
                              items: [1, 2]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text("Sem $e"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedSemester = v!),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: "Course e.g MTH101",
                          prefixIcon: Icon(Icons.book),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: scoreController,
                        decoration: InputDecoration(
                          hintText: "Score e.g 75",
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: unitController,
                        decoration: InputDecoration(
                          hintText: "Unit e.g 3",
                          prefixIcon: Icon(Icons.school),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: addCourse,
                        child: Text("Add Course"),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            buildIndicator(),

            /* SWIPE VIEW */
            Expanded(
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  setState(() => currentPage = index);
                },
                itemCount: 14,
                itemBuilder: (context, index) {
                  int year = (index ~/ 2) + 1;
                  int sem = (index % 2) + 1;

                  var list = getSemesterCourses(year, sem);
                  double gpa = calculateGPA(list);

                  return Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        /* SEMESTER GPA CARD */
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.indigo],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Year $year - Semester $sem",
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "GPA: ${gpa.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 15),

                        Expanded(
                          child: list.isEmpty
                              ? Center(child: Text("No courses"))
                              : ListView.builder(
                                  itemCount: list.length,
                                  itemBuilder: (context, i) {
                                    var c = list[i];
                                    return Card(
                                      margin: EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        title: Text(c.name),
                                        subtitle: Text(
                                          "Score ${c.score} | Unit ${c.unit}",
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: getColor(c.score),
                                          child: Text(getGrade(c.score)),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () =>
                                                  editCourse(i, list),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                final course = list[i];

                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(
                                                      "Delete Course",
                                                    ),
                                                    content: Text(
                                                      "Are you sure?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: Text("Cancel"),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          setState(() {
                                                            courses.removeWhere(
                                                              (c) =>
                                                                  c.name ==
                                                                      course
                                                                          .name &&
                                                                  c.score ==
                                                                      course
                                                                          .score &&
                                                                  c.unit ==
                                                                      course
                                                                          .unit &&
                                                                  c.year ==
                                                                      course
                                                                          .year &&
                                                                  c.semester ==
                                                                      course
                                                                          .semester,
                                                            );
                                                          });

                                                          await saveCourses();

                                                          // 🔥 FORCE PAGE REFRESH (this is the missing part)
                                                          setState(() {
                                                            currentPage =
                                                                getCurrentIndex();
                                                          });
                                                          pageController
                                                              .jumpToPage(
                                                                currentPage,
                                                              );

                                                          Navigator.pop(ctx);
                                                        },
                                                        child: Text(
                                                          "Delete",
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            /* CGPA BOTTOM CARD */
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text("Overall CGPA", style: TextStyle(color: Colors.white70)),
                  Text(
                    calculateCGPA().toStringAsFixed(2),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
