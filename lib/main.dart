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
  if (score >= 40) return 1.0;
  return 0.0;
}

Color getColor(int score) {
  if (score >= 70) return Colors.green;
  if (score >= 50) return Colors.blue;
  if (score >= 40) return Colors.orange;
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

  final PageController pageController = PageController();

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  @override
  void dispose() {
    nameController.dispose();
    scoreController.dispose();
    unitController.dispose();
    pageController.dispose();
    super.dispose();
  }

  /* ================= STORAGE ================= */

  Future<void> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();

    List<String>? data = prefs.getStringList("courses");

    if (data != null) {
      courses = data.map((e) => Course.fromMap(jsonDecode(e))).toList();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(currentPage);
      }
    });

    setState(() {});
  }

  Future<void> saveCourses() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> data = courses.map((e) => jsonEncode(e.toMap())).toList();

    await prefs.setStringList("courses", data);
  }

  /* ================= PDF ================= */

  Future<void> exportPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "CGPA REPORT",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 20),

                pw.Text(
                  "Overall CGPA: ${calculateCGPA().toStringAsFixed(2)}",
                  style: pw.TextStyle(fontSize: 18),
                ),

                pw.SizedBox(height: 25),

                ...courses.map(
                  (c) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      "${c.name}   |   Score ${c.score}   |   Unit ${c.unit}   |   Year ${c.year} Semester ${c.semester}",
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /* ================= HELPERS ================= */

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

  /* ================= ADD COURSE ================= */

  void addCourse() {
    String name = nameController.text.trim().toUpperCase();

    int score = int.tryParse(scoreController.text) ?? -1;

    int unit = int.tryParse(unitController.text) ?? 0;

    if (name.isEmpty || score < 0 || score > 100 || unit <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid Input")));
      return;
    }

    setState(() {
      courses.add(Course(name, score, unit, selectedYear, selectedSemester));

      currentPage = getCurrentIndex();
    });

    pageController.jumpToPage(currentPage);

    saveCourses();

    nameController.clear();
    scoreController.clear();
    unitController.clear();
  }

  /* ================= EDIT ================= */

  void editCourse(Course course) {
    nameController.text = course.name;
    scoreController.text = course.score.toString();
    unitController.text = course.unit.toString();

    selectedYear = course.year;
    selectedSemester = course.semester;

    setState(() {
      courses.remove(course);
      currentPage = getCurrentIndex();
    });

    pageController.jumpToPage(currentPage);
  }

  /* ================= DELETE ================= */

  /* ================= DELETE COURSE ================= */

  void deleteCourse(Course course) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text("Delete Course"),

          content: Text("Are you sure you want to delete this course?"),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
              },
              child: Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

              onPressed: () {
                Navigator.of(ctx).pop(true);
              },

              child: Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        courses.remove(course);
      });

      await saveCourses();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Course deleted")));
    }
  }

  /* ================= CLEAR ALL ================= */

  void clearAllCourses() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text("Clear All Courses"),

          content: Text("This will delete ALL saved courses permanently."),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
              },
              child: Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

              onPressed: () {
                Navigator.of(ctx).pop(true);
              },

              child: Text("Clear All"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        courses.clear();
        currentPage = 0;
      });

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove("courses");

      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("All courses cleared")));
    }
  }

  /* ================= PAGE INDICATOR ================= */

  Widget buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(14, (index) {
        bool active = index == currentPage;

        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(20),
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
        backgroundColor: isDarkMode ? Colors.black : Colors.grey.shade100,

        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text("CGPA Calculator"),

          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),

            IconButton(
              icon: Icon(Icons.delete_forever),
              onPressed: clearAllCourses,
            ),

            IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: exportPDF),
          ],
        ),

        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35),
              child: Column(
                children: [
                  SizedBox(height: 18),

                  /* INPUT CARD */
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),

                    child: Card(
                      elevation: 5,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Padding(
                        padding: EdgeInsets.all(18),

                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: selectedYear,

                                    decoration: InputDecoration(
                                      labelText: "Year",

                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),

                                    items: List.generate(7, (i) => i + 1)
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text("Year $e"),
                                          ),
                                        )
                                        .toList(),

                                    onChanged: (v) {
                                      setState(() {
                                        selectedYear = v!;
                                      });
                                    },
                                  ),
                                ),

                                SizedBox(width: 15),

                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: selectedSemester,

                                    decoration: InputDecoration(
                                      labelText: "Semester",

                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),

                                    items: [1, 2]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text("Sem $e"),
                                          ),
                                        )
                                        .toList(),

                                    onChanged: (v) {
                                      setState(() {
                                        selectedSemester = v!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 18),

                            TextField(
                              controller: nameController,

                              decoration: InputDecoration(
                                hintText: "Course e.g MTH101",

                                prefixIcon: Icon(Icons.book),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            SizedBox(height: 15),

                            TextField(
                              controller: scoreController,

                              keyboardType: TextInputType.number,

                              decoration: InputDecoration(
                                hintText: "Score e.g 75",

                                prefixIcon: Icon(Icons.numbers),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            SizedBox(height: 15),

                            TextField(
                              controller: unitController,

                              keyboardType: TextInputType.number,

                              decoration: InputDecoration(
                                hintText: "Unit e.g 3",

                                prefixIcon: Icon(Icons.school),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 52,

                              child: ElevatedButton(
                                onPressed: addCourse,

                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),

                                child: Text(
                                  "Add Course",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 18),

                  buildIndicator(),

                  SizedBox(height: 18),

                  /* PAGE VIEW */
                  SizedBox(
                    height: 540,

                    child: PageView.builder(
                      controller: pageController,

                      itemCount: 14,

                      onPageChanged: (index) {
                        setState(() {
                          currentPage = index;
                        });
                      },

                      itemBuilder: (context, index) {
                        int year = (index ~/ 2) + 1;
                        int sem = (index % 2) + 1;

                        var list = getSemesterCourses(year, sem);

                        double gpa = calculateGPA(list);

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),

                          child: Column(
                            children: [
                              /* GPA CARD */
                              Container(
                                width: double.infinity,

                                padding: EdgeInsets.all(24),

                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue, Colors.indigo],
                                  ),

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Column(
                                  children: [
                                    Text(
                                      "Year $year • Semester $sem",

                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                      ),
                                    ),

                                    SizedBox(height: 10),

                                    Text(
                                      "GPA: ${gpa.toStringAsFixed(2)}",

                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 18),

                              /* COURSE LIST */
                              Expanded(
                                child: list.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No courses added",
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.only(bottom: 20),

                                        itemCount: list.length,

                                        itemBuilder: (context, i) {
                                          var c = list[i];

                                          return Card(
                                            elevation: 3,

                                            margin: EdgeInsets.only(bottom: 14),

                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),

                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),

                                              child: ListTile(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6,
                                                    ),

                                                leading: CircleAvatar(
                                                  radius: 24,

                                                  backgroundColor: getColor(
                                                    c.score,
                                                  ),

                                                  child: Text(
                                                    getGrade(c.score),

                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),

                                                title: Text(
                                                  c.name,

                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),

                                                subtitle: Padding(
                                                  padding: EdgeInsets.only(
                                                    top: 6,
                                                  ),

                                                  child: Text(
                                                    "Score ${c.score} • Unit ${c.unit}",
                                                  ),
                                                ),

                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,

                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.edit,
                                                        color: Colors.blue,
                                                      ),

                                                      onPressed: () {
                                                        editCourse(c);
                                                      },
                                                    ),

                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                      ),

                                                      onPressed: () {
                                                        deleteCourse(c);
                                                      },
                                                    ),
                                                  ],
                                                ),
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

                  SizedBox(height: 25),

                  /* CGPA CARD */
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),

                    child: Container(
                      width: double.infinity,

                      margin: EdgeInsets.only(bottom: 20),

                      padding: EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 20,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.black87,

                        borderRadius: BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Column(
                        children: [
                          Text(
                            "Overall CGPA",

                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),

                          SizedBox(height: 12),

                          Text(
                            calculateCGPA().toStringAsFixed(2),

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
