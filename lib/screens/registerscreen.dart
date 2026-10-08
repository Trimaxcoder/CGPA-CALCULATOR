// ══════════════════════════════════════════════════════════
//  REGISTER SCREEN  (3-step wizard). RENAME FROM LOGINSCREEN WITH PASSWORD
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

import 'main_shell.dart';
import '../widgets/ui_helpers.dart';
import '../models/studentProfile_model.dart';
import '../uniport_courses.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';

import '../widgets/combo_field.dart';
import 'signinscreen.dart';
import '../widgets/google_button.dart';
import '../widgets/snackBar.dart';
import '../widgets/preloader.dart';
import 'landing_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  static const _totalSteps = 3;
  static const Color _blue = Color(0xFF1565C0);

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _matricC = TextEditingController();
  final _schoolC = TextEditingController();
  final _facC = TextEditingController();
  final _deptC = TextEditingController();
  String _selectedLevel = '100';
  static const _levels = ['100', '200', '300', '400', '500', '600', '700'];
  final _passC = TextEditingController();
  final _confirmPassC = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _step1Valid = false;
  bool _step2Valid = false;
  bool _step3Valid = false;

  List<String> get _schools => getAllSchools();
  List<String> get _faculties => getFaculties();
  List<String> get _depts =>
      _facC.text.trim().isNotEmpty ? getDepartments(_facC.text.trim()) : [];

  @override
  void initState() {
    super.initState();
    _nameC.addListener(_revalidateStep1);
    _emailC.addListener(_revalidateStep1);
    _matricC.addListener(_revalidateStep1);
    _passC.addListener(_revalidateStep2);
    _confirmPassC.addListener(_revalidateStep2);
    _schoolC.addListener(_revalidateStep3);
    _facC.addListener(_revalidateStep3);
    _deptC.addListener(_revalidateStep3);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameC.dispose();
    _emailC.dispose();
    _matricC.dispose();
    _schoolC.dispose();
    _facC.dispose();
    _deptC.dispose();
    _passC.dispose();
    _confirmPassC.dispose();
    super.dispose();
  }

  // ── Live validation (drives Next-button enabled state) ─────
  void _revalidateStep1() {
    final valid =
        _nameC.text.trim().split(' ').where((s) => s.isNotEmpty).length >= 2 &&
        _emailC.text.trim().contains('@') &&
        isValidEmail(_emailC.text.trim()) &&
        _matricC.text.trim().isNotEmpty;
    if (valid != _step1Valid) setState(() => _step1Valid = valid);
  }

  void _revalidateStep2() {
    final pass = _passC.text.trim();
    final confirm = _confirmPassC.text.trim();
    final valid = pass.length >= 6 && confirm.isNotEmpty && pass == confirm;
    if (valid != _step2Valid) setState(() => _step2Valid = valid);
  }

  void _revalidateStep3() {
    final valid =
        _schoolC.text.trim().isNotEmpty &&
        _findBestMatch(_schoolC.text, _schools) != null &&
        _facC.text.trim().isNotEmpty &&
        _findBestMatch(_facC.text, _faculties) != null &&
        _deptC.text.trim().isNotEmpty &&
        _findBestMatch(_deptC.text, _depts) != null;
    if (valid != _step3Valid) setState(() => _step3Valid = valid);
  }

  String? _findBestMatch(String input, List<String> options) {
    final query = input.toLowerCase().trim();
    if (query.isEmpty) return null;

    for (final opt in options) {
      if (opt.toLowerCase().trim() == query) return opt;
    }

    final substringMatches = options
        .where((opt) => opt.toLowerCase().contains(query))
        .toList();
    if (substringMatches.length == 1) return substringMatches.first;

    if (substringMatches.isEmpty) {
      final reverseMatches = options
          .where((opt) => query.contains(opt.toLowerCase()))
          .toList();
      if (reverseMatches.length == 1) return reverseMatches.first;
    }

    final wordMatches = options.where((opt) {
      final words = opt.toLowerCase().split(RegExp(r'\s+'));
      return words.any((w) => w.startsWith(query) || query.startsWith(w));
    }).toList();
    if (wordMatches.length == 1) return wordMatches.first;

    return null;
  }

  // ── Navigation between steps ────────────────────────────────
  void _goNext() {
    final formKey = _currentStep == 0
        ? _step1Key
        : (_currentStep == 1 ? _step2Key : _step3Key);
    formKey.currentState?.validate();

    final isValid = _currentStep == 0
        ? _step1Valid
        : (_currentStep == 1 ? _step2Valid : _step3Valid);
    if (!isValid) return;

    if (_currentStep < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.of(context).pushReplacement(fadeRoute(const LandingPage()));
    } else {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _goSignIn() =>
      Navigator.of(context).pushReplacement(fadeRoute(const SignInScreen()));

  Future<void> _submit() async {
    if (!_step3Key.currentState!.validate()) return;
    setState(() => _loading = true);

    final canonicalSchool =
        _findBestMatch(_schoolC.text, _schools) ?? _schoolC.text.trim();
    final canonicalFaculty =
        _findBestMatch(_facC.text, _faculties) ?? _facC.text.trim();
    final canonicalDept =
        _findBestMatch(_deptC.text, _depts) ?? _deptC.text.trim();

    final profileData = {
      'name': _nameC.text.trim(),
      'email': _emailC.text.trim(),
      'matricNumber': _matricC.text.trim(),
      'school': canonicalSchool,
      'faculty': canonicalFaculty,
      'department': canonicalDept,
      'level': _selectedLevel,
    };

    final profile = StudentProfile(
      name: profileData['name']!,
      email: profileData['email']!,
      matricNumber: profileData['matricNumber']!,
      school: profileData['school']!,
      faculty: profileData['faculty']!,
      department: profileData['department']!,
      level: profileData['level']!,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toMap()));

    try {
      await AuthService().register(
        email: profileData['email']!,
        password: _passC.text.trim(),
        profile: profileData,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        try {
          await AuthService().login(
            email: profileData['email']!,
            password: _passC.text.trim(),
          );
        } catch (_) {}
      } else {
        debugPrint('Server register warning: ${e.message}');
      }
    } catch (_) {
      // Offline — will sync later
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => PreloaderScreen(),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId:
            '36781799836-r0fa4p6ogpj2u45k670vvh5p5fqrc4vb.apps.googleusercontent.com',
      );

      if (!kIsWeb) await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        if (mounted)
          AppSnackBar.showError(context, 'Google sign-in failed. Try again.');
        return;
      }

      setState(() => _loading = true);

      final userData = await AuthService().loginWithGoogle(idToken: idToken);

      if (userData['profile'] != null) {
        final profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile', jsonEncode(profile.toMap()));
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } catch (e, stack) {
      debugPrint('Google sign-in error: $e\n$stack');
      if (mounted)
        AppSnackBar.showError(context, 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _currentButtonEnabled => _currentStep == 0
      ? _step1Valid
      : (_currentStep == 1 ? _step2Valid : _step3Valid);

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: context.isExpanded ? _buildDesktop() : _buildMobile());

  // ── Phone / tablet (original design) ──────────────────────
  Widget _buildMobile() => SizedBox.expand(
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // ── Top bar: back + progress ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _goBack,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _progressBar(light: false)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Step pages ──
                Expanded(child: _pages(light: false)),

                // ── Bottom Next/Create button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
                  child: _nextButton(light: false),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _pages({required bool light}) => PageView(
    controller: _pageCtrl,
    physics: const NeverScrollableScrollPhysics(),
    onPageChanged: (i) => setState(() => _currentStep = i),
    children: [
      _buildStep1(light),
      _buildStep2(light),
      _buildStep3(light),
    ],
  );

  Widget _nextButton({required bool light}) {
    final label = _currentStep < _totalSteps - 1 ? 'Next' : 'Create Account';
    final enabled = _currentButtonEnabled;

    if (light) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (_loading || !enabled) ? null : _goNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black12,
            disabledForegroundColor: Colors.black38,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: (_loading || !enabled) ? null : _goNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF0D47A1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0D47A1),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _progressBar({required bool light}) {
    return Row(
      children: List.generate(_totalSteps, (i) {
        final isActive = i <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
            height: 5,
            decoration: BoxDecoration(
              color: isActive
                  ? (light ? _blue : Colors.white)
                  : (light ? Colors.black12 : Colors.white.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DESKTOP (>= 1024 px): split screen with a step tracker
  // ══════════════════════════════════════════════════════════
  Widget _buildDesktop() => Row(
    children: [
      Expanded(flex: 6, child: _desktopHero()),
      Expanded(flex: 4, child: _desktopPanel()),
    ],
  );

  static const _stepInfo = [
    ('Personal info', 'Your name, email and matric number'),
    ('Security', 'Choose a password'),
    ('Academic details', 'School, faculty, department and level'),
  ];

  Widget _desktopHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -140,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight < 700 ? 700.0 : c.maxHeight;
                return SingleChildScrollView(
                  child: SizedBox(
                    height: h,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(60, 48, 60, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text(
                                    'S',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: _blue,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                'SCHOOLLIFE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Create your\naccount.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'It takes about a minute. Three quick steps and\nyou are in.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: [
                                for (var i = 0; i < _stepInfo.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _stepTile(i),
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Developed by TRIMAX',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
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
  }

  Widget _stepTile(int i) {
    final done = i < _currentStep;
    final current = i == _currentStep;
    final info = _stepInfo[i];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: current
            ? Colors.white.withOpacity(0.18)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current
              ? Colors.white.withOpacity(0.5)
              : Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done || current)
                  ? Colors.white
                  : Colors.white.withOpacity(0.15),
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: _blue, size: 22)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: current ? _blue : Colors.white70,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.$1,
                  style: TextStyle(
                    color: Colors.white.withOpacity(current || done ? 1 : 0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.$2,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopPanel() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 6),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                        label: const Text(
                          'Back',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black54,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: _progressBar(light: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _pages(light: true)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 28),
                  child: _nextButton(light: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEPS  (light = true on the desktop white panel)
  // ══════════════════════════════════════════════════════════
  Color _titleColor(bool light) =>
      light ? const Color(0xFF0D1B2A) : Colors.white;
  Color _subColor(bool light) => light ? Colors.black45 : Colors.white70;

  // ── Step 1: Personal Info ───────────────────────────────────
  Widget _buildStep1(bool light) {
    final dividerColor = light ? Colors.black12 : Colors.white.withOpacity(0.2);
    final orColor = light ? Colors.black38 : Colors.white.withOpacity(0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 40),
      child: Form(
        key: _step1Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!light) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1565C0),
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Create Account',
              style: TextStyle(
                color: _titleColor(light),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step 1 of 3 — tell us about yourself',
              style: TextStyle(color: _subColor(light), fontSize: 13),
            ),
            const SizedBox(height: 28),
            _field(
              _nameC,
              'Full Name',
              Icons.person_outline,
              light: light,
              cap: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Full name is required';
                if (v.trim().split(' ').where((s) => s.isNotEmpty).length < 2)
                  return 'Enter first and last name';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              _emailC,
              'Email Address',
              Icons.email_outlined,
              light: light,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.trim().contains('@')) return 'Email must contain @';
                if (!isValidEmail(v.trim()))
                  return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              _matricC,
              'Matric Number',
              Icons.badge_outlined,
              light: light,
              cap: TextCapitalization.characters,
              onSubmit: (_) => _goNext(),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Matric number is required';
                return null;
              },
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: Divider(color: dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(color: orColor, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(color: dividerColor)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: light
                  ? Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: GoogleButton(onPressed: _handleGoogleSignIn),
                    )
                  : GoogleButton(onPressed: _handleGoogleSignIn),
            ),
            const SizedBox(height: 28),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?  ',
                    style: TextStyle(
                      color: light ? Colors.black45 : Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: _goSignIn,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: light ? _blue : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: light ? _blue : Colors.white,
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
    );
  }

  // ── Step 2: Security ────────────────────────────────────────
  Widget _buildStep2(bool light) {
    final fieldText = light ? Colors.black87 : Colors.white;
    final dec = light ? _decLight : _dec;
    final eye = light ? Colors.black38 : Colors.white60;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 40),
      child: Form(
        key: _step2Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secure your account',
              style: TextStyle(
                color: _titleColor(light),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step 2 of 3 — choose a password',
              style: TextStyle(color: _subColor(light), fontSize: 13),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _passC,
              obscureText: _obscurePass,
              style: TextStyle(color: fieldText),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Password is required';
                if (v.trim().length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
              decoration: dec('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                    color: eye,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassC,
              obscureText: _obscureConfirm,
              style: TextStyle(color: fieldText),
              onFieldSubmitted: (_) => _goNext(),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please confirm your password';
                if (v.trim() != _passC.text.trim())
                  return 'Passwords do not match';
                return null;
              },
              decoration: dec('Confirm Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: eye,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Password must be at least 6 characters',
              style: TextStyle(
                color: light ? Colors.black38 : Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Academic Info ───────────────────────────────────
  Widget _buildStep3(bool light) {
    final dec = light ? _decLight : _dec;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 40),
      child: Form(
        key: _step3Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic details',
              style: TextStyle(
                color: _titleColor(light),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step 3 of 3 — almost done',
              style: TextStyle(color: _subColor(light), fontSize: 13),
            ),
            const SizedBox(height: 28),
            // ComboField: dark = true means dark text on a light background
            ComboField(
              controller: _schoolC,
              label: 'School / University',
              icon: Icons.account_balance,
              suggestions: _schools,
              dark: light,
              onSuggestionSelected: (_) {
                setState(() {
                  _facC.clear();
                  _deptC.clear();
                });
                _revalidateStep3();
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your school';
                if (_findBestMatch(v, _schools) == null)
                  return 'Please select a valid school from the list';
                return null;
              },
            ),
            const SizedBox(height: 14),
            ComboField(
              controller: _facC,
              label: 'Faculty',
              icon: Icons.account_balance_outlined,
              suggestions: _faculties,
              dark: light,
              onSuggestionSelected: (_) {
                setState(() => _deptC.clear());
                _revalidateStep3();
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your faculty';
                if (_findBestMatch(v, _faculties) == null)
                  return 'Please select a valid faculty from the list';
                return null;
              },
            ),
            const SizedBox(height: 14),
            ComboField(
              controller: _deptC,
              label: 'Department',
              icon: Icons.school_outlined,
              suggestions: _depts,
              dark: light,
              onSuggestionSelected: (_) => _revalidateStep3(),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Enter your department';
                if (_findBestMatch(v, _depts) == null)
                  return 'Please select a valid department from the list';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              onChanged: (v) => setState(() => _selectedLevel = v!),
              style: TextStyle(color: light ? Colors.black87 : Colors.white),
              dropdownColor: light ? Colors.white : const Color(0xFF0D47A1),
              decoration: dec('Level', Icons.stairs_outlined),
              items: _levels
                  .map(
                    (l) =>
                        DropdownMenuItem(value: l, child: Text('$l Level')),
                  )
                  .toList(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Select your level' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    required bool light,
    TextInputType? keyboardType,
    TextCapitalization cap = TextCapitalization.none,
    String? Function(String?)? validator,
    ValueChanged<String>? onSubmit,
  }) => TextFormField(
    controller: ctrl,
    style: TextStyle(color: light ? Colors.black87 : Colors.white),
    keyboardType: keyboardType,
    textCapitalization: cap,
    validator: validator,
    onFieldSubmitted: onSubmit,
    decoration: light ? _decLight(label, icon) : _dec(label, icon),
  );

  // Light-on-gradient decoration (phone)
  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white, width: 1.5),
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

  // Light decoration (desktop white panel)
  InputDecoration _decLight(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _blue, size: 18),
    ),
    filled: true,
    fillColor: const Color(0xFFF5F7FA),
    labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: _blue, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400, width: 2),
    ),
    errorStyle: TextStyle(color: Colors.red.shade600),
  );
}

// ──────────────────────────────────────────────────────────
//  Alias so existing code that refers to LoginScreen still compiles
// ──────────────────────────────────────────────────────────
typedef LoginScreen = RegisterScreen;