// ══════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ui_helpers.dart';
import '../services/api_service.dart';
import 'signinscreen.dart';
import 'resetpasswordscreen.dart';
import 'landing_page.dart';
import 'homescreen.dart';
import 'main_shell.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> fadeAnim, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    fadeAnim = Tween<double>(
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

      if (kIsWeb) {
        final token = _getResetTokenFromUrl();
        print("=== RESET TOKEN: $token");
        print("=== URL path: ${Uri.base.path}");
        print("=== URL query: ${Uri.base.query}");
        if (token != null) {
          Navigator.of(
            context,
          ).pushReplacement(fadeRoute(ResetPasswordScreen(token: token)));
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final hasProfile = (prefs.getString('profile') ?? '').isNotEmpty;
      final hasToken = (await TokenStorage.getAccessToken() ?? '').isNotEmpty;

      // First time opening the app
      if (!hasProfile && !hasToken) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(fadeRoute(LandingPage()));
        return;
      }

      // Returning user — verify token is still valid
      bool tokenValid = false;
      if (hasToken) {
        try {
          await AuthService().getMe();
          tokenValid = true;
        } on UnauthorizedException {
          await TokenStorage.clearTokens(); // wipe expired tokens
          tokenValid = false;
        } catch (_) {
          // offline — trust cached profile
          tokenValid = hasProfile;
        }
      }

       if (tokenValid) {
        await NotificationService.init();
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        fadeRoute(tokenValid ? const MainShell() : const SignInScreen()),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _getResetTokenFromUrl() {
    try {
      // ignore: undefined_prefixed_name
      final token = Uri.base.queryParameters['token'];
      final path = Uri.base.path;
      if (path == '/reset-password' && token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: FadeTransition(
        opacity: fadeAnim,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconCircle(Icons.school, 110, 60),
              const SizedBox(height: 28),
              const Text(
                'Gradex',
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
