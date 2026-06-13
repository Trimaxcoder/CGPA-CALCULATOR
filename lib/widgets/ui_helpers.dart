

// ══════════════════════════════════════════════════════════
//  SHARED UTILITIES
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

Widget gradientBox({required Widget child}) => Container(
  width: double.infinity,
  height: double.infinity,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.blue.shade700, Colors.indigo.shade900],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: child,
);

Widget iconCircle(IconData icon, double size, double iconSize) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    shape: BoxShape.circle,
  ),
  child: Icon(icon, size: iconSize, color: Colors.white),
);

Widget sheetHandle() => Container(
  margin: const EdgeInsets.only(top: 12),
  width: 40,
  height: 4,
  decoration: BoxDecoration(
    color: Colors.grey.shade400,
    borderRadius: BorderRadius.circular(2),
  ),
);

/// Shared "── OR ──" divider used on auth screens
Widget orDivider() => Row(
  children: [
    Expanded(child: Divider(color: Colors.white24, thickness: 1)),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        'OR',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    ),
    Expanded(child: Divider(color: Colors.white24, thickness: 1)),
  ],
);

/// Shared error box widget used on auth screens
Widget errorBox(String message) => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: Colors.red.withOpacity(0.15),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.red.withOpacity(0.4)),
  ),
  child: Row(
    children: [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      ),
    ],
  ),
);

PageRouteBuilder fadeRoute(Widget page) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 600),
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) =>
      FadeTransition(opacity: anim, child: child),
);


// ══════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════

Color scoreColor(int s) {
  if (s >= 70) return Colors.green;
  if (s >= 50) return Colors.blue;
  if (s >= 40) return Colors.orange;
  return Colors.red;
}

String getDegreeClass(double cgpa, double max) {
  final pct = max > 0 ? cgpa / max : 0;
  if (pct >= 0.90) return 'First Class';
  if (pct >= 0.70) return 'Second Class Upper';
  if (pct >= 0.48) return 'Second Class Lower';
  if (pct >= 0.30) return 'Third Class';
  if (cgpa > 0) return 'Pass';
  return '—';
}

Color degreeColor(double cgpa, double max) {
  final pct = max > 0 ? cgpa / max : 0;
  if (pct >= 0.90) return Colors.green.shade700;
  if (pct >= 0.70) return Colors.blue.shade700;
  if (pct >= 0.48) return Colors.orange.shade700;
  if (pct >= 0.30) return Colors.purple.shade700;
  if (cgpa > 0) return Colors.grey.shade700;
  return Colors.grey;
}

bool isValidEmail(String e) =>
    RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(e);
