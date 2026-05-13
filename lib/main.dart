// main.dart
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

import 'grading_model.dart';
import 'uniport_courses.dart';

void main() => runApp(const MyApp());

// ══════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════

class Course {
  String id;
  String name;
  String title; // course title from JSON, empty if manual
  int score;
  int unit;
  int year;
  int semester;

  Course(this.name, this.title, this.score, this.unit, this.year, this.semester)
    : id = '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode}';

  Course.withId(
    this.id,
    this.name,
    this.title,
    this.score,
    this.unit,
    this.year,
    this.semester,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'title': title,
    'score': score,
    'unit': unit,
    'year': year,
    'semester': semester,
  };

  factory Course.fromMap(Map<String, dynamic> m) => Course.withId(
    m['id'] ??
        '${DateTime.now().microsecondsSinceEpoch}_${(m['name'] ?? '').hashCode}',
    m['name'] ?? '',
    m['title'] ?? '',
    m['score'] ?? 0,
    m['unit'] ?? 1,
    m['year'] ?? 1,
    m['semester'] ?? 1,
  );
}

class StudentProfile {
  String name, matricNumber, department, faculty, email;
  StudentProfile({
    this.name = '',
    this.matricNumber = '',
    this.department = '',
    this.faculty = '',
    this.email = '',
  });
  bool get isEmpty => name.isEmpty;
  Map<String, dynamic> toMap() => {
    'name': name,
    'matricNumber': matricNumber,
    'department': department,
    'faculty': faculty,
    'email': email,
  };
  factory StudentProfile.fromMap(Map<String, dynamic> m) => StudentProfile(
    name: m['name'] ?? '',
    matricNumber: m['matricNumber'] ?? '',
    department: m['department'] ?? '',
    faculty: m['faculty'] ?? '',
    email: m['email'] ?? '',
  );
}

// ══════════════════════════════════════════════════════════
//  HELPERS (use GradingModel, not hard-coded)
// ══════════════════════════════════════════════════════════

Color scoreColor(int s) {
  if (s >= 70) return Colors.green;
  if (s >= 50) return Colors.blue;
  if (s >= 40) return Colors.orange;
  return Colors.red;
}

String getDegreeClass(double cgpa, double max) {
  final pct = max > 0 ? cgpa / max : 0;
  if (pct >= 0.90) return 'First Class';
  if (pct >= 0.70) return 'Second Class Upper';
  if (pct >= 0.48) return 'Second Class Lower';
  if (pct >= 0.30) return 'Third Class';
  if (cgpa > 0) return 'Pass';
  return '—';
}

Color degreeColor(double cgpa, double max) {
  final pct = max > 0 ? cgpa / max : 0;
  if (pct >= 0.90) return Colors.green.shade700;
  if (pct >= 0.70) return Colors.blue.shade700;
  if (pct >= 0.48) return Colors.orange.shade700;
  if (pct >= 0.30) return Colors.purple.shade700;
  if (cgpa > 0) return Colors.grey.shade700;
  return Colors.grey;
}

bool isValidEmail(String e) =>
    RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(e);

// ══════════════════════════════════════════════════════════
//  APP ROOT
// ══════════════════════════════════════════════════════════

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: false),
    home: const SplashScreen(),
  );
}

// ══════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ══════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final has = (prefs.getString('profile') ?? '').isNotEmpty;
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(_fade_(has ? const HomeScreen() : const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _gradientBox(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconCircle(Icons.school, 110, 60),
              const SizedBox(height: 28),
              const Text(
                'CGPA Calculator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your academic performance',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 60),
              const Text(
                'Developed by TRIMAX',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 60),
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  LOGIN / REGISTER SCREEN
// ══════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _fk = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _matricC = TextEditingController();
  final _deptC = TextEditingController();
  final _facC = TextEditingController();

  // Faculty / Department from university data
  String? _selFaculty;
  String? _selDept;
  bool _loading = false;

  List<String> get _faculties => getFaculties();
  List<String> get _depts =>
      _selFaculty != null ? getDepartments(_selFaculty!) : [];

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _matricC.dispose();
    _deptC.dispose();
    _facC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    final profile = StudentProfile(
      name: _nameC.text.trim(),
      email: _emailC.text.trim(),
      matricNumber: _matricC.text.trim(),
      faculty: _selFaculty ?? _facC.text.trim(),
      department: _selDept ?? _deptC.text.trim(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toMap()));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(_fade_(const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _gradientBox(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
          child: Form(
            key: _fk,
            child: Column(
              children: [
                _iconCircle(Icons.school, 76, 38),
                const SizedBox(height: 16),
                const Text(
                  'Create Your Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your details to get started',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 32),

                _loginField(
                  _nameC,
                  'Full Name',
                  Icons.person_outline,
                  cap: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Full name is required';
                    if (v.trim().split(' ').length < 2)
                      return 'Enter first and last name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _loginField(
                  _emailC,
                  'Email Address',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!isValidEmail(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _loginField(
                  _matricC,
                  'Matric Number',
                  Icons.badge_outlined,
                  cap: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Matric number is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Faculty dropdown
                _dropdownField(
                  label: 'Faculty',
                  icon: Icons.account_balance_outlined,
                  value: _selFaculty,
                  items: _faculties,
                  onChanged: (v) => setState(() {
                    _selFaculty = v;
                    _selDept = null;
                  }),
                  validator: (v) => v == null ? 'Select your faculty' : null,
                ),
                const SizedBox(height: 14),

                // Department dropdown (depends on faculty)
                _dropdownField(
                  label: 'Department',
                  icon: Icons.school_outlined,
                  value: _selDept,
                  items: _depts,
                  onChanged: (v) => setState(() => _selDept = v),
                  validator: (v) => v == null ? 'Select your department' : null,
                  hint: _selFaculty == null
                      ? 'Select faculty first'
                      : 'Select department',
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.blue.shade700,
                            ),
                          )
                        : const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _loginField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    TextCapitalization cap = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      textCapitalization: cap,
      validator: validator,
      decoration: _loginDec(label, icon),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.indigo.shade900,
      style: const TextStyle(color: Colors.white),
      decoration: _loginDec(label, icon),
      hint: Text(
        hint ?? 'Select $label',
        style: const TextStyle(color: Colors.white38, fontSize: 14),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          )
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
      validator: validator,
    );
  }

  InputDecoration _loginDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.blue.shade300),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
    errorStyle: const TextStyle(color: Colors.redAccent),
  );
}

// ══════════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Course> courses = [];
  StudentProfile profile = StudentProfile();
  GradingModel grading = GradingModel.defaultNigerian5();

  bool isDarkMode = false;
  String searchQuery = '';
  int currentPage = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _pageCtrl = PageController();
  final _shareKey = GlobalKey();
  late TabController _tabCtrl;

  int _selYear = 1, _selSem = 1;

  // ── init / dispose ──────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this)
      ..addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scoreCtrl.dispose();
    _unitCtrl.dispose();
    _searchCtrl.dispose();
    _pageCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── storage ─────────────────────────────────────────────
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('courses');
    if (raw != null)
      courses = raw.map((e) => Course.fromMap(jsonDecode(e))).toList();
    final pd = prefs.getString('profile');
    if (pd != null) profile = StudentProfile.fromMap(jsonDecode(pd));
    final gd = prefs.getString('grading');
    if (gd != null) grading = GradingModel.fromJson(gd);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(currentPage);
    });
  }

  Future<void> _saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'courses',
      courses.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toMap()));
  }

  Future<void> _saveGrading() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grading', grading.toJson());
  }

  // ── calcs ────────────────────────────────────────────────
  int get _pageIndex => (_selYear - 1) * 2 + (_selSem - 1);
  List<Course> _semCourses(int y, int s) =>
      courses.where((c) => c.year == y && c.semester == s).toList();
  double _gpa(List<Course> list) {
    if (list.isEmpty) return 0;
    double total = 0;
    int units = 0;
    for (final c in list) {
      total += grading.getPoint(c.score) * c.unit;
      units += c.unit;
    }
    return total / units;
  }

  double get cgpa => _gpa(courses);
  double get maxGP => grading.maxGradePoint;
  int get totalUnits => courses.fold(0, (s, c) => s + c.unit);
  int get totalCourses => courses.length;
  Course? get topCourse => courses.isEmpty
      ? null
      : courses.reduce((a, b) => a.score > b.score ? a : b);
  String get bestSemLabel {
    double best = 0;
    String label = '—';
    for (int y = 1; y <= 7; y++) {
      for (int s = 1; s <= 2; s++) {
        final list = _semCourses(y, s);
        if (list.isNotEmpty) {
          final g = _gpa(list);
          if (g > best) {
            best = g;
            label = 'Year $y Sem $s (${g.toStringAsFixed(2)})';
          }
        }
      }
    }
    return label;
  }

  List<Course> get searchResults => searchQuery.isEmpty
      ? []
      : courses
            .where(
              (c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();

  // ══════════════════════════════════════════════════════════
  //  ADD COURSE (Fix #1 — clears + success dialog)
  // ══════════════════════════════════════════════════════════

  void _addCourse() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final name = _nameCtrl.text.trim().toUpperCase();
    final score = int.parse(_scoreCtrl.text.trim());
    final unit = int.parse(_unitCtrl.text.trim());
    setState(() {
      courses.add(Course(name, '', score, unit, _selYear, _selSem));
      currentPage = _pageIndex;
    });
    _pageCtrl.jumpToPage(currentPage);
    _saveCourses();
    _nameCtrl.clear();
    _scoreCtrl.clear();
    _unitCtrl.clear();
    _formKey.currentState!.reset();
    _showSuccessDialog(name);
  }

  void _showSuccessDialog(String name) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Course Added!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '$name saved to Year $_selYear, Semester $_selSem.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    ),
  );

  // ── add from JSON picker ─────────────────────────────────
  void _addFromPicker() {
    // Determine level from courses count or default
    final levelStr = '${_selYear * 100}';
    final semLabel = _selSem == 1 ? 'First Semester' : 'Second Semester';
    final available = getCourses(
      profile.faculty,
      profile.department,
      levelStr,
      semLabel,
    );
    // Filter out already-added courses
    final added = _semCourses(_selYear, _selSem).map((c) => c.name).toSet();
    final selectable = available.where((c) => !added.contains(c.code)).toList();

    if (selectable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            available.isEmpty
                ? 'No course data for ${profile.department} Year $_selYear Sem $_selSem. Use manual entry.'
                : 'All available courses for this semester already added.',
          ),
        ),
      );
      return;
    }

    final Set<String> picked = {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select Courses — Year $_selYear Sem $_selSem',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${profile.department}  •  ${profile.faculty}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: selectable.length,
                  itemBuilder: (_, i) {
                    final cd = selectable[i];
                    final isSel = picked.contains(cd.code);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSel
                            ? const BorderSide(color: Colors.blue, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSel
                              ? Colors.blue
                              : Colors.grey.shade200,
                          child: Icon(
                            isSel ? Icons.check : Icons.book_outlined,
                            color: isSel ? Colors.white : Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          cd.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${cd.title}  •  ${cd.unit} unit${cd.unit > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => setB(() {
                          if (isSel)
                            picked.remove(cd.code);
                          else
                            picked.add(cd.code);
                        }),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    if (picked.isNotEmpty)
                      Text(
                        '${picked.length} course${picked.length > 1 ? 's' : ''} selected',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: picked.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _showScoreEntryForPicked(
                                  selectable
                                      .where((c) => picked.contains(c.code))
                                      .toList(),
                                );
                              },
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add ${picked.isEmpty ? '' : picked.length.toString()} Selected',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScoreEntryForPicked(List<CourseData> picked) {
    final controllers = {
      for (final c in picked) c.code: TextEditingController(),
    };
    final fk = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Text(
                      'Enter Scores',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: Form(
                  key: fk,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    itemCount: picked.length,
                    itemBuilder: (_, i) {
                      final cd = picked[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cd.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    cd.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: controllers[cd.code],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Score',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  final s = int.tryParse(v ?? '');
                                  if (s == null || s < 0 || s > 100)
                                    return '0–100';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!fk.currentState!.validate()) return;
                      for (final cd in picked) {
                        final score = int.parse(
                          controllers[cd.code]!.text.trim(),
                        );
                        courses.add(
                          Course(
                            cd.code,
                            cd.title,
                            score,
                            cd.unit,
                            _selYear,
                            _selSem,
                          ),
                        );
                      }
                      setState(() => currentPage = _pageIndex);
                      _pageCtrl.jumpToPage(currentPage);
                      _saveCourses();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${picked.length} course${picked.length > 1 ? 's' : ''} added ✓',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save All Courses',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── edit / delete ────────────────────────────────────────
  void _editCourse(Course c) {
    _nameCtrl.text = c.name;
    _scoreCtrl.text = c.score.toString();
    _unitCtrl.text = c.unit.toString();
    _selYear = c.year;
    _selSem = c.semester;
    setState(() {
      courses.removeWhere((x) => x.id == c.id);
      currentPage = _pageIndex;
    });
    _saveCourses();
    _pageCtrl.jumpToPage(currentPage);
    _tabCtrl.animateTo(0);
  }

  void _deleteCourse(Course c) async {
    HapticFeedback.mediumImpact();
    final ok = await _confirm(
      'Delete ${c.name}?',
      'This course will be permanently removed.',
      'Delete',
    );
    if (ok) {
      setState(() => courses.removeWhere((x) => x.id == c.id));
      _saveCourses();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${c.name} deleted')));
    }
  }

  void _clearAll() async {
    final ok = await _confirm(
      'Clear All Courses',
      'This will permanently delete ALL saved courses.',
      'Clear All',
    );
    if (ok) {
      setState(() {
        courses.clear();
        currentPage = 0;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('courses');
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All courses cleared')));
    }
  }

  void _deleteAccount() async {
    final ok = await _confirm(
      'Delete Account',
      'This permanently deletes your profile and ALL course data. Cannot be undone.',
      'Delete Account',
      destructive: true,
    );
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(_fade_(const LoginScreen()), (_) => false);
    }
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action, {
    bool destructive = true,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: destructive ? Colors.red : null),
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ══════════════════════════════════════════════════════════
  //  WHAT-IF (Fix #2 — existing courses only)
  // ══════════════════════════════════════════════════════════

  void _showWhatIf() {
    if (courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add courses first to use the simulator.'),
        ),
      );
      return;
    }
    final Map<String, int> overrides = {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) {
          final simList = courses
              .map(
                (c) => overrides.containsKey(c.id)
                    ? Course.withId(
                        c.id,
                        c.name,
                        c.title,
                        overrides[c.id]!,
                        c.unit,
                        c.year,
                        c.semester,
                      )
                    : c,
              )
              .toList();
          final projected = _gpa(simList);
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                _sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: const [
                      Icon(Icons.science, color: Colors.purple),
                      SizedBox(width: 10),
                      Text(
                        'What-If Simulator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // CGPA bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _cgpaCol('Current CGPA', cgpa.toStringAsFixed(2)),
                      const Icon(Icons.arrow_forward, color: Colors.white54),
                      _cgpaCol(
                        'Projected CGPA',
                        overrides.isEmpty ? '—' : projected.toStringAsFixed(2),
                        color: overrides.isEmpty
                            ? Colors.white54
                            : projected > cgpa
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Text(
                    'Tap a course to simulate a different score.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: courses.length,
                    itemBuilder: (_, i) {
                      final c = courses[i];
                      final has = overrides.containsKey(c.id);
                      final dispScore = has ? overrides[c.id]! : c.score;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: has
                              ? const BorderSide(
                                  color: Colors.purple,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scoreColor(dispScore),
                            child: Text(
                              grading.getGrade(dispScore),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Original: ${c.score}  •  Unit: ${c.unit}  •  Y${c.year}S${c.semester}'
                            '${has ? '\nSimulated: ${overrides[c.id]}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: has ? Colors.purple : Colors.grey.shade600,
                            ),
                          ),
                          trailing: has
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setB(() => overrides.remove(c.id)),
                                )
                              : const Icon(Icons.edit_note, color: Colors.grey),
                          onTap: () {
                            final sc = TextEditingController(
                              text: c.score.toString(),
                            );
                            showDialog(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                title: Text('Simulate: ${c.name}'),
                                content: TextField(
                                  controller: sc,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'New score (0–100)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      final s = int.tryParse(sc.text.trim());
                                      if (s != null && s >= 0 && s <= 100) {
                                        setB(() => overrides[c.id] = s);
                                        Navigator.pop(d);
                                      }
                                    },
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
                            );
                          },
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
    );
  }

  Widget _cgpaCol(String label, String value, {Color color = Colors.white}) =>
      Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

  // ══════════════════════════════════════════════════════════
  //  TARGET CGPA (Fix #3 — single input + button)
  // ══════════════════════════════════════════════════════════

  void _showTargetCalc() {
    final targetCtrl = TextEditingController();
    String result = '', emoji = '';
    void compute(void Function(void Function()) setD) {
      final target = double.tryParse(targetCtrl.text.trim());
      if (target == null || target <= 0 || target > maxGP) {
        setD(() {
          result =
              'Enter a valid CGPA between 0.01 and ${maxGP.toStringAsFixed(1)}.';
          emoji = '⚠️';
        });
        return;
      }
      final cur = cgpa;
      final curUnits = totalUnits;
      if (curUnits == 0) {
        setD(() {
          result = 'Add at least one course first.';
          emoji = '📚';
        });
        return;
      }
      if (cur >= target) {
        setD(() {
          result =
              'You already have ${cur.toStringAsFixed(2)}, meeting your target! 🎉';
          emoji = '🎉';
        });
        return;
      }
      final curTotal = courses.fold(
        0.0,
        (s, c) => s + grading.getPoint(c.score) * c.unit,
      );
      final gap = target - cur;
      final List<String> sc = [];
      for (final rem in [15, 20, 30]) {
        final needed = (target * (curUnits + rem) - curTotal) / rem;
        if (needed > maxGP) {
          sc.add('• With $rem more units: Not achievable');
        } else {
          // Find grade label for needed GP
          String glabel = '—';
          for (final r in grading.rules) {
            if (r.gradePoint >= needed - 0.01)
              glabel = '${r.grade} (≥${r.minScore})';
          }
          sc.add(
            '• With $rem more units: avg GP ${needed.toStringAsFixed(2)} ≈ $glabel',
          );
        }
      }
      setD(() {
        result =
            'Current CGPA : ${cur.toStringAsFixed(2)}\n'
            'Target CGPA  : ${target.toStringAsFixed(2)}\nGap : ${gap.toStringAsFixed(2)} GP\n\n'
            'What you need:\n${sc.join('\n')}';
        emoji = '🎯';
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.track_changes, color: Colors.teal),
              SizedBox(width: 8),
              Flexible(child: Text('Target CGPA Calculator')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Desired CGPA (max ${maxGP.toStringAsFixed(1)})',
                    prefixIcon: const Icon(
                      Icons.flag_outlined,
                      color: Colors.teal,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => compute(setD),
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (result.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$emoji  $result',
                      style: const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  GRADING MODEL SETTINGS
  // ══════════════════════════════════════════════════════════

  void _showGradingSettings() {
    // Deep copy rules
    final List<GradeRule> editRules = grading.rules
        .map((r) => r.copyWith())
        .toList();
    final controllers = {
      for (final r in editRules)
        r.grade: {
          'min': TextEditingController(text: r.minScore.toString()),
          'gp': TextEditingController(text: r.gradePoint.toStringAsFixed(1)),
        },
    };
    final fk = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: const [
                    Icon(Icons.tune, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Grading System',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Set minimum score and grade point for each grade.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              // Preset buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final preset = GradingModel.defaultNigerian5();
                          setState(() => grading = preset);
                          _saveGrading();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('5.0 scale preset applied'),
                            ),
                          );
                        },
                        child: const Text('5.0 Scale Preset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final preset = GradingModel.defaultNigerian4();
                          setState(() => grading = preset);
                          _saveGrading();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('4.0 scale preset applied'),
                            ),
                          );
                        },
                        child: const Text('4.0 Scale Preset'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: Form(
                  key: fk,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: editRules.length,
                    itemBuilder: (_, i) {
                      final r = editRules[i];
                      final isF = r.grade == 'F';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _gradeColor(r.grade),
                              child: Text(
                                r.grade,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: controllers[r.grade]!['min'],
                                enabled: !isF,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isF ? 'Below all' : 'Min score',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                validator: isF
                                    ? null
                                    : (v) {
                                        final s = int.tryParse(v ?? '');
                                        if (s == null || s < 0 || s > 100)
                                          return '0-100';
                                        return null;
                                      },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: controllers[r.grade]!['gp'],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Grade Point',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  final g = double.tryParse(v ?? '');
                                  if (g == null || g < 0) return '≥0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!fk.currentState!.validate()) return;
                      for (final r in editRules) {
                        r.minScore =
                            int.tryParse(controllers[r.grade]!['min']!.text) ??
                            r.minScore;
                        r.gradePoint =
                            double.tryParse(
                              controllers[r.grade]!['gp']!.text,
                            ) ??
                            r.gradePoint;
                      }
                      setState(() => grading = GradingModel(rules: editRules));
                      _saveGrading();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Grading system updated ✓'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save Grading System',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.amber;
      case 'E':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PDF
  // ══════════════════════════════════════════════════════════

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    final rows = <List<String>>[];
    for (int y = 1; y <= 7; y++) {
      for (int s = 1; s <= 2; s++) {
        for (final c in _semCourses(y, s)) {
          rows.add([
            c.name,
            '${c.score}',
            grading.getGrade(c.score),
            grading.getPoint(c.score).toStringAsFixed(1),
            '${c.unit}',
            'Y$y S$s',
          ]);
        }
      }
    }
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: const pw.BoxDecoration(
              color: PdfColors.indigo800,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ACADEMIC TRANSCRIPT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (profile.name.isNotEmpty)
                  pw.Text(
                    'Name: ${profile.name}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                if (profile.matricNumber.isNotEmpty)
                  pw.Text(
                    'Matric: ${profile.matricNumber}',
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                if (profile.department.isNotEmpty)
                  pw.Text(
                    'Dept: ${profile.department}',
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                if (profile.faculty.isNotEmpty)
                  pw.Text(
                    'Faculty: ${profile.faculty}',
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                if (profile.email.isNotEmpty)
                  pw.Text(
                    'Email: ${profile.email}',
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Overall CGPA',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      cgpa.toStringAsFixed(2),
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Class of Degree',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      getDegreeClass(cgpa, maxGP),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo800,
                      ),
                    ),
                    pw.Text(
                      'Units: $totalUnits  |  Courses: $totalCourses',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (rows.isNotEmpty) ...[
            pw.Text(
              'Course Details',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.indigo800,
                  ),
                  children:
                      ['Course', 'Score', 'Grade', 'GP', 'Units', 'Period']
                          .map(
                            (h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                h,
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                ...rows.asMap().entries.map(
                  (e) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: e.key % 2 == 0
                          ? PdfColors.grey50
                          : PdfColors.white,
                    ),
                    children: e.value
                        .map(
                          (cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Semester GPA Summary',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...() {
            final r = <pw.Widget>[];
            for (int y = 1; y <= 7; y++)
              for (int s = 1; s <= 2; s++) {
                final list = _semCourses(y, s);
                if (list.isEmpty) continue;
                r.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Year $y, Semester $s'),
                        pw.Text(
                          'GPA: ${_gpa(list).toStringAsFixed(2)}   Units: ${list.fold(0, (s, c) => s + c.unit)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }
            return r;
          }(),
          pw.SizedBox(height: 28),
          pw.Text(
            'Generated by CGPA Calculator — TRIMAX',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // ── share as image ───────────────────────────────────────
  Future<void> _shareImage() async {
    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final png = bytes!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cgpa_result.png');
      await file.writeAsBytes(png);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'My CGPA: ${cgpa.toStringAsFixed(2)} — ${getDegreeClass(cgpa, maxGP)} 🎓',
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not share image')));
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PROFILE TAB (Fix #4)
  // ══════════════════════════════════════════════════════════

  Widget _buildProfile() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        // Header card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.indigo.shade900],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.email,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoTile(Icons.badge_outlined, 'Matric Number', profile.matricNumber),
        _infoTile(Icons.school_outlined, 'Department', profile.department),
        _infoTile(Icons.account_balance_outlined, 'Faculty', profile.faculty),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _showEditProfile,
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoTile(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.blue, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showEditProfile() {
    final fk = GlobalKey<FormState>();
    final nameC = TextEditingController(text: profile.name);
    final emailC = TextEditingController(text: profile.email);
    final matricC = TextEditingController(text: profile.matricNumber);
    String? selFac = profile.faculty.isNotEmpty ? profile.faculty : null;
    String? selDept = profile.department.isNotEmpty ? profile.department : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Profile'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: fk,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField(nameC, 'Full Name', Icons.person_outline, (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  }),
                  const SizedBox(height: 12),
                  _editField(emailC, 'Email', Icons.email_outlined, (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!isValidEmail(v.trim())) return 'Invalid email';
                    return null;
                  }),
                  const SizedBox(height: 12),
                  _editField(matricC, 'Matric Number', Icons.badge_outlined, (
                    v,
                  ) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  }),
                  const SizedBox(height: 12),
                  // Faculty dropdown
                  DropdownButtonFormField<String>(
                    value: getFaculties().contains(selFac) ? selFac : null,
                    decoration: InputDecoration(
                      labelText: 'Faculty',
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items: getFaculties()
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() {
                      selFac = v;
                      selDept = null;
                    }),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  // Department dropdown
                  DropdownButtonFormField<String>(
                    value:
                        selFac != null &&
                            getDepartments(selFac!).contains(selDept)
                        ? selDept
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items:
                        (selFac != null ? getDepartments(selFac!) : <String>[])
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setD(() => selDept = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (!fk.currentState!.validate()) return;
                setState(
                  () => profile = StudentProfile(
                    name: nameC.text.trim(),
                    email: emailC.text.trim(),
                    matricNumber: matricC.text.trim(),
                    faculty: selFac ?? '',
                    department: selDept ?? '',
                  ),
                );
                _saveProfile();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated ✓')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String? Function(String?) validator,
  ) => TextFormField(
    controller: ctrl,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  GPA CHART
  // ══════════════════════════════════════════════════════════

  Widget _buildChart() {
    final spots = <FlSpot>[];
    final labels = <String>[];
    int idx = 0;
    for (int y = 1; y <= 7; y++)
      for (int s = 1; s <= 2; s++) {
        final list = _semCourses(y, s);
        if (list.isNotEmpty) {
          spots.add(FlSpot(idx.toDouble(), _gpa(list)));
          labels.add('Y${y}S$s');
          idx++;
        }
      }
    if (spots.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Add courses to see your GPA trend',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GPA Per Semester',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxGP,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxGP / 5,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxGP / 5,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length)
                          return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
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
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            children: [
              _dot('First Class', Colors.green),
              _dot('2nd Upper', Colors.blue),
              _dot('2nd Lower', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    ],
  );

  // ══════════════════════════════════════════════════════════
  //  SUMMARY (Fix #5 — no overflow, fixed stat cards)
  // ══════════════════════════════════════════════════════════

  Widget _buildSummary() {
    final top = topCourse;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.indigo.shade800],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  if (profile.name.isNotEmpty) ...[
                    Text(
                      profile.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (profile.department.isNotEmpty)
                      Text(
                        profile.department,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'CGPA',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    cgpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: degreeColor(cgpa, maxGP).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: degreeColor(cgpa, maxGP).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      getDegreeClass(cgpa, maxGP),
                      style: TextStyle(
                        color: degreeColor(cgpa, maxGP),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pill('Courses', '$totalCourses'),
                      _pill('Units', '$totalUnits'),
                      _pill('Max GP', maxGP.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareImage,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Fix #5 — Row of Rows instead of GridView to avoid overflow
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _statCard(
                  'Best Semester',
                  bestSemLabel,
                  Icons.emoji_events,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Top Course',
                  top != null ? '${top.name}\n(Score: ${top.score})' : '—',
                  Icons.star,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _statCard(
                  'Total Units',
                  '$totalUnits credits',
                  Icons.library_books,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Courses Taken',
                  '$totalCourses',
                  Icons.menu_book,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ],
  );

  // Fix #5: content-sized, not fixed-height
  Widget _statCard(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════════
  //  COURSES TAB (Fix #5 — bottom margin)
  // ══════════════════════════════════════════════════════════

  Widget _buildCourses() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search courses...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      searchQuery = '';
                      _searchCtrl.clear();
                    }),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          ),
        ),
      ),
      if (searchQuery.isNotEmpty)
        Expanded(
          child: Builder(
            builder: (_) {
              final r = searchResults;
              if (r.isEmpty)
                return const Center(
                  child: Text(
                    'No courses found',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  30,
                ), // bottom margin fix
                itemCount: r.length,
                itemBuilder: (_, i) => _courseCard(r[i]),
              );
            },
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _indicator(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: 14,
            onPageChanged: (i) => setState(() => currentPage = i),
            itemBuilder: (_, index) {
              final y = (index ~/ 2) + 1;
              final s = (index % 2) + 1;
              final list = _semCourses(y, s);
              final gpa = _gpa(list);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.indigo],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year $y • Semester $s',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'GPA: ${gpa.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${list.length} course${list.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${list.fold(0, (s, c) => s + c.unit)} units',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: list.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 50,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No courses yet',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  30,
                                ), // bottom margin fix
                                itemCount: list.length,
                                itemBuilder: (_, i) => _dismissible(list[i]),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ],
  );

  Widget _indicator() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(14, (i) {
      final a = i == currentPage;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: a ? 18 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: a ? Colors.blue : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }),
  );

  Widget _dismissible(Course c) => Dismissible(
    key: Key(c.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete, color: Colors.white),
    ),
    confirmDismiss: (_) async {
      HapticFeedback.mediumImpact();
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('Delete ${c.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    },
    onDismissed: (_) {
      setState(() => courses.removeWhere((x) => x.id == c.id));
      _saveCourses();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${c.name} deleted')));
    },
    child: _courseCard(c),
  );

  Widget _courseCard(Course c) => Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: scoreColor(c.score),
        child: Text(
          grading.getGrade(c.score),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        c.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Score ${c.score} • Unit ${c.unit} • GP ${grading.getPoint(c.score).toStringAsFixed(1)} • Y${c.year}S${c.semester}'
          '${c.title.isNotEmpty ? "\n${c.title}" : ""}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => _editCourse(c),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _deleteCourse(c),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  ADD TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildAddTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          // Profile mini-banner
          if (profile.name.isNotEmpty)
            GestureDetector(
              onTap: () => _tabCtrl.animateTo(4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 18,
                      child: Text(
                        profile.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (profile.department.isNotEmpty)
                            Text(
                              profile.department,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.blue.shade300),
                  ],
                ),
              ),
            ),

          // Year / semester dropdowns
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: List.generate(7, (i) => i + 1)
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('Year $e'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selYear = v!),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selSem,
                          decoration: InputDecoration(
                            labelText: 'Semester',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: [1, 2]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('Sem $e'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selSem = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── COURSE PICKER BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _addFromPicker,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Select from Course List'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blue.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or enter manually',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Manual fields
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Course Code e.g MTH101',
                      prefixIcon: const Icon(Icons.book),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter a course code';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _scoreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Score (0–100)',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a score';
                      final s = int.tryParse(v);
                      if (s == null || s < 0 || s > 100)
                        return 'Score must be 0–100';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _unitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Credit Unit (e.g 3)',
                      prefixIcon: const Icon(Icons.school),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter credit units';
                      final u = int.tryParse(v);
                      if (u == null || u <= 0) return 'Units must be 1 or more';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _addCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Add Course',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tool buttons
          Row(
            children: [
              Expanded(
                child: _toolBtn(
                  Icons.science,
                  'What-If',
                  Colors.purple,
                  _showWhatIf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _toolBtn(
                  Icons.track_changes,
                  'Target',
                  Colors.teal,
                  _showTargetCalc,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _toolBtn(
                  Icons.tune,
                  'Grading',
                  Colors.orange,
                  _showGradingSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _toolBtn(
                  Icons.picture_as_pdf,
                  'PDF',
                  Colors.red,
                  _exportPDF,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _toolBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  MAIN BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) => Theme(
    data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
    child: Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.blue.shade50,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('CGPA Calculator'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => setState(() => isDarkMode = !isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline, size: 20), text: 'Add'),
            Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Courses'),
            Tab(icon: Icon(Icons.show_chart, size: 20), text: 'Chart'),
            Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Summary'),
            Tab(icon: Icon(Icons.person, size: 20), text: 'Profile'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Persistent CGPA bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.indigo.shade900],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall CGPA',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        cgpa.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: degreeColor(cgpa, maxGP).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: degreeColor(cgpa, maxGP).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      getDegreeClass(cgpa, maxGP),
                      style: TextStyle(
                        color: degreeColor(cgpa, maxGP),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildAddTab(),
                  _buildCourses(),
                  _buildChart(),
                  _buildSummary(),
                  _buildProfile(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  SHARED UTILITIES
// ══════════════════════════════════════════════════════════

Widget _gradientBox({required Widget child}) => Container(
  width: double.infinity,
  height: double.infinity,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.blue.shade700, Colors.indigo.shade900],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: child,
);

Widget _iconCircle(IconData icon, double size, double iconSize) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    shape: BoxShape.circle,
  ),
  child: Icon(icon, size: iconSize, color: Colors.white),
);

Widget _sheetHandle() => Container(
  margin: const EdgeInsets.only(top: 12),
  width: 40,
  height: 4,
  decoration: BoxDecoration(
    color: Colors.grey.shade400,
    borderRadius: BorderRadius.circular(2),
  ),
);

PageRouteBuilder _fade_(Widget page) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 600),
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) =>
      FadeTransition(opacity: anim, child: child),
);
