// ══════════════════════════════════════════════════════════
//  REGISTER SCREEN  (renamed from LoginScreen, with password)
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';

import 'dart:async';
import 'main_shell.dart';
import '../widgets/ui_helpers.dart';
import '../models/studentProfile_model.dart';
import '../uniport_courses.dart';
import '../services/api_service.dart';

import '../widgets/combo_field.dart';
import 'signinscreen.dart';
import '../widgets/google_button.dart';
import '../widgets/snackBar.dart';
import '../widgets/preloader.dart';
import 'homescreen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fk = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _matricC = TextEditingController();
  final _schoolC = TextEditingController();
  final _facC = TextEditingController();
  final _deptC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmPassC = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  List<String> get _schools => getAllSchools();
  List<String> get _faculties => getFaculties();
  List<String> get _depts =>
      _facC.text.trim().isNotEmpty ? getDepartments(_facC.text.trim()) : [];

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);

    final profileData = {
      'name': _nameC.text.trim(),
      'email': _emailC.text.trim(),
      'matricNumber': _matricC.text.trim(),
      'school': _schoolC.text.trim(),
      'faculty': _facC.text.trim(),
      'department': _deptC.text.trim(),
    };

    final profile = StudentProfile(
      name: profileData['name']!,
      email: profileData['email']!,
      matricNumber: profileData['matricNumber']!,
      school: profileData['school']!,
      faculty: profileData['faculty']!,
      department: profileData['department']!,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toMap()));

    try {
      await AuthService().register(
        email: profileData['email']!,
        password: _passC.text.trim(), // use the user's chosen password
        profile: profileData,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Already registered — try signing in
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

      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled

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
      print("=== API ERROR: ${e.message}");
      if (mounted) AppSnackBar.showError(context, e.message);
    } catch (e, stack) {
      print("=== GOOGLE ERROR: $e");
      print("=== STACK: $stack");
      if (mounted)
        AppSnackBar.showError(context, 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Keep LoginScreen as alias so existing code compiles ──
  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          child: Form(
            key: _fk,
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white70,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 16),

                iconCircle(Icons.school, 76, 38),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your details to get started',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 28),

                _field(
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
                _field(
                  _emailC,
                  'Email Address',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!v.trim().contains('@')) return 'Email must contain @';
                    if (!isValidEmail(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
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

                // Password
                TextFormField(
                  controller: _passC,
                  obscureText: _obscurePass,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Password is required';
                    if (v.trim().length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                  decoration: _dec('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: Colors.blue.shade300,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmPassC,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please confirm your password';
                    if (v.trim() != _passC.text.trim())
                      return 'Passwords do not match';
                    return null;
                  },
                  decoration: _dec('Confirm Password', Icons.lock_outline)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.blue.shade300,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: 14),

                ComboField(
                  controller: _schoolC,
                  label: 'School / University',
                  icon: Icons.account_balance,
                  suggestions: _schools,
                  dark: false,
                  onSuggestionSelected: (_) => setState(() {
                    _facC.clear();
                    _deptC.clear();
                  }),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your school'
                      : null,
                ),
                const SizedBox(height: 14),
                ComboField(
                  controller: _facC,
                  label: 'Faculty',
                  icon: Icons.account_balance_outlined,
                  suggestions: _faculties,
                  dark: false,
                  onSuggestionSelected: (_) => setState(() => _deptC.clear()),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your faculty'
                      : null,
                ),
                const SizedBox(height: 14),
                ComboField(
                  controller: _deptC,
                  label: 'Department',
                  icon: Icons.school_outlined,
                  suggestions: _depts,
                  dark: false,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your department'
                      : null,
                ),
                const SizedBox(height: 32),

                // Submit
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                orDivider(),
                const SizedBox(height: 16),

                // Continue with Google
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: GoogleButton(onPressed: _handleGoogleSignIn),
                ),
                const SizedBox(height: 28),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?  ',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushReplacement(fadeRoute(const SignInScreen())),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.blue.shade200,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue.shade200,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    TextCapitalization cap = TextCapitalization.none,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white),
    keyboardType: keyboardType,
    textCapitalization: cap,
    validator: validator,
    decoration: _dec(label, icon),
  );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
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




// ──────────────────────────────────────────────────────────
//  Alias so existing code that refers to LoginScreen still compiles
// ──────────────────────────────────────────────────────────
typedef LoginScreen = RegisterScreen;

