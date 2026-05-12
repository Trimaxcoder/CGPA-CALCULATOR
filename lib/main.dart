import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

void main() {
  runApp(MyApp());
}

/* ================= MODEL ================= */

class Course {
  String id;
  String name;
  int score;
  int unit;
  int year;
  int semester;

  Course(this.name, this.score, this.unit, this.year, this.semester)
      : id = DateTime.now().millisecondsSinceEpoch.toString() +
            name.hashCode.toString();

  Course.withId(
      this.id, this.name, this.score, this.unit, this.year, this.semester);

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "score": score,
      "unit": unit,
      "year": year,
      "semester": semester,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course.withId(
      map["id"] ??
          DateTime.now().millisecondsSinceEpoch.toString() +
              (map["name"] ?? "").hashCode.toString(),
      map["name"] ?? "",
      map["score"] ?? 0,
      map["unit"] ?? 1,
      map["year"] ?? 1,
      map["semester"] ?? 1,
    );
  }
}

/* ================= STUDENT PROFILE MODEL ================= */

class StudentProfile {
  String name;
  String matricNumber;
  String department;
  String faculty;

  StudentProfile({
    this.name = "",
    this.matricNumber = "",
    this.department = "",
    this.faculty = "",
  });

  Map<String, dynamic> toMap() => {
        "name": name,
        "matricNumber": matricNumber,
        "department": department,
        "faculty": faculty,
      };

  factory StudentProfile.fromMap(Map<String, dynamic> map) => StudentProfile(
        name: map["name"] ?? "",
        matricNumber: map["matricNumber"] ?? "",
        department: map["department"] ?? "",
        faculty: map["faculty"] ?? "",
      );
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

String getDegreeClass(double cgpa) {
  if (cgpa >= 4.50) return "First Class";
  if (cgpa >= 3.50) return "Second Class Upper";
  if (cgpa >= 2.40) return "Second Class Lower";
  if (cgpa >= 1.50) return "Third Class";
  if (cgpa > 0) return "Pass";
  return "—";
}

Color getDegreeColor(double cgpa) {
  if (cgpa >= 4.50) return Colors.green.shade700;
  if (cgpa >= 3.50) return Colors.blue.shade700;
  if (cgpa >= 2.40) return Colors.orange.shade700;
  if (cgpa >= 1.50) return Colors.purple.shade700;
  if (cgpa > 0) return Colors.grey.shade700;
  return Colors.grey;
}

/* ================= APP ================= */

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}

/* ================= SPLASH SCREEN ================= */

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.indigo.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school, size: 60, color: Colors.white),
                ),
                SizedBox(height: 30),
                Text("CGPA Calculator",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                SizedBox(height: 10),
                Text("Track your academic performance",
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
                SizedBox(height: 60),
                Text("Developed by TRIMAX",
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 60),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= HOME SCREEN ================= */

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Course> courses = [];
  StudentProfile profile = StudentProfile();

  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final scoreController = TextEditingController();
  final unitController = TextEditingController();

  int selectedYear = 1;
  int selectedSemester = 1;

  bool isDarkMode = false;
  bool isSearching = false;
  String searchQuery = "";
  final searchController = TextEditingController();

  final PageController pageController = PageController();
  int currentPage = 0;

  // What-if simulator
  List<Course> whatIfCourses = [];
  bool isWhatIfMode = false;

  // Share key
  final GlobalKey shareKey = GlobalKey();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    nameController.dispose();
    scoreController.dispose();
    unitController.dispose();
    searchController.dispose();
    pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /* ================= STORAGE ================= */

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList("courses");
    if (data != null) {
      courses = data.map((e) => Course.fromMap(jsonDecode(e))).toList();
    }
    String? profileData = prefs.getString("profile");
    if (profileData != null) {
      profile = StudentProfile.fromMap(jsonDecode(profileData));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) pageController.jumpToPage(currentPage);
    });
    setState(() {});
  }

  Future<void> saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> data = courses.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList("courses", data);
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("profile", jsonEncode(profile.toMap()));
  }

  /* ================= HELPERS ================= */

  int getCurrentIndex() =>
      (selectedYear - 1) * 2 + (selectedSemester - 1);

  List<Course> getSemesterCourses(int year, int semester) =>
      courses.where((c) => c.year == year && c.semester == semester).toList();

  List<Course> getSearchResults() {
    if (searchQuery.isEmpty) return [];
    return courses
        .where((c) =>
            c.name.toLowerCase().contains(searchQuery.toLowerCase()))
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

  double calculateCGPA() => calculateGPA(courses);

  double calculateWhatIfCGPA() =>
      calculateGPA([...courses, ...whatIfCourses]);

  int getTotalUnits() =>
      courses.fold(0, (sum, c) => sum + c.unit);

  int getTotalCourses() => courses.length;

  String getBestSemester() {
    double best = 0;
    String label = "—";
    for (int y = 1; y <= 7; y++) {
      for (int s = 1; s <= 2; s++) {
        var list = getSemesterCourses(y, s);
        if (list.isNotEmpty) {
          double gpa = calculateGPA(list);
          if (gpa > best) {
            best = gpa;
            label = "Year $y Sem $s (${gpa.toStringAsFixed(2)})";
          }
        }
      }
    }
    return label;
  }

  Course? getHighestCourse() {
    if (courses.isEmpty) return null;
    return courses.reduce((a, b) => a.score > b.score ? a : b);
  }

  /* ================= WHAT-IF SIMULATOR ================= */

  void showWhatIfSimulator() {
    List<Map<String, TextEditingController>> controllers = [];
    for (int i = 0; i < 3; i++) {
      controllers.add({
        "name": TextEditingController(),
        "score": TextEditingController(),
        "unit": TextEditingController(),
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          List<Course> tempCourses = [];
          for (var c in controllers) {
            int score = int.tryParse(c["score"]!.text) ?? -1;
            int unit = int.tryParse(c["unit"]!.text) ?? 0;
            String name = c["name"]!.text.trim();
            if (name.isNotEmpty && score >= 0 && score <= 100 && unit > 0) {
              tempCourses
                  .add(Course(name.toUpperCase(), score, unit, 1, 1));
            }
          }
          double newCGPA = calculateGPA([...courses, ...tempCourses]);

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.science, color: Colors.blue),
                      SizedBox(width: 10),
                      Text("What-If Simulator",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue, Colors.indigo]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Current CGPA",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(calculateCGPA().toStringAsFixed(2),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      Icon(Icons.arrow_forward,
                          color: Colors.white70, size: 20),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Projected CGPA",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                                tempCourses.isEmpty
                                    ? "—"
                                    : newCGPA.toStringAsFixed(2),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Text("Add hypothetical courses:",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                      SizedBox(height: 12),
                      ...controllers.asMap().entries.map((entry) {
                        int i = entry.key;
                        var c = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Row(children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: c["name"],
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  hintText: "Course ${i + 1}",
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: c["score"],
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  hintText: "Score",
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: c["unit"],
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  hintText: "Unit",
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ================= TARGET CGPA CALCULATOR ================= */

  void showTargetCalculator() {
    final targetController = TextEditingController();
    final remainingUnitsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String result = "";
          double target = double.tryParse(targetController.text) ?? 0;
          int remUnits =
              int.tryParse(remainingUnitsController.text) ?? 0;

          if (target > 0 && remUnits > 0 && courses.isNotEmpty) {
            int currentUnits = getTotalUnits();
            double currentTotal = courses.fold(
                0.0, (sum, c) => sum + getPoint(c.score) * c.unit);
            double neededPointTotal =
                target * (currentUnits + remUnits) - currentTotal;
            double neededAvg = neededPointTotal / remUnits;

            if (neededAvg <= 0) {
              result = "You've already achieved this CGPA! 🎉";
            } else if (neededAvg > 5.0) {
              result =
                  "Not achievable with $remUnits units remaining. Try a lower target or more units.";
            } else {
              // Reverse engineer score range
              String scoreRange = neededAvg >= 4.0
                  ? "60–69 (B) to 70+ (A)"
                  : neededAvg >= 3.0
                      ? "50–59 (C) to 60+ (B)"
                      : neededAvg >= 2.0
                          ? "45–49 (D) to 50+ (C)"
                          : "40–44 (E)";
              result =
                  "You need an average GP of ${neededAvg.toStringAsFixed(2)} per unit\n(≈ $scoreRange in remaining courses)";
            }
          }

          return AlertDialog(
            backgroundColor:
                isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.track_changes, color: Colors.blue),
              SizedBox(width: 8),
              Text("Target CGPA",
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: targetController,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: "Desired CGPA (e.g. 4.50)",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: remainingUnitsController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: "Remaining credit units",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (result.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(result,
                        style: TextStyle(
                            fontSize: 14, color: Colors.blue.shade800)),
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Close")),
            ],
          );
        },
      ),
    );
  }

  /* ================= STUDENT PROFILE EDITOR ================= */

  void showProfileEditor() {
    final nameCtrl = TextEditingController(text: profile.name);
    final matricCtrl = TextEditingController(text: profile.matricNumber);
    final deptCtrl = TextEditingController(text: profile.department);
    final facCtrl = TextEditingController(text: profile.faculty);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.person, color: Colors.blue),
          SizedBox(width: 8),
          Text("Student Profile",
              style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _profileField(nameCtrl, "Full Name", Icons.person_outline),
            SizedBox(height: 12),
            _profileField(
                matricCtrl, "Matric Number", Icons.badge_outlined),
            SizedBox(height: 12),
            _profileField(
                deptCtrl, "Department", Icons.school_outlined),
            SizedBox(height: 12),
            _profileField(facCtrl, "Faculty", Icons.account_balance_outlined),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                profile = StudentProfile(
                  name: nameCtrl.text.trim(),
                  matricNumber: matricCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  faculty: facCtrl.text.trim(),
                );
              });
              saveProfile();
              Navigator.pop(ctx);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _profileField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /* ================= PDF ================= */

  Future<void> exportPDF() async {
    final pdf = pw.Document();

    List<List<String>> tableData = [];
    for (int y = 1; y <= 7; y++) {
      for (int s = 1; s <= 2; s++) {
        var list = getSemesterCourses(y, s);
        if (list.isEmpty) continue;
        for (var c in list) {
          tableData.add([
            c.name,
            c.score.toString(),
            getGrade(c.score),
            getPoint(c.score).toStringAsFixed(1),
            c.unit.toString(),
            "Year $y Sem $s",
          ]);
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (context) => [
          // Header
          pw.Container(
            padding: pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo800,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("ACADEMIC TRANSCRIPT",
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 10),
                if (profile.name.isNotEmpty)
                  pw.Text("Name: ${profile.name}",
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                if (profile.matricNumber.isNotEmpty)
                  pw.Text("Matric No: ${profile.matricNumber}",
                      style: pw.TextStyle(color: PdfColors.white)),
                if (profile.department.isNotEmpty)
                  pw.Text("Department: ${profile.department}",
                      style: pw.TextStyle(color: PdfColors.white)),
                if (profile.faculty.isNotEmpty)
                  pw.Text("Faculty: ${profile.faculty}",
                      style: pw.TextStyle(color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // CGPA Summary
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo200),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Overall CGPA",
                          style: pw.TextStyle(
                              color: PdfColors.grey700, fontSize: 12)),
                      pw.Text(calculateCGPA().toStringAsFixed(2),
                          style: pw.TextStyle(
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold)),
                    ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Class of Degree",
                          style: pw.TextStyle(
                              color: PdfColors.grey700, fontSize: 12)),
                      pw.Text(getDegreeClass(calculateCGPA()),
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo800)),
                      pw.Text(
                          "Total Units: ${getTotalUnits()}  |  Courses: ${getTotalCourses()}",
                          style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey600)),
                    ]),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Course table
          if (tableData.isNotEmpty) ...[
            pw.Text("Course Details",
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1),
                5: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColors.indigo800),
                  children: ["Course", "Score", "Grade", "GP", "Units", "Period"]
                      .map((h) => pw.Padding(
                            padding: pw.EdgeInsets.all(8),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11)),
                          ))
                      .toList(),
                ),
                ...tableData.asMap().entries.map((entry) {
                  bool isEven = entry.key % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isEven
                            ? PdfColors.grey50
                            : PdfColors.white),
                    children: entry.value
                        .map((cell) => pw.Padding(
                              padding: pw.EdgeInsets.all(7),
                              child: pw.Text(cell,
                                  style: pw.TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  );
                }).toList(),
              ],
            ),
          ],

          pw.SizedBox(height: 20),
          // Per-semester GPA
          pw.Text("Semester GPA Summary",
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          ...() {
            List<pw.Widget> rows = [];
            for (int y = 1; y <= 7; y++) {
              for (int s = 1; s <= 2; s++) {
                var list = getSemesterCourses(y, s);
                if (list.isEmpty) continue;
                double gpa = calculateGPA(list);
                int units =
                    list.fold(0, (sum, c) => sum + c.unit);
                rows.add(pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Year $y, Semester $s"),
                        pw.Text(
                            "GPA: ${gpa.toStringAsFixed(2)}   Units: $units",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold)),
                      ]),
                ));
              }
            }
            return rows;
          }(),

          pw.SizedBox(height: 30),
          pw.Text(
              "Generated by CGPA Calculator — TRIMAX",
              style: pw.TextStyle(
                  color: PdfColors.grey500, fontSize: 10)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /* ================= SHARE AS IMAGE ================= */

  Future<void> shareAsImage() async {
    try {
      RenderRepaintBoundary boundary = shareKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cgpa_result.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)],
          text:
              'My CGPA: ${calculateCGPA().toStringAsFixed(2)} — ${getDegreeClass(calculateCGPA())} 🎓');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not share image")));
    }
  }

  /* ================= ADD COURSE ================= */

  void addCourse() {
    if (!_formKey.currentState!.validate()) return;

    String name = nameController.text.trim().toUpperCase();
    int score = int.parse(scoreController.text);
    int unit = int.parse(unitController.text);

    HapticFeedback.lightImpact();

    setState(() {
      courses.add(Course(name, score, unit, selectedYear, selectedSemester));
      currentPage = getCurrentIndex();
    });

    pageController.jumpToPage(currentPage);
    saveCourses();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Course added ✓")));

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
      courses.removeWhere((c) => c.id == course.id);
      currentPage = getCurrentIndex();
    });

    saveCourses();
    pageController.jumpToPage(currentPage);

    // Switch to Add tab
    _tabController.animateTo(0);
  }

  /* ================= DELETE COURSE ================= */

  void deleteCourse(Course course) async {
    HapticFeedback.mediumImpact();
    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Course",
            style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black)),
        content: Text("Delete ${course.name}?",
            style: TextStyle(
                color:
                    isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => courses.removeWhere((c) => c.id == course.id));
      await saveCourses();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Course deleted")));
    }
  }

  /* ================= CLEAR ALL ================= */

  void clearAllCourses() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear All Courses",
            style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black)),
        content: Text("This will delete ALL saved courses permanently.",
            style: TextStyle(
                color:
                    isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        courses.clear();
        currentPage = 0;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("courses");
      if (pageController.hasClients) pageController.jumpToPage(0);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("All courses cleared")));
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
          margin: EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  /* ================= GPA CHART ================= */

  Widget buildGPAChart() {
    List<FlSpot> spots = [];
    List<String> labels = [];
    int idx = 0;

    for (int y = 1; y <= 7; y++) {
      for (int s = 1; s <= 2; s++) {
        var list = getSemesterCourses(y, s);
        if (list.isNotEmpty) {
          spots.add(FlSpot(idx.toDouble(), calculateGPA(list)));
          labels.add("Y${y}S$s");
          idx++;
        }
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey.shade300),
            SizedBox(height: 12),
            Text("Add courses to see your GPA trend",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("GPA Per Semester",
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 5,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        int i = v.toInt();
                        if (i < 0 || i >= labels.length)
                          return SizedBox();
                        return Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style: TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.blue,
                        strokeColor: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          // Degree class thresholds legend
          Wrap(spacing: 16, children: [
            _legendItem("First Class", "≥4.50", Colors.green),
            _legendItem("2nd Upper", "≥3.50", Colors.blue),
            _legendItem("2nd Lower", "≥2.40", Colors.orange),
          ]),
        ],
      ),
    );
  }

  Widget _legendItem(String label, String threshold, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      SizedBox(width: 4),
      Text("$label $threshold",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    ]);
  }

  /* ================= SUMMARY STATS ================= */

  Widget buildSummaryStats() {
    double cgpa = calculateCGPA();
    Course? best = getHighestCourse();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        // Shareable CGPA card
        RepaintBoundary(
          key: shareKey,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.black, Colors.indigo.shade800]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              if (profile.name.isNotEmpty) ...[
                Text(profile.name.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 1.2)),
                if (profile.department.isNotEmpty)
                  Text(profile.department,
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                SizedBox(height: 16),
              ],
              Text("CGPA",
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text(cgpa.toStringAsFixed(2),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: getDegreeColor(cgpa).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: getDegreeColor(cgpa).withOpacity(0.5)),
                ),
                child: Text(getDegreeClass(cgpa),
                    style: TextStyle(
                        color: getDegreeColor(cgpa),
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statPill("Courses", "${getTotalCourses()}"),
                  _statPill("Units", "${getTotalUnits()}"),
                  _statPill("GPA/5.0",
                      "${(cgpa * 20).toStringAsFixed(0)}%"),
                ],
              ),
            ]),
          ),
        ),

        SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: shareAsImage,
              icon: Icon(Icons.share),
              label: Text("Share Result"),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: exportPDF,
              icon: Icon(Icons.picture_as_pdf),
              label: Text("Export PDF"),
            ),
          ),
        ]),

        SizedBox(height: 20),
        // Stats grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _statCard("Best Semester", getBestSemester(),
                Icons.emoji_events, Colors.amber),
            _statCard(
                "Top Course",
                best != null
                    ? "${best.name}\n(${best.score})"
                    : "—",
                Icons.star,
                Colors.green),
            _statCard("Total Units", "${getTotalUnits()} credits",
                Icons.library_books, Colors.blue),
            _statCard("Courses Taken", "${getTotalCourses()}",
                Icons.menu_book, Colors.purple),
          ],
        ),
      ]),
    );
  }

  Widget _statPill(String label, String value) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
      Text(label,
          style: TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Text(title,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ],
      ),
    );
  }

  /* ================= COURSES TAB ================= */

  Widget buildCoursesTab() {
    return Column(children: [
      // Search bar
      Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: TextField(
          controller: searchController,
          onChanged: (v) => setState(() => searchQuery = v),
          decoration: InputDecoration(
            hintText: "Search courses...",
            prefixIcon: Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () => setState(() {
                      searchQuery = "";
                      searchController.clear();
                    }),
                  )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor:
                isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          ),
        ),
      ),

      if (searchQuery.isNotEmpty) ...[
        Expanded(
          child: Builder(builder: (_) {
            var results = getSearchResults();
            if (results.isEmpty) {
              return Center(
                  child: Text("No courses found",
                      style: TextStyle(color: Colors.grey)));
            }
            return ListView.builder(
              padding: EdgeInsets.all(14),
              itemCount: results.length,
              itemBuilder: (_, i) => _buildCourseCard(results[i]),
            );
          }),
        ),
      ] else ...[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: buildIndicator(),
        ),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            itemCount: 14,
            onPageChanged: (index) =>
                setState(() => currentPage = index),
            itemBuilder: (context, index) {
              int year = (index ~/ 2) + 1;
              int sem = (index % 2) + 1;
              var list = getSemesterCourses(year, sem);
              double gpa = calculateGPA(list);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.blue, Colors.indigo]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text("Year $year • Semester $sem",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13)),
                            SizedBox(height: 4),
                            Text("GPA: ${gpa.toStringAsFixed(2)}",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                                "${list.length} course${list.length != 1 ? 's' : ''}",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                            Text(
                                "${list.fold(0, (s, c) => s + c.unit)} units",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Color(0xFF1E1E1E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: list.isEmpty
                          ? Center(
                              child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                SizedBox(height: 10),
                                Text("No courses yet",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 15)),
                              ],
                            ))
                          : ListView.builder(
                              padding: EdgeInsets.all(10),
                              itemCount: list.length,
                              itemBuilder: (_, i) =>
                                  _buildDismissibleCard(list[i]),
                            ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ],
    ]);
  }

  Widget _buildDismissibleCard(Course c) {
    return Dismissible(
      key: Key(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Delete ${c.name}?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("Delete"),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      onDismissed: (_) {
        setState(() => courses.removeWhere((x) => x.id == c.id));
        saveCourses();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("${c.name} deleted")));
      },
      child: _buildCourseCard(c),
    );
  }

  Widget _buildCourseCard(Course c) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: getColor(c.score),
          child: Text(getGrade(c.score),
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(c.name,
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
              "Score ${c.score} • Unit ${c.unit} • GP ${getPoint(c.score).toStringAsFixed(1)}"),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => editCourse(c),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => deleteCourse(c),
          ),
        ]),
      ),
    );
  }

  /* ================= ADD COURSE TAB ================= */

  Widget buildAddTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(children: [
          // Profile banner
          if (profile.name.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 18,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (profile.department.isNotEmpty)
                        Text(profile.department,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ]),
              ]),
            ),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: InputDecoration(
                        labelText: "Year",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: List.generate(7, (i) => i + 1)
                          .map((e) => DropdownMenuItem(
                              value: e, child: Text("Year $e")))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedYear = v!),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedSemester,
                      decoration: InputDecoration(
                        labelText: "Semester",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [1, 2]
                          .map((e) => DropdownMenuItem(
                              value: e, child: Text("Sem $e")))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedSemester = v!),
                    ),
                  ),
                ]),
                SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "Course Code e.g MTH101",
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return "Enter a course code";
                    return null;
                  },
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: scoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Score (0–100)",
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter a score";
                    int? s = int.tryParse(v);
                    if (s == null || s < 0 || s > 100)
                      return "Score must be 0–100";
                    return null;
                  },
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: unitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Credit Unit (e.g 3)",
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter credit units";
                    int? u = int.tryParse(v);
                    if (u == null || u <= 0)
                      return "Units must be 1 or more";
                    return null;
                  },
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: addCourse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text("Add Course",
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ]),
            ),
          ),

          SizedBox(height: 16),

          // Tools row
          Row(children: [
            Expanded(
              child: _toolButton(
                icon: Icons.science,
                label: "What-If",
                color: Colors.purple,
                onTap: showWhatIfSimulator,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _toolButton(
                icon: Icons.track_changes,
                label: "Target",
                color: Colors.teal,
                onTap: showTargetCalculator,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _toolButton(
                icon: Icons.person,
                label: "Profile",
                color: Colors.orange,
                onTap: showProfileEditor,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _toolButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /* ================= MAIN BUILD ================= */

  @override
  Widget build(BuildContext context) {
    double cgpa = calculateCGPA();

    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor:
            isDarkMode ? Colors.black : Colors.blue.shade50,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text("CGPA Calculator"),
          actions: [
            IconButton(
              icon: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () =>
                  setState(() => isDarkMode = !isDarkMode),
            ),
            IconButton(
                icon: Icon(Icons.delete_forever),
                onPressed: clearAllCourses),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: Icon(Icons.add_circle_outline), text: "Add"),
              Tab(icon: Icon(Icons.list_alt), text: "Courses"),
              Tab(icon: Icon(Icons.show_chart), text: "Chart"),
              Tab(icon: Icon(Icons.dashboard), text: "Summary"),
            ],
          ),
        ),

        body: SafeArea(
          child: Column(children: [
            // CGPA bar
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.black87, Colors.indigo.shade900]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Overall CGPA",
                          style: TextStyle(
                              color: Colors.white54, fontSize: 11)),
                      Text(cgpa.toStringAsFixed(2),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: getDegreeColor(cgpa).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: getDegreeColor(cgpa).withOpacity(0.5)),
                    ),
                    child: Text(getDegreeClass(cgpa),
                        style: TextStyle(
                            color: getDegreeColor(cgpa),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  buildAddTab(),
                  buildCoursesTab(),
                  buildGPAChart(),
                  buildSummaryStats(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}