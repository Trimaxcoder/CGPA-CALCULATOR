// ══════════════════════════════════════════════════════════
//  SIGN IN SCREEN  (with biometric support)
// ══════════════════════════════════════════════════════════
import '../services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

import 'main_shell.dart';
import '../widgets/ui_helpers.dart';
import '../models/studentProfile_model.dart';
import '../services/api_service.dart';
import '../utils/responsive.dart';
import 'forgotpasswordscreen.dart';
import 'registerscreen.dart';
import '../widgets/google_button.dart';
import '../widgets/snackBar.dart';
import 'landing_page.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _fk = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  static const Color _blue = Color(0xFF1565C0);

  bool _loading = false;
  bool _obscure = true;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted)
      setState(() {
        _bioAvailable = available;
        _bioEnabled = enabled;
      });
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  // ── Email + password sign in ───────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_fk.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await AuthService().login(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );

      final userData = await AuthService().getMe();
      if (userData['profile'] != null) {
        final profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile', jsonEncode(profile.toMap()));
      }

      // Offer fingerprint enrolment after first successful login
      // (this used to be called twice, which showed the dialog twice)
      if (_bioAvailable && !_bioEnabled && mounted) {
        await _promptEnableBiometrics(
          email: _emailC.text.trim(),
          password: _passC.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
    } on UnauthorizedException {
      setState(() => _errorMsg = 'Incorrect email or password.');
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('profile') ?? '';
      if (saved.isNotEmpty && mounted) {
        Navigator.of(
          context,
        ).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
      } else {
        setState(
          () =>
              _errorMsg = 'Could not connect. Check your internet connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Fingerprint sign in ────────────────────────────────────────────────────
  Future<void> _signInWithBiometrics() async {
    final authenticated = await BiometricService.authenticate(
      reason: 'Sign in to SchoolLife',
    );
    if (!authenticated) return;

    final creds = await BiometricService.getCredentials();
    if (creds.email == null || creds.password == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Saved credentials not found. Please sign in with your password.',
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await AuthService().login(email: creds.email!, password: creds.password!);

      final token = await TokenStorage.getAccessToken();
      final refresh = await TokenStorage.getRefreshToken();
      print("=== BIO LOGIN token: ${token != null}");
      print("=== BIO LOGIN refresh: ${refresh != null}");

      final userData = await AuthService().getMe();
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
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getString('profile') ?? '').isNotEmpty && mounted) {
        Navigator.of(
          context,
        ).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
      } else {
        if (mounted) {
          setState(
            () => _errorMsg = 'Biometric sign in failed. Try your password.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Ask user to enable biometrics after login ──────────────────────────────

  Future<void> _promptEnableBiometrics({
    required String email,
    required String password,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Flexible(child: Text('Enable Fingerprint Login')),
          ],
        ),
        content: const Text(
          'Would you like to use your fingerprint to sign in faster next time?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await BiometricService.saveCredentials(
                email: email,
                password: password,
              );
              Navigator.pop(ctx);
              if (mounted) {
                AppSnackBar.showSuccess(context, 'Fingerprint login enabled ✓');
                setState(() => _bioEnabled = true);
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  // ── Google sign in ─────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId:
            '36781799836-r0fa4p6ogpj2u45k670vvh5p5fqrc4vb.apps.googleusercontent.com',
      );

      if (!kIsWeb) await googleSignIn.signOut();

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
      if (mounted) AppSnackBar.showError(context, e.message);
    } catch (e) {
      if (mounted)
        AppSnackBar.showError(context, 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() => Navigator.of(
    context,
  ).pushReplacement(fadeRoute(const LandingPage()));

  void _goRegister() => Navigator.of(
    context,
  ).pushReplacement(fadeRoute(const RegisterScreen()));

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _fk,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back button ──────────────────────────────
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
                    const SizedBox(height: 36),

                    // ── S Logo ───────────────────────────────────
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
                    const SizedBox(height: 24),

                    // ── Title ────────────────────────────────────
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to your account',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 36),

                    ..._formChildren(light: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Desktop (>= 1024 px): split screen ────────────────────
  Widget _buildDesktop() => Row(
    children: [
      Expanded(flex: 6, child: _desktopHero()),
      Expanded(flex: 4, child: _desktopPanel()),
    ],
  );

  Widget _desktopHero() {
    Widget card(IconData icon, String title, String desc) => Container(
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
                            'Welcome\nback.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Pick up right where you left off. Your CGPA,\ntimetable and reminders are waiting.',
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
                                card(
                                  Icons.track_changes_outlined,
                                  'Track CGPA',
                                  'GPA for every semester',
                                ),
                                const SizedBox(height: 12),
                                card(
                                  Icons.calendar_month_outlined,
                                  'Timetable',
                                  'Lectures, study sessions and exams',
                                ),
                                const SizedBox(height: 12),
                                card(
                                  Icons.notifications_active_outlined,
                                  'Class Alerts',
                                  'Never miss a class',
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
                      vertical: 36,
                    ),
                    child: Form(
                      key: _fk,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back
                          TextButton.icon(
                            onPressed: _goBack,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 14,
                            ),
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
                          const SizedBox(height: 18),
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Welcome back! Enter your details to continue.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 30),
                          ..._formChildren(light: true),
                        ],
                      ),
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

  // ══════════════════════════════════════════════════════════
  //  SHARED FORM  (light = true on the desktop white panel)
  // ══════════════════════════════════════════════════════════
  List<Widget> _formChildren({required bool light}) {
    final fieldText = light ? Colors.black87 : Colors.white;
    final dec = light ? _decLight : _dec;
    final mutedText = light ? Colors.black45 : Colors.white60;

    return [
      // ── Email ────────────────────────────────────
      TextFormField(
        controller: _emailC,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(color: fieldText),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email is required';
          if (!v.trim().contains('@')) return 'Enter a valid email';
          return null;
        },
        decoration: dec('Email Address', Icons.email_outlined),
      ),
      const SizedBox(height: 16),

      // ── Password ─────────────────────────────────
      TextFormField(
        controller: _passC,
        obscureText: _obscure,
        style: TextStyle(color: fieldText),
        onFieldSubmitted: (_) {
          if (!_loading) _signIn();
        },
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Password is required';
          if (v.trim().length < 4) return 'Password too short';
          return null;
        },
        decoration: dec('Password', Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              color: light ? Colors.black38 : Colors.white60,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),

      // ── Forgot password ──────────────────────────
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(fadeRoute(const ForgotPasswordScreen())),
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              color: light ? _blue : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      if (_errorMsg != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(light ? 0.07 : 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: light ? Colors.red.shade700 : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMsg!,
                  style: TextStyle(
                    color: light ? Colors.red.shade700 : Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),

      // ── Sign In button ───────────────────────────
      SizedBox(
        width: double.infinity,
        height: 54,
        child: light
            ? ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
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
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.transparent,
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
                      : const Text(
                          'Sign In',
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

      // ── Fingerprint button ───────────────────────
      if (_bioAvailable && _bioEnabled) ...[
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: light ? null : Border.all(color: Colors.white30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _signInWithBiometrics,
              icon: const Icon(Icons.fingerprint, size: 24, color: Colors.white),
              label: const Text(
                'Sign in with Fingerprint',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],

      // ── Divider ──────────────────────────────────
      Row(
        children: [
          Expanded(
            child: Divider(
              color: light ? Colors.black12 : Colors.white.withOpacity(0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or',
              style: TextStyle(
                color: light ? Colors.black38 : Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: light ? Colors.black12 : Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // ── Google button ────────────────────────────
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

      // ── Register link ────────────────────────────
      Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account?  ",
              style: TextStyle(color: mutedText, fontSize: 14),
            ),
            GestureDetector(
              onTap: _goRegister,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Create one',
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
    ];
  }

  // Dark-on-gradient decoration (phone)
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