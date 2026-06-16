
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
import 'forgotpasswordscreen.dart';
import 'registerscreen.dart';
import '../widgets/google_button.dart';
import '../widgets/snackBar.dart';
import 'homescreen.dart';


class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _fk = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

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
      if (_bioAvailable && !_bioEnabled && mounted) {
        _promptEnableBiometrics(
          email: _emailC.text.trim(),
          password: _passC.text.trim(),
        );
      }

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
      reason: 'Sign in to Gradex',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          child: Form(
            key: _fk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 32),
                iconCircle(Icons.lock_outline_rounded, 76, 38),
                const SizedBox(height: 20),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to your account',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 36),

                // Email
                TextFormField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!v.trim().contains('@')) return 'Enter a valid email';
                    return null;
                  },
                  decoration: _dec('Email Address', Icons.email_outlined),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passC,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Password is required';
                    if (v.trim().length < 4) return 'Password too short';
                    return null;
                  },
                  decoration: _dec('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.blue.shade300,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(fadeRoute(const ForgotPasswordScreen())),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.blue.shade200,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 6),
                  errorBox(_errorMsg!),
                ],
                const SizedBox(height: 20),

                // Sign In button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.white38,
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
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Fingerprint button — only shown when device supports it
                // and user has previously enabled it
                if (_bioAvailable && _bioEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithBiometrics,
                      icon: const Icon(
                        Icons.fingerprint,
                        size: 26,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Sign in with Fingerprint',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.white54,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                orDivider(),
                const SizedBox(height: 16),

                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: GoogleButton(onPressed: _handleGoogleSignIn),
                ),
                const SizedBox(height: 28),

                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?  ",
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pushReplacement(fadeRoute(const RegisterScreen())),
                        child: Text(
                          'Create one',
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
                ),
              ],
            ),
          ),
        ),
      ),
    ),
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