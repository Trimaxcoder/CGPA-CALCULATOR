
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';


import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../models/grading_model.dart';
import '../uniport_courses.dart';
import '../services/api_service.dart';
import '../widgets/combo_field.dart';
import '../models/course_model.dart';
import '../models/studentProfile_model.dart';
import '../screens/splash_screen.dart';
import '../screens/landing_page.dart';
import '../screens/signinscreen.dart';
import '../screens/registerscreen.dart';
import '../widgets/ui_helpers.dart';
import '../widgets/snackBar.dart';





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
  bool _cgpaHidden = false;
  Timer? _syncTimer;
  final Set<String> _deletedServerIds = {};

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _cgpaHidden = prefs.getBool('cgpaHidden') ?? false;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

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

  bool _useGradeInput = false;
  String? _manualGrade;
  Course? _editingCourse;

  Course? _lastDeleted;
  int? _lastDeletedIndex;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (_tabCtrl.indexIsChanging && _tabCtrl.index != 0) {
          _cancelEdit();
        }
        setState(() {});
      });
    _loadData();
    _loadPrefs();

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncWithServer();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scoreCtrl.dispose();
    _unitCtrl.dispose();
    _searchCtrl.dispose();
    _pageCtrl.dispose();
    _tabCtrl.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('courses');
    if (raw != null) {
      courses = raw.map((e) => Course.fromMap(jsonDecode(e))).toList();
    }
    final pd = prefs.getString('profile');
    if (pd != null) profile = StudentProfile.fromMap(jsonDecode(pd));
    final gd = prefs.getString('grading');
    if (gd != null) grading = GradingModel.fromJson(gd);

    if (grading.rules.isEmpty) {
      grading = GradingModel.defaultNigerian5();
      await prefs.setString('grading', grading.toJson());
    }

    setState(() {});

    int attempts = 0;
    while (!(await TokenStorage.hasTokens()) && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    _syncWithServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(currentPage);
    });
  }

  Future<void> _syncWithServer() async {
    // Don't sync if no token — avoids redirect on fresh biometric login
    final hasToken = await TokenStorage.hasTokens();
    if (!hasToken) {
      return;
    }

    try {
      final localList = courses
    .where((c) => !_deletedServerIds.contains(c.serverId))
    .map((c) => c.toMap())
    .toList();
      print("=== SYNC deletedIds: $_deletedServerIds");
      final serverCourses = await CourseService().syncCourses(
        localList,
        deletedServerIds: _deletedServerIds.toList(),
      );
      print("=== SYNC server returned: ${serverCourses.length} courses");
      final merged = serverCourses.map((m) => Course.fromServerMap(m)).toList();

      setState(() {
        courses = merged;
        _deletedServerIds.clear();
      });
      await _saveCourses();

      final userData = await AuthService().getMe();
      if (userData['profile'] != null) {
        profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile', jsonEncode(profile.toMap()));
      }
      if (userData['grading'] != null) {
        final gData = Map<String, dynamic>.from(userData['grading'] as Map);
        if (gData['rules'] != null) {
          final tempGrading = GradingModel.fromJson(jsonEncode(gData));
          if (tempGrading.rules.isNotEmpty) {
            grading = tempGrading;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('grading', grading.toJson());
          } else {
            if (grading.rules.isEmpty)
              grading = GradingModel.defaultNigerian5();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('grading', grading.toJson());
            ProfileService()
                .updateGrading(
                  grading.rules
                      .map(
                        (r) => {
                          'grade': r.grade,
                          'minScore': r.minScore,
                          'gradePoint': r.gradePoint,
                        },
                      )
                      .toList(),
                )
                .catchError((e) => debugPrint('Grading sync failed: $e'));
          }
        }
      }
      setState(() {});
    } on UnauthorizedException {
      await TokenStorage.clearTokens();
      if (mounted) {
        Navigator.of(
          context,
        ).pushAndRemoveUntil(fadeRoute(const SignInScreen()), (_) => false);
      }
    } catch (e) {
      debugPrint('Sync skipped (offline?): $e');
    }
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

  Future<void> _scanResultSheet() async {
    if (kIsWeb) return;
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 1,
        ),
      );

      final result = await documentScanner.scanDocument();
      if (result.images.isEmpty) return;

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Reading result sheet...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final inputImage = InputImage.fromFilePath(result.images.first);
      final recognizer = TextRecognizer();
      final ocrResult = await recognizer.processImage(inputImage);
      await recognizer.close();

      print("=== OCR TEXT: ${ocrResult.text}");

      print("=== OCR TEXT: ${ocrResult.text}");
      final extracted = _parseCoursesFromText(ocrResult.text);
      print("=== EXTRACTED COUNT: ${extracted.length}");

      if (mounted) Navigator.pop(context);

      if (extracted.isEmpty) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            'Could not extract courses. Try a clearer scan.',
          );
        }
        return;
      }

      if (mounted) _showExtractedCoursesPreview(extracted);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppSnackBar.showError(context, 'Scan failed. Try again.');
      }
      debugPrint('Scan error: $e');
    }
  }

  List<Map<String, dynamic>> _parseCoursesFromText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final codePattern = RegExp(r'\|?([A-Z]{2,4})\s+(\d{3})[\.\-]?(\d?)\s*$');
    final semPattern = RegExp(
      r'(\d+)(?:st|nd|rd|th)\s+semester',
      caseSensitive: false,
    );
    final yearPattern = RegExp(r'year\s+(\w+)', caseSensitive: false);
    final gradePattern = RegExp(r'^[A-F][+-]?$');

    int wordToInt(String w) {
      const map = {
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
        'five': 5,
        'six': 6,
        'seven': 7,
      };
      return map[w.toLowerCase()] ?? (int.tryParse(w) ?? 1);
    }

    int currentYear = _selYear;
    int currentSem = _selSem;
    final codeLinesWithContext = <Map<String, dynamic>>[];
    final seenCodes = <String>{};

    // First pass — collect all course codes with position and semester/year
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      final yearMatch = yearPattern.firstMatch(line);
      if (yearMatch != null) currentYear = wordToInt(yearMatch.group(1)!);

      final semMatch = semPattern.firstMatch(line);
      if (semMatch != null)
        currentSem = int.tryParse(semMatch.group(1)!) ?? currentSem;

      final codeMatch = codePattern.firstMatch(line);
      if (codeMatch == null) continue;
      if (line.contains('Total') || line.contains('Code')) continue;

      final prefix = codeMatch.group(1)!;
      final number = codeMatch.group(2)!;
      final suffix = codeMatch.group(3) ?? '';
      final code = '$prefix$number';

      if (seenCodes.contains(code)) continue;
      seenCodes.add(code);

      int detectedSem = currentSem;
      if (suffix == '1') detectedSem = 1;
      if (suffix == '2') detectedSem = 2;

      codeLinesWithContext.add({
        'name': code,
        'year': currentYear,
        'semester': detectedSem,
        'lineIndex': i,
      });
    }

    // Collect all scores and units from entire text
    final allScores = <int>[];
    final allUnits = <int>[];
    final allGrades = <String>[];
    bool afterMark = false;
    bool afterCU = false;

    for (final line in lines) {
      if (line == 'Mark') {
        afterMark = true;
        afterCU = false;
        continue;
      }
      if (line == 'CU') {
        afterCU = true;
        afterMark = false;
        continue;
      }
      if (line == 'Grade') continue;
      if (line == '2024/2025' || line == '2023/2024') {
        afterCU = false;
        afterMark = false;
        continue;
      }

      if (afterMark) {
        final val = int.tryParse(line);
        if (val != null && val >= 0 && val <= 100) {
          allScores.add(val);
        } else if (gradePattern.hasMatch(line)) {
          allGrades.add(line);
        } else if (val == null) {
          afterMark = false;
        }
      }

      if (afterCU) {
        final val = int.tryParse(line);
        if (val != null && val >= 1 && val <= 6) {
          allUnits.add(val);
        } else if (val == null) {
          afterCU = false;
        }
      }
    }

    print("=== CODES: ${codeLinesWithContext.map((c) => c['name']).toList()}");
    print("=== UNITS: $allUnits");
    print("=== SCORES: $allScores");
    print("=== GRADES: $allGrades");

    // Build result — assign scores/units by index, fallback to empty
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < codeLinesWithContext.length; i++) {
      final c = codeLinesWithContext[i];
      final score = i < allScores.length ? allScores[i] : null;
      final unit = i < allUnits.length ? allUnits[i] : null;
      final grade = i < allGrades.length ? allGrades[i] : null;

      result.add({
        'name': c['name'],
        'year': c['year'],
        'semester': c['semester'],
        'score': score,
        'unit': unit,
        'grade': grade,
      });
    }

    return result;
  }

  void _showExtractedCoursesPreview(List<Map<String, dynamic>> extracted) {
    final gradeLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

    // Build item state list
    final items = extracted
        .map(
          (c) => {
            'name': TextEditingController(text: c['name'] as String? ?? ''),
            'score': TextEditingController(
              text: c['score'] != null ? c['score'].toString() : '',
            ),
            'unit': TextEditingController(
              text: c['unit'] != null ? c['unit'].toString() : '',
            ),
            'year': c['year'] as int,
            'semester': c['semester'] as int,
            'included': true,
            'useGrade': c['grade'] != null,
            'grade': c['grade'] as String?,
          },
        )
        .toList();

    final fk = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (ctx2, setSheet) => Column(
              children: [
                sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Extracted Courses (${items.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Review, edit or uncheck courses before saving',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Form(
                    key: fk,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final included = item['included'] as bool;
                        final useGrade = item['useGrade'] as bool;
                        final year = item['year'] as int;
                        final sem = item['semester'] as int;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: included
                                  ? Colors.blue.withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  children: [
                                    // Live blue label
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Year $year • Sem $sem',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Year dropdown
                                    DropdownButton<int>(
                                      value: year,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      dropdownColor: isDarkMode
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.white,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      items: List.generate(7, (j) => j + 1)
                                          .map(
                                            (y) => DropdownMenuItem(
                                              value: y,
                                              child: Text('Y$y'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: included
                                          ? (v) => setSheet(
                                              () => items[i]['year'] = v!,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    // Semester dropdown
                                    DropdownButton<int>(
                                      value: sem,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      dropdownColor: isDarkMode
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.white,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      items: [1, 2]
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text('S$s'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: included
                                          ? (v) => setSheet(
                                              () => items[i]['semester'] = v!,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    // Include checkbox
                                    Checkbox(
                                      value: included,
                                      activeColor: Colors.blue,
                                      onChanged: (v) => setSheet(
                                        () => items[i]['included'] = v!,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Input fields
                                Opacity(
                                  opacity: included ? 1.0 : 0.4,
                                  child: Row(
                                    children: [
                                      // Course code
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller:
                                              item['name']
                                                  as TextEditingController,
                                          enabled: included,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Code',
                                            labelStyle: TextStyle(
                                              fontSize: 11,
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          validator: (v) =>
                                              included &&
                                                  (v == null ||
                                                      v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Score or Grade
                                      Expanded(
                                        flex: 3,
                                        child: useGrade
                                            ? DropdownButtonFormField<String>(
                                                value: item['grade'] as String?,
                                                dropdownColor: isDarkMode
                                                    ? const Color(0xFF2A2A2A)
                                                    : Colors.white,
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Grade',
                                                  labelStyle: TextStyle(
                                                    fontSize: 11,
                                                    color: isDarkMode
                                                        ? Colors.white54
                                                        : Colors.black45,
                                                  ),
                                                  isDense: true,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  suffixIcon: GestureDetector(
                                                    onTap: () => setSheet(
                                                      () =>
                                                          items[i]['useGrade'] =
                                                              false,
                                                    ),
                                                    child: Icon(
                                                      Icons.swap_horiz,
                                                      size: 16,
                                                      color:
                                                          Colors.blue.shade300,
                                                    ),
                                                  ),
                                                ),
                                                items: gradeLetters
                                                    .map(
                                                      (g) => DropdownMenuItem(
                                                        value: g,
                                                        child: Text(g),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: included
                                                    ? (v) => setSheet(
                                                        () =>
                                                            items[i]['grade'] =
                                                                v,
                                                      )
                                                    : null,
                                                validator: (v) =>
                                                    included &&
                                                        useGrade &&
                                                        v == null
                                                    ? 'Select'
                                                    : null,
                                              )
                                            : TextFormField(
                                                controller:
                                                    item['score']
                                                        as TextEditingController,
                                                enabled: included,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Score',
                                                  labelStyle: TextStyle(
                                                    fontSize: 11,
                                                    color: isDarkMode
                                                        ? Colors.white54
                                                        : Colors.black45,
                                                  ),
                                                  isDense: true,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  suffixIcon: GestureDetector(
                                                    onTap: () => setSheet(
                                                      () =>
                                                          items[i]['useGrade'] =
                                                              true,
                                                    ),
                                                    child: Icon(
                                                      Icons.swap_horiz,
                                                      size: 16,
                                                      color:
                                                          Colors.blue.shade300,
                                                    ),
                                                  ),
                                                ),
                                                validator: (v) {
                                                  if (!included || useGrade)
                                                    return null;
                                                  final s = int.tryParse(
                                                    v ?? '',
                                                  );
                                                  if (s == null ||
                                                      s < 0 ||
                                                      s > 100)
                                                    return '0-100';
                                                  return null;
                                                },
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Unit
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller:
                                              item['unit']
                                                  as TextEditingController,
                                          enabled: included,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 13,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Units',
                                            labelStyle: TextStyle(
                                              fontSize: 11,
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          validator: (v) {
                                            if (!included) return null;
                                            final u = int.tryParse(v ?? '');
                                            if (u == null || u < 1)
                                              return '1-6';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Text(
                          '${items.where((i) => i['included'] as bool).length} of ${items.length} courses selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (!fk.currentState!.validate()) return;
                              final newCourses = <Course>[];
                              for (int i = 0; i < items.length; i++) {
                                final item = items[i];
                                if (!(item['included'] as bool)) continue;

                                final name =
                                    (item['name'] as TextEditingController).text
                                        .trim()
                                        .toUpperCase();
                                final unit =
                                    int.tryParse(
                                      (item['unit'] as TextEditingController)
                                          .text
                                          .trim(),
                                    ) ??
                                    2;
                                final yr = item['year'] as int;
                                final sem = item['semester'] as int;

                                int score;
                                if (item['useGrade'] as bool) {
                                  final grade = item['grade'] as String? ?? 'F';
                                  final rule = grading.rules.firstWhere(
                                    (r) => r.grade == grade,
                                    orElse: () => GradeRule(
                                      grade: 'F',
                                      minScore: 0,
                                      gradePoint: 0,
                                    ),
                                  );
                                  score = rule.minScore;
                                } else {
                                  score =
                                      int.tryParse(
                                        (item['score'] as TextEditingController)
                                            .text
                                            .trim(),
                                      ) ??
                                      0;
                                }

                                final course = Course(
                                  name,
                                  '',
                                  score,
                                  unit,
                                  yr,
                                  sem,
                                );
                                courses.add(course);
                                newCourses.add(course);
                              }

                              setState(() {});
                              _saveCourses();

                              for (final course in newCourses) {
                                CourseService()
                                    .addCourse(
                                      name: course.name,
                                      title: course.title,
                                      score: course.score,
                                      unit: course.unit,
                                      year: course.year,
                                      semester: course.semester,
                                      clientId: course.id,
                                    )
                                    .catchError(
                                      (e) =>
                                          debugPrint('Server save failed: $e'),
                                    );
                              }

                              Navigator.pop(ctx);
                              AppSnackBar.showSuccess(
                                context,
                                '${newCourses.length} course${newCourses.length > 1 ? 's' : ''} added ✓',
                              );
                            },
                            icon: const Icon(Icons.save),
                            label: const Text(
                              'Save Selected Courses',
                              style: TextStyle(fontSize: 15),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ADD COURSE
  // ══════════════════════════════════════════════════════════

  void _addCourse() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    final name = _nameCtrl.text.trim().toUpperCase();
    final unit = int.parse(_unitCtrl.text.trim());
    int score;
    if (_useGradeInput) {
      final rule = grading.rules.firstWhere(
        (r) => r.grade == _manualGrade,
        orElse: () => GradeRule(grade: 'F', minScore: 0, gradePoint: 0),
      );
      score = rule.minScore;
    } else {
      score = int.parse(_scoreCtrl.text.trim());
    }
    final wasEditing = _editingCourse;
    setState(() {
      courses.add(Course(name, '', score, unit, _selYear, _selSem));
      _editingCourse = null;
      currentPage = _pageIndex;
    });
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(currentPage);
    _saveCourses();
    if (wasEditing?.serverId != null) {
      CourseService()
          .updateCourse(
            id: wasEditing!.serverId!,
            name: name,
            title: '',
            score: score,
            unit: unit,
            year: _selYear,
            semester: _selSem,
          )
          .catchError((e) => debugPrint('Server update failed: $e'));
    } else {
      CourseService()
          .addCourse(
            name: name,
            title: '',
            score: score,
            unit: unit,
            year: _selYear,
            semester: _selSem,
            clientId: courses.last.id,
          )
          .then((serverCourse) {
            debugPrint('Course saved on server: ${serverCourse['_id']}');
          })
          .catchError((e) {
            debugPrint('Server save failed (will sync later): $e');
          });
    }
    _nameCtrl.clear();
    _scoreCtrl.clear();
    _unitCtrl.clear();
    _manualGrade = null;
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
    final levelStr = '${_selYear * 100}';
    final semLabel = _selSem == 1 ? 'First Semester' : 'Second Semester';
    final available = getCourses(
      profile.faculty,
      profile.department,
      levelStr,
      semLabel,
    );
    final added = _semCourses(_selYear, _selSem).map((c) => c.name).toSet();
    final selectable = available.where((c) => !added.contains(c.code)).toList();

    if (selectable.isEmpty) {
      AppSnackBar.showInfo(
        context,
        available.isEmpty
            ? 'No course data for ${profile.department} Year $_selYear Sem $_selSem. Use manual entry.'
            : 'All available courses for this semester already added.',
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
              sheetHandle(),
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
              SafeArea(
                top: false,
                child: Padding(
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
    final gradeSelections = <String, String?>{
      for (final c in picked) c.code: null,
    };
    final fk = GlobalKey<FormState>();
    bool _saved = false;
    bool _useGrade = false;

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final labelColor = isDarkMode ? Colors.white70 : Colors.black54;
    final fillColor = isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.grey.shade50;
    final subColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500;
    final gradeLetters = grading.rules.map((r) => r.grade).toList();

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
          child: StatefulBuilder(
            builder: (ctx2, setSheet) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _useGrade ? 'Enter Grades' : 'Enter Scores',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      _inputModeToggle(
                        useGrade: _useGrade,
                        onChanged: (v) {
                          setSheet(() {
                            _useGrade = v;
                            fk.currentState?.reset();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.46,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      cd.title,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor,
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
                                child: _useGrade
                                    ? _gradeDropdownFormField(
                                        value: gradeSelections[cd.code],
                                        grades: gradeLetters,
                                        fillColor: fillColor,
                                        labelColor: labelColor,
                                        textColor: textColor,
                                        onChanged: (v) => setSheet(
                                          () => gradeSelections[cd.code] = v,
                                        ),
                                      )
                                    : TextFormField(
                                        controller: controllers[cd.code],
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          labelText: 'Score',
                                          labelStyle: TextStyle(
                                            color: labelColor,
                                          ),
                                          filled: true,
                                          fillColor: fillColor,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: StatefulBuilder(
                      builder: (ctx2, setSt) => SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saved
                              ? null
                              : () {
                                  if (_useGrade) {
                                    final missing = picked
                                        .where(
                                          (c) =>
                                              gradeSelections[c.code] == null,
                                        )
                                        .map((c) => c.code)
                                        .toList();
                                    if (missing.isNotEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Select grade for: ${missing.join(', ')}',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                  } else {
                                    if (!fk.currentState!.validate()) return;
                                  }
                                  setSt(() => _saved = true);
                                  final existingKeys = courses
                                      .map((c) => '${c.name}_${c.unit}')
                                      .toSet();
                                  final newCourses = <Course>[];

                                  for (final cd in picked) {
                                    final key = '${cd.code}_${cd.unit}';
                                    if (existingKeys.contains(key)) continue;
                                    final int score;
                                    if (_useGrade) {
                                      final grade = gradeSelections[cd.code]!;
                                      final rule = grading.rules.firstWhere(
                                        (r) => r.grade == grade,
                                        orElse: () => GradeRule(
                                          grade: 'F',
                                          minScore: 0,
                                          gradePoint: 0,
                                        ),
                                      );
                                      score = rule.minScore;
                                    } else {
                                      score = int.parse(
                                        controllers[cd.code]!.text.trim(),
                                      );
                                    }
                                    final course = Course(
                                      cd.code,
                                      cd.title,
                                      score,
                                      cd.unit,
                                      _selYear,
                                      _selSem,
                                    );
                                    courses.add(course);
                                    newCourses.add(course);
                                    existingKeys.add(key);
                                  }

                                  setState(() => currentPage = _pageIndex);
                                  if (_pageCtrl.hasClients)
                                    _pageCtrl.jumpToPage(currentPage);
                                  _saveCourses();

                                  // Save each new course to server
                                  for (final course in newCourses) {
                                    CourseService()
                                        .addCourse(
                                          name: course.name,
                                          title: course.title,
                                          score: course.score,
                                          unit: course.unit,
                                          year: course.year,
                                          semester: course.semester,
                                          clientId: course.id,
                                        )
                                        .then(
                                          (s) => print(
                                            "=== PICKER COURSE SAVED: ${s['_id']}",
                                          ),
                                        )
                                        .catchError(
                                          (e) => print(
                                            "=== PICKER COURSE FAILED: $e",
                                          ),
                                        );
                                  }

                                  Navigator.pop(ctx);
                                  final added = newCourses.length;
                                  final skipped = picked.length - added;
                                  final msg = added == 0
                                      ? 'All courses already saved — no duplicates added'
                                      : '$added course${added > 1 ? 's' : ''} added ✓'
                                            '${skipped > 0 ? ' ($skipped duplicate${skipped > 1 ? 's' : ''} skipped)' : ''}';
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(msg)));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _saved ? Colors.grey : Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _saved ? 'Saved ✓' : 'Save All Courses',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputModeToggle({
    required bool useGrade,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip('Score', !useGrade, () => onChanged(false)),
          _modeChip('Grade', useGrade, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey,
            ),
          ),
        ),
      );

  Widget _gradeDropdownFormField({
    required String? value,
    required List<String> grades,
    required Color fillColor,
    required Color labelColor,
    required Color textColor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Grade',
        labelStyle: TextStyle(color: labelColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      style: TextStyle(color: textColor, fontSize: 14),
      items: grades
          .map(
            (g) => DropdownMenuItem(
              value: g,
              child: Text(g, style: TextStyle(color: textColor)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Select' : null,
    );
  }

  // ── edit  ────────────────────────────────────────

  void _editCourse(Course c) {
    final nameCtrl = TextEditingController(text: c.name);
    final scoreCtrl = TextEditingController(text: c.score.toString());
    final unitCtrl = TextEditingController(text: c.unit.toString());
    int selYear = c.year;
    int selSem = c.semester;
    bool useGrade = false;
    String? manualGrade;
    final fk = GlobalKey<FormState>();
    final gradeLetters = grading.rules.map((r) => r.grade).toList();

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
          child: StatefulBuilder(
            builder: (ctx2, setSheet) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: fk,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sheetHandle(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Edit Course',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        _inputModeToggle(
                          useGrade: useGrade,
                          onChanged: (v) => setSheet(() => useGrade = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Course name
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Course Code',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Score or Grade
                    useGrade
                        ? _gradeDropdownFormField(
                            value: manualGrade,
                            grades: gradeLetters,
                            fillColor: isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade50,
                            labelColor: isDarkMode
                                ? Colors.white70
                                : Colors.black54,
                            textColor: isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            onChanged: (v) => setSheet(() => manualGrade = v),
                          )
                        : TextFormField(
                            controller: scoreCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Score (0–100)',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white24
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            validator: (v) {
                              final s = int.tryParse(v ?? '');
                              if (s == null || s < 0 || s > 100)
                                return 'Enter 0–100';
                              return null;
                            },
                          ),
                    const SizedBox(height: 14),

                    // Unit
                    TextFormField(
                      controller: unitCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Credit Units',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final u = int.tryParse(v ?? '');
                        if (u == null || u < 1) return 'Enter valid units';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Year & Semester
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selYear,
                            dropdownColor: isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Year',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white24
                                      : Colors.grey.shade400,
                                ),
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
                            onChanged: (v) => setSheet(() => selYear = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selSem,
                            dropdownColor: isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              labelStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white24
                                      : Colors.grey.shade400,
                                ),
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
                            onChanged: (v) => setSheet(() => selSem = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (useGrade && manualGrade == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select a grade')),
                            );
                            return;
                          }
                          if (!fk.currentState!.validate()) return;

                          final name = nameCtrl.text.trim().toUpperCase();
                          final unit = int.parse(unitCtrl.text.trim());
                          final int score;
                          if (useGrade) {
                            final rule = grading.rules.firstWhere(
                              (r) => r.grade == manualGrade,
                              orElse: () => GradeRule(
                                grade: 'F',
                                minScore: 0,
                                gradePoint: 0,
                              ),
                            );
                            score = rule.minScore;
                          } else {
                            score = int.parse(scoreCtrl.text.trim());
                          }

                          // Update locally
                          setState(() {
                            final idx = courses.indexWhere((x) => x.id == c.id);
                            if (idx != -1) {
                              courses[idx] = Course(
                                name,
                                c.title,
                                score,
                                unit,
                                selYear,
                                selSem,
                              )..serverId = c.serverId;
                            }
                          });
                          _saveCourses();

                          // Update on server
                          if (c.serverId != null) {
                            CourseService()
                                .updateCourse(
                                  id: c.serverId!,
                                  name: name,
                                  title: c.title,
                                  score: score,
                                  unit: unit,
                                  year: selYear,
                                  semester: selSem,
                                )
                                .catchError(
                                  (e) => debugPrint('Update failed: $e'),
                                );
                          }

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name updated ✓')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
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
      ),
    );
  }

  void _cancelEdit() {
    if (_editingCourse != null) {
      setState(() {
        courses.add(_editingCourse!);
        _editingCourse = null;
      });
      _saveCourses();
      _nameCtrl.clear();
      _scoreCtrl.clear();
      _unitCtrl.clear();
      _manualGrade = null;
      _formKey.currentState?.reset();
    }
  }

  void _deleteCourse(Course c, {int? atIndex}) async {
    HapticFeedback.mediumImpact();
    final idx = atIndex ?? courses.indexOf(c);
    setState(() {
      courses.removeWhere((x) => x.id == c.id);
      _lastDeleted = c;
      _lastDeletedIndex = idx;
    });
    _saveCourses();
    if (c.serverId != null) {
      _deletedServerIds.add(c.serverId!);
      CourseService()
          .deleteCourse(c.serverId!)
          .then((_) => print("=== DELETE SUCCESS"))
          .catchError((e) => print("=== DELETE FAILED: $e"));
    } else {
      print("=== NO serverId — skipping server delete");
    }
    AppSnackBar.showUndo(context, '${c.name} deleted', _undoDelete);
  }

  void _undoDelete() {
    if (_lastDeleted == null) return;
    final course = _lastDeleted!;
    final idx = _lastDeletedIndex ?? courses.length;
    setState(() {
      if (idx >= 0 && idx <= courses.length) {
        courses.insert(idx, course);
      } else {
        courses.add(course);
      }
      _lastDeleted = null;
      _lastDeletedIndex = null;
    });
    _saveCourses();
    AppSnackBar.showSuccess(context, '${course.name} restored');
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
      CourseService().deleteAllCourses().catchError(
        (e) => debugPrint('Server clear failed: $e'),
      );
      AppSnackBar.showSuccess(context, 'All courses cleared');
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
  //  MANUAL BATCH ENTRY
  // ══════════════════════════════════════════════════════════

  void _showManualBatchEntry() {
    const int initRows = 5;

    final List<Map<String, TextEditingController>> rows = List.generate(
      initRows,
      (_) => {
        'name': TextEditingController(),
        'code': TextEditingController(),
        'unit': TextEditingController(),
        'score': TextEditingController(),
      },
    );
    final List<String?> gradeSelections = List.filled(
      initRows,
      null,
      growable: true,
    );
    bool useGrade = false;
    final gradeLetters = grading.rules.map((r) => r.grade).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (ctx2, setSheet) {
              final textColor = isDarkMode ? Colors.white : Colors.black87;
              final labelColor = isDarkMode ? Colors.white70 : Colors.black54;
              final fillColor = isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade50;
              final borderColor = isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade200;
              final headerBg = isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.blue.shade50;

              InputDecoration cellDec(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: fillColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                errorStyle: const TextStyle(fontSize: 0, height: 0),
              );

              void addRow() {
                setSheet(() {
                  rows.add({
                    'name': TextEditingController(),
                    'code': TextEditingController(),
                    'unit': TextEditingController(),
                    'score': TextEditingController(),
                  });
                  gradeSelections.add(null);
                });
              }

              void removeRow(int i) {
                setSheet(() {
                  rows[i].values.forEach((c) => c.dispose());
                  rows.removeAt(i);
                  gradeSelections.removeAt(i);
                });
              }

              void saveAll() {
                final filled = <int>[];
                for (int i = 0; i < rows.length; i++) {
                  final codeVal = rows[i]['code']!.text.trim();
                  final unitVal = rows[i]['unit']!.text.trim();
                  final scoreVal = rows[i]['score']!.text.trim();
                  final gradeVal = gradeSelections[i];
                  final nameVal = rows[i]['name']!.text.trim();
                  if (nameVal.isEmpty &&
                      codeVal.isEmpty &&
                      unitVal.isEmpty &&
                      scoreVal.isEmpty &&
                      gradeVal == null)
                    continue;
                  filled.add(i);
                }

                if (filled.isEmpty) {
                  AppSnackBar.showInfo(context, 'No course data entered.');
                  return;
                }

                final errors = <String>[];
                for (final i in filled) {
                  final code = rows[i]['code']!.text.trim();
                  final unit = int.tryParse(rows[i]['unit']!.text.trim());
                  final label = code.isNotEmpty ? code : 'Row ${i + 1}';
                  if (code.isEmpty)
                    errors.add('Row ${i + 1}: course code missing');
                  if (unit == null || unit <= 0)
                    errors.add('$label: invalid unit');
                  if (useGrade) {
                    if (gradeSelections[i] == null)
                      errors.add('$label: grade not selected');
                  } else {
                    final s = int.tryParse(rows[i]['score']!.text.trim());
                    if (s == null || s < 0 || s > 100)
                      errors.add('$label: score must be 0–100');
                  }
                }

                if (errors.isNotEmpty) {
                  showDialog(
                    context: ctx,
                    builder: (d) => AlertDialog(
                      backgroundColor: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Fix these issues',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        errors.take(6).join('\n'),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(d),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                int added = 0;
                final existingKeys = courses
                    .map((c) => '${c.name}_${c.unit}')
                    .toSet();
                for (final i in filled) {
                  final code = rows[i]['code']!.text.trim().toUpperCase();
                  final name = rows[i]['name']!.text.trim();
                  final unit = int.parse(rows[i]['unit']!.text.trim());
                  final int score;
                  if (useGrade) {
                    final grade = gradeSelections[i]!;
                    final rule = grading.rules.firstWhere(
                      (r) => r.grade == grade,
                      orElse: () =>
                          GradeRule(grade: 'F', minScore: 0, gradePoint: 0),
                    );
                    score = rule.minScore;
                  } else {
                    score = int.parse(rows[i]['score']!.text.trim());
                  }
                  final key = '${code}_$unit';
                  if (existingKeys.contains(key)) continue;
                  courses.add(
                    Course(code, name, score, unit, _selYear, _selSem),
                  );
                  existingKeys.add(key);
                  added++;
                }

                setState(() => currentPage = _pageIndex);
                if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(currentPage);
                _saveCourses();
                Navigator.pop(ctx);

                final skipped = filled.length - added;
                final msg = added == 0
                    ? 'All courses already saved — no duplicates added'
                    : '$added course${added > 1 ? 's' : ''} added ✓'
                          '${skipped > 0 ? ' ($skipped duplicate${skipped > 1 ? 's' : ''} skipped)' : ''}';
                AppSnackBar.showSuccess(context, msg);
              }

              final filledCount = rows
                  .where((r) => r['code']!.text.trim().isNotEmpty)
                  .length;

              Widget headerCell(String t, {int flex = 2}) => Expanded(
                flex: flex,
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.blue.shade300
                        : Colors.blue.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );

              return Column(
                children: [
                  sheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.table_rows_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manual Batch Entry',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Year $_selYear • Semester $_selSem  —  ${rows.length} row${rows.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: labelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _inputModeToggle(
                          useGrade: useGrade,
                          onChanged: (v) => setSheet(() => useGrade = v),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        headerCell('Course Name', flex: 2),
                        const SizedBox(width: 6),
                        headerCell('Code', flex: 2),
                        const SizedBox(width: 6),
                        headerCell('Unit', flex: 1),
                        const SizedBox(width: 6),
                        headerCell(useGrade ? 'Grade' : 'Score', flex: 2),
                        const SizedBox(width: 6),
                        const SizedBox(width: 28),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row['name'],
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: cellDec('Name'),
                                  onChanged: (_) => setSheet(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row['code'],
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: cellDec('e.g. MTH101'),
                                  onChanged: (_) => setSheet(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: row['unit'],
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: cellDec('1–6'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: useGrade
                                    ? DropdownButtonHideUnderline(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: fillColor,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            value: gradeSelections[i],
                                            isExpanded: true,
                                            isDense: true,
                                            hint: Text(
                                              'Grade',
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.grey.shade600
                                                    : Colors.grey.shade400,
                                                fontSize: 12,
                                              ),
                                            ),
                                            dropdownColor: isDarkMode
                                                ? const Color(0xFF2A2A2A)
                                                : Colors.white,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                            ),
                                            items: gradeLetters
                                                .map(
                                                  (g) => DropdownMenuItem(
                                                    value: g,
                                                    child: Text(
                                                      g,
                                                      style: TextStyle(
                                                        color: textColor,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setSheet(
                                              () => gradeSelections[i] = v,
                                            ),
                                          ),
                                        ),
                                      )
                                    : TextField(
                                        controller: row['score'],
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                        ),
                                        decoration: cellDec('0–100'),
                                      ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: rows.length > 1
                                    ? () => removeRow(i)
                                    : null,
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  size: 22,
                                  color: rows.length > 1
                                      ? Colors.red.shade400
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF121212)
                          : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: addRow,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: Colors.blue,
                            ),
                            label: const Text(
                              'Add Row',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: saveAll,
                              icon: const Icon(Icons.save_alt),
                              label: Text(
                                filledCount == 0
                                    ? 'Save Courses'
                                    : 'Save $filledCount Course${filledCount != 1 ? 's' : ''}',
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  WHAT-IF
  // ══════════════════════════════════════════════════════════

  void _showWhatIf() {
    if (courses.isEmpty) {
      AppSnackBar.showInfo(context, 'Add courses first to use the simulator.');
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
                sheetHandle(),
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
  //  TARGET CGPA
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
      for (final rem in [15, 20, 30, 40, 50, 60]) {
        final needed = (target * (curUnits + rem) - curTotal) / rem;
        if (needed > maxGP) {
          sc.add('• With $rem more units: Not achievable');
        } else if (needed <= 0) {
          sc.add('• With $rem more units: Already achievable ✓');
        } else {
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
            'Target CGPA  : ${target.toStringAsFixed(2)}\n'
            'Gap          : ${gap.toStringAsFixed(2)} GP\n\n'
            'What you need:\n${sc.join('\n')}';
        emoji = '🎯';
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final textColor = isDarkMode ? Colors.white : Colors.black87;
          final labelColor = isDarkMode ? Colors.white70 : Colors.black54;
          final fillColor = isDarkMode
              ? const Color(0xFF2A2A2A)
              : Colors.grey.shade50;
          final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          final resultBg = isDarkMode
              ? Colors.teal.withOpacity(0.15)
              : Colors.teal.withOpacity(0.08);

          return AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.track_changes, color: Colors.teal),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Target CGPA Calculator',
                    style: TextStyle(color: textColor),
                  ),
                ),
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
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText:
                          'Desired CGPA (max ${maxGP.toStringAsFixed(1)})',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: const Icon(
                        Icons.flag_outlined,
                        color: Colors.teal,
                      ),
                      filled: true,
                      fillColor: fillColor,
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
                        color: resultBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$emoji  $result',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: textColor,
                        ),
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
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  MINIMUM SCORE CALCULATOR
  // ══════════════════════════════════════════════════════════

  void _showMinScoreCalc() {
    if (courses.isEmpty) {
      AppSnackBar.showInfo(context, 'Add courses first to use this tool.');
      return;
    }

    final targetCtrl = TextEditingController();
    final extraUnitsCtrl = TextEditingController();
    String result = '';
    String emoji = '';

    void compute(void Function(void Function()) setD) {
      final targetCgpa = double.tryParse(targetCtrl.text.trim());
      final extraUnits = int.tryParse(extraUnitsCtrl.text.trim());

      if (targetCgpa == null || targetCgpa <= 0 || targetCgpa > maxGP) {
        setD(() {
          result =
              'Enter a valid target CGPA between 0.01 and ${maxGP.toStringAsFixed(1)}.';
          emoji = '⚠️';
        });
        return;
      }
      if (extraUnits == null || extraUnits <= 0) {
        setD(() {
          result = 'Enter the number of remaining credit units (must be > 0).';
          emoji = '⚠️';
        });
        return;
      }

      final currentTotalGP = courses.fold(
        0.0,
        (s, c) => s + grading.getPoint(c.score) * c.unit,
      );
      final currentUnits = totalUnits;
      final neededGP =
          (targetCgpa * (currentUnits + extraUnits) - currentTotalGP) /
          extraUnits;

      if (neededGP <= 0) {
        setD(() {
          result =
              'Great news! Your current CGPA (${cgpa.toStringAsFixed(2)}) already exceeds '
              'or will naturally reach ${targetCgpa.toStringAsFixed(2)} with $extraUnits more units '
              'even if you score 0 in all remaining courses. Keep it up!';
          emoji = '🎉';
        });
        return;
      }

      if (neededGP > maxGP) {
        final maxPoss =
            (currentTotalGP + maxGP * extraUnits) / (currentUnits + extraUnits);
        setD(() {
          result =
              'Not achievable with $extraUnits units.\n'
              'Max possible CGPA: ${maxPoss.toStringAsFixed(2)}\n\n'
              'Consider increasing your remaining units or lowering your target CGPA.';
          emoji = '❌';
        });
        return;
      }

      final sortedRules = List.of(grading.rules)
        ..sort((a, b) => a.gradePoint.compareTo(b.gradePoint));
      GradeRule? targetRule;
      for (final r in sortedRules) {
        if (r.gradePoint >= neededGP - 0.001) {
          targetRule = r;
          break;
        }
      }
      final gradeNeeded = targetRule?.grade ?? 'F';
      final minScoreNeeded = targetRule?.minScore ?? 0;
      final maxPossibleCgpa =
          (currentTotalGP + maxGP * extraUnits) / (currentUnits + extraUnits);

      setD(() {
        result =
            'Current CGPA       : ${cgpa.toStringAsFixed(2)}\n'
            'Target CGPA        : ${targetCgpa.toStringAsFixed(2)}\n'
            'Remaining Units    : $extraUnits\n\n'
            'You need an average GP of ${neededGP.toStringAsFixed(2)} per unit.\n\n'
            'Minimum grade required: $gradeNeeded  (score ≥ $minScoreNeeded) in every remaining course.\n\n'
            'Max achievable CGPA with $extraUnits units: ${maxPossibleCgpa.toStringAsFixed(2)}';
        emoji = '📊';
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final textColor = isDarkMode ? Colors.white : Colors.black87;
          final labelColor = isDarkMode ? Colors.white70 : Colors.black54;
          final fillColor = isDarkMode
              ? const Color(0xFF2A2A2A)
              : Colors.grey.shade50;
          final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          final resultBg = isDarkMode
              ? Colors.indigo.withOpacity(0.15)
              : Colors.indigo.withOpacity(0.07);

          return AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Min Score Calculator',
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Find the minimum score you need in remaining courses to reach your target CGPA.',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText:
                          'Target CGPA (max ${maxGP.toStringAsFixed(1)})',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: const Icon(
                        Icons.flag_outlined,
                        color: Colors.indigo,
                      ),
                      filled: true,
                      fillColor: fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: extraUnitsCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Remaining Credit Units',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: const Icon(
                        Icons.library_books_outlined,
                        color: Colors.indigo,
                      ),
                      filled: true,
                      fillColor: fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: 'Total units of courses not yet taken',
                      helperStyle: TextStyle(color: labelColor, fontSize: 11),
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
                        backgroundColor: Colors.indigo,
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
                        color: resultBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$emoji  $result',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: textColor,
                        ),
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
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  GRADING MODEL SETTINGS
  // ══════════════════════════════════════════════════════════

  void _showGradingSettings() {
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

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final labelColor = isDarkMode ? Colors.white70 : Colors.black54;
    final fillColor = isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.grey.shade50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.tune, color: Colors.blue),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Grading System',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
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
                          AppSnackBar.showSuccess(
                            context,
                            '5.0 scale preset applied',
                          );
                        },
                        child: Text(
                          '5.0 Scale Preset',
                          style: TextStyle(color: textColor),
                        ),
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
                          ProfileService()
                              .updateGrading(
                                grading.rules
                                    .map(
                                      (r) => {
                                        'grade': r.grade,
                                        'minScore': r.minScore,
                                        'gradePoint': r.gradePoint,
                                      },
                                    )
                                    .toList(),
                              )
                              .catchError(
                                (e) => debugPrint(
                                  'Grading server save failed: $e',
                                ),
                              );
                          AppSnackBar.showSuccess(
                            context,
                            '4.0 scale preset applied',
                          );
                        },
                        child: Text(
                          '4.0 Scale Preset',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Flexible(
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
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: isF ? 'Below all' : 'Min score',
                                  labelStyle: TextStyle(color: labelColor),
                                  filled: true,
                                  fillColor: fillColor,
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
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Grade Point',
                                  labelStyle: TextStyle(color: labelColor),
                                  filled: true,
                                  fillColor: fillColor,
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                      AppSnackBar.showSuccess(
                        context,
                        'Grading system updated ✓',
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
              SafeArea(top: false, child: const SizedBox(height: 8)),
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
      if (mounted) AppSnackBar.showError(context, 'Could not share image');
    }
  }



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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
                maxY: maxGP > 0 ? maxGP : 5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxGP > 0 ? maxGP / 5 : 1,
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
                      interval: maxGP > 0 ? maxGP / 5 : 1,
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
  //  SUMMARY
  // ══════════════════════════════════════════════════════════

  Widget _buildSummary() {
    final top = topCourse;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
                    _cgpaHidden ? '••••' : cgpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_cgpaHidden)
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
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportPDF,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _statCard(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════════
  //  COURSES TAB
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
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
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
                                _cgpaHidden
                                    ? 'GPA: ••••'
                                    : 'GPA: ${gpa.toStringAsFixed(2)}',
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
                                  40,
                                ),
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

  Widget _dismissible(Course c) {
    final idx = courses.indexOf(c);
    return Dismissible(
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
        return true;
      },
      onDismissed: (_) => _deleteCourse(c, atIndex: idx),
      child: _courseCard(c),
    );
  }

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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          if (_editingCourse != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Editing: ${_editingCourse!.name} — save to confirm or switch tabs to cancel.',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Icon(
                      Icons.close,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

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
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showManualBatchEntry,
                      icon: const Icon(Icons.table_rows_outlined),
                      label: const Text('Enter Courses Manually'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'or scan result sheet',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _scanResultSheet,
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Scan Result Sheet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

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
              const SizedBox(width: 8),
              Expanded(
                child: _toolBtn(
                  Icons.track_changes,
                  'Target',
                  Colors.teal,
                  _showTargetCalc,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toolBtn(
                  Icons.calculate_outlined,
                  'Min Score',
                  Colors.indigo,
                  _showMinScoreCalc,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toolBtn(
                  Icons.tune,
                  'Grading',
                  Colors.orange,
                  _showGradingSettings,
                ),
              ),
              const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );



  Widget _buildClearAllTab() {
  final isDark = context.read<ThemeNotifier>().isDarkMode;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_forever_rounded, size: 64,
              color: Colors.red.withOpacity(0.7)),
          const SizedBox(height: 16),
          const Text('Clear All Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'This will permanently delete all your courses.\nThis cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Clear All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ══════════════════════════════════════════════════════════
  //  MAIN BUILD
  // ══════════════════════════════════════════════════════════

@override
Widget build(BuildContext context) {
  final isDark = context.watch<ThemeNotifier>().isDarkMode;
  final navBg = isDark ? const Color(0xFF1E293B) : Colors.white;
  final navFg = isDark ? Colors.white : Colors.black87;

  return Scaffold(
    backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.blue.shade50,
    appBar: AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor: navBg,
      foregroundColor: navFg,
      iconTheme: IconThemeData(color: navFg),
      title: Text(
        'CGPA Calculator',
        style: TextStyle(color: navFg, fontWeight: FontWeight.bold),
      ),
      bottom: TabBar(
        controller: _tabCtrl,
        isScrollable: false,
        labelColor: isDark ? const Color(0xFF818CF8) : Colors.blue.shade700,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
        indicatorColor: isDark ? const Color(0xFF818CF8) : Colors.blue.shade700,
        tabs: [
          const Tab(icon: Icon(Icons.add_circle_outline, size: 20), text: 'Add'),
          const Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Courses'),
          const Tab(icon: Icon(Icons.show_chart, size: 20), text: 'Chart'),
          const Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Summary'),
          Tab(
            icon: const Icon(Icons.delete_forever, size: 20),
            text: 'Clear All',
            iconMargin: EdgeInsets.zero,
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.indigo.shade900],
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall CGPA',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      _cgpaHidden ? '••••' : cgpa.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 160,
                  child: _cgpaHidden
                      ? const SizedBox()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
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
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: degreeColor(cgpa, maxGP),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _cgpaHidden ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _cgpaHidden = !_cgpaHidden);
                    _savePref('cgpaHidden', _cgpaHidden);
                  },
                  tooltip: _cgpaHidden ? 'Show CGPA' : 'Hide CGPA',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                _buildClearAllTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
