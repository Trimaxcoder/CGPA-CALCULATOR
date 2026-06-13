// main.dart
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';



void main() => runApp(const MyApp());

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
