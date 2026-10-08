// ══════════════════════════════════════════════════════════
//  AUTH SPLIT LAYOUT (desktop, >= 1024 px)
//  Blue hero on the left, white form panel on the right.
//  Used by the forgot-password and reset-password screens.
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

class AuthSplit extends StatelessWidget {
  const AuthSplit({
    super.key,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.child,
  });

  final String heroTitle;
  final String heroSubtitle;
  final Widget child;

  static const Color _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 6, child: _hero()),
        Expanded(flex: 4, child: _panel()),
      ],
    );
  }

  Widget _hero() => Container(
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
              final h = c.maxHeight < 620 ? 620.0 : c.maxHeight;
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
                        Text(
                          heroTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          heroSubtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
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

  Widget _panel() => Container(
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
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}