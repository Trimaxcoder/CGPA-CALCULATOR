// ══════════════════════════════════════════════════════════
//  PRELOADER SCREEN
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:gradex/screens/main_shell.dart';
import '../main.dart';
import '../widgets/ui_helpers.dart';
import '../screens/homescreen.dart';

class PreloaderScreen extends StatefulWidget {
  @override
  State<PreloaderScreen> createState() => PreloaderScreenState();
}

class PreloaderScreenState extends State<PreloaderScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeRoute(const MainShell()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: gradientBox(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconCircle(Icons.school, 100, 54),
          const SizedBox(height: 28),
          const Text(
            'Setting up your account...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    ),
  );
}