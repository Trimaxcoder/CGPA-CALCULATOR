// ══════════════════════════════════════════════════════════
//  LANDING PAGE
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gradex/screens/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import 'registerscreen.dart';
import 'signinscreen.dart';
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

  static const Color _blue = Color(0xFF1565C0);

  // Feature list shared by the phone pills and the desktop cards
  static const _features = [
    (Icons.track_changes_outlined, 'Track CGPA', 'GPA for every semester'),
    (Icons.science_outlined, 'What-If Sim', 'Simulate different scores'),
    (Icons.picture_as_pdf_outlined, 'PDF Export', 'Download your transcript'),
    (Icons.show_chart, 'GPA Trends', 'See your progress over time'),
    (Icons.calendar_month_outlined, 'Timetable', 'Lectures and study sessions'),
    (Icons.notifications_active_outlined, 'Class Alerts', 'Never miss a class'),
    (Icons.event_note_outlined, 'Exam Countdown', 'Days left to every exam'),
    (Icons.bookmark_outline, 'Study Reminders', 'Bookmark and get reminded'),
  ];

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
  Widget build(BuildContext context) {
    final desktop = context.isExpanded;

    return Scaffold(
      body: FadeTransition(
        opacity: fadeAnim,
        child: SlideTransition(
          position: _slide,
          child: desktop ? _buildDesktop() : _buildMobile(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PHONE / TABLET (original design)
  // ══════════════════════════════════════════════════════════
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
        child: LayoutBuilder(
          builder: (context, c) {
            // Scrolls (instead of overflowing) on short screens
            final h = c.maxHeight < 700 ? 700.0 : c.maxHeight;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SizedBox(
                    height: h,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // ── Big S Logo ──────────────────────────────
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'S',
                                style: TextStyle(
                                  fontSize: 58,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1565C0),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── App name ────────────────────────────────
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SCHOOLLIFE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Track your academic performance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Feature pills ────────────────────────────
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final f in _features)
                                _featurePill(f.$1, f.$2),
                            ],
                          ),

                          const Spacer(flex: 3),

                          // ── Sign In ──────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).push(fadeRoute(const SignInScreen())),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D47A1),
                                elevation: 4,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Create Account ───────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E88E5),
                                    Color(0xFF0D47A1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).push(fadeRoute(const RegisterScreen())),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Continue with Google ─────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: GoogleButton(
                              onPressed: () => _handleGoogleSignIn(context),
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Text(
                            'Developed by TRIMAX',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  DESKTOP (screens >= 1024 px): split screen
  // ══════════════════════════════════════════════════════════
  Widget _buildDesktop() => Row(
    children: [
      Expanded(flex: 6, child: _desktopHero()),
      Expanded(flex: 4, child: _desktopPanel()),
    ],
  );

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
          // decorative circles
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
                final h = c.maxHeight < 720 ? 720.0 : c.maxHeight;
                return SingleChildScrollView(
                  child: SizedBox(
                    height: h,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(60, 48, 60, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // brand
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

                          // headline
                          const Text(
                            'Your academic life,\nin one place.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Track your academic performance, plan your\ntimetable and never miss a class.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // feature cards
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ResponsiveGrid(
                              minItemWidth: 250,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final f in _features)
                                  _featureCard(f.$1, f.$2, f.$3),
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

  Widget _desktopPanel() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 40,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'S',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in or create an account to continue.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black45,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Sign In
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).push(fadeRoute(const SignInScreen())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Create Account
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).push(fadeRoute(const RegisterScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blue,
                              side: const BorderSide(color: _blue, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Google (bordered so a white button stays visible)
                        Container(
                          height: 56,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: GoogleButton(
                            onPressed: () => _handleGoogleSignIn(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String desc) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}