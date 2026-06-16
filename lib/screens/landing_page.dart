
// ══════════════════════════════════════════════════════════
//  LANDING PAGE
// ══════════════════════════════════════════════════════════


import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gradex/screens/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import 'registerscreen.dart';
import 'signinscreen.dart';
import 'homescreen.dart';
import '../widgets/google_button.dart';
import '../models/studentProfile_model.dart';
import '../widgets/ui_helpers.dart';
import '../widgets/snackBar.dart';
import 'dart:convert';


class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> fadeAnim;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: SafeArea(
        child: FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  iconCircle(Icons.school, 110, 60),
                  const SizedBox(height: 28),
                  const Text(
                    'Gradex',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _featurePill(Icons.track_changes_outlined, 'Track CGPA'),
                      _featurePill(Icons.science_outlined, 'What-If Sim'),
                      _featurePill(Icons.picture_as_pdf_outlined, 'PDF Export'),
                      _featurePill(Icons.show_chart, 'GPA Trends'),
                    ],
                  ),
                  const Spacer(flex: 3),

                  // ── Sign In ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(fadeRoute(const SignInScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Create Account ───────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(fadeRoute(const RegisterScreen())),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white54,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Continue with Google ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: GoogleButton(
                      onPressed: () => _handleGoogleSignIn(context),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Developed by TRIMAX',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _handleGoogleSignIn(BuildContext context) async {
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
        AppSnackBar.showError(context, 'Google sign-in failed. Try again.');
        return;
      }

      final userData = await AuthService().loginWithGoogle(idToken: idToken);

      if (userData['profile'] != null) {
        final profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile', jsonEncode(profile.toMap()));
      }

      if (!context.mounted) return;
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
    }
  }

  Widget _featurePill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );
}
