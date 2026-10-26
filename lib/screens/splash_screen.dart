// ══════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ══════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ui_helpers.dart';
import '../services/api_service.dart';
import 'signinscreen.dart';
import 'resetpasswordscreen.dart';
import 'landing_page.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Minimum time the splash stays on screen (the auth check runs during it)
  static const _minShow = Duration(milliseconds: 2200);
  // Longest we wait for the server before falling back to the saved profile
  static const _authTimeout = Duration(milliseconds: 2500);

  // Run cycle (loops): legs, arms, bounce, scrolling ground and speed lines
  late final AnimationController _run;
  // One-shot entrance fade
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _tagSlide;

  @override
  void initState() {
    super.initState();

    _run = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _tagSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _start();
  }

  /// Runs the minimum splash timer and the auth check at the same time,
  /// then navigates as soon as both are done.
  Future<void> _start() async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(_minShow),
      _resolveNextScreen(),
    ]);

    if (!mounted) return;
    final next = results[1] as Widget;
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  /// Decides which screen to open next. Never waits longer than
  /// [_authTimeout] on the network.
  Future<Widget> _resolveNextScreen() async {
    if (kIsWeb) {
      final token = _getResetTokenFromUrl();
      if (token != null) {
        return ResetPasswordScreen(token: token);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final hasProfile = (prefs.getString('profile') ?? '').isNotEmpty;
    final hasToken = (await TokenStorage.getAccessToken() ?? '').isNotEmpty;

    if (!hasProfile && !hasToken) {
      return LandingPage();
    }

    bool tokenValid = false;
    if (hasToken) {
      try {
        await AuthService().getMe().timeout(_authTimeout);
        tokenValid = true;
      } on UnauthorizedException {
        await TokenStorage.clearTokens();
        tokenValid = false;
      } catch (_) {
        // Timeout or network error: trust the saved profile
        tokenValid = hasProfile;
      }
    }

    return tokenValid ? const MainShell() : const SignInScreen();
  }

  @override
  void dispose() {
    _run.dispose();
    _intro.dispose();
    super.dispose();
  }

  String? _getResetTokenFromUrl() {
    try {
      final token = Uri.base.queryParameters['token'];
      final path = Uri.base.path;
      if (path == '/reset-password' && token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _fade,
                  child: CustomPaint(painter: _RunnerPainter(run: _run)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: FadeTransition(
                      opacity: _tagFade,
                      child: SlideTransition(
                        position: _tagSlide,
                        child: Text(
                          'Track your academic performance',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  RUNNER PAINTER: white student on blue, speed lines, ground
// ══════════════════════════════════════════════════════════

class _RunnerPainter extends CustomPainter {
  final Animation<double> run;

  _RunnerPainter({required this.run}) : super(repaint: run);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // One unit "u" scales the whole figure with the screen
    final u = (math.min(w, h) * 0.03).clamp(6.0, 11.0).toDouble();
    final cx = w / 2;
    final groundY = h * 0.54;

    final phase = run.value * 2 * math.pi;

    _drawGround(canvas, w, groundY, u);
    _drawSpeedLines(canvas, w, groundY, u);
    _drawStudent(canvas, cx, groundY, u, phase);
  }

  // ── Ground line + scrolling dashes ──
  void _drawGround(Canvas canvas, double w, double groundY, double u) {
    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 2,
    );

    final dashW = u * 2.5;
    final period = u * 6;
    final scroll = run.value * period; // one period per stride = seamless loop
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = groundY + u * 1.6;
    for (double x = -period - scroll; x < w + period; x += period) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
    }
  }

  // ── Speed streaks flowing past ──
  void _drawSpeedLines(Canvas canvas, double w, double groundY, double u) {
    // y offset above ground, length, speed multiplier (whole numbers loop cleanly), opacity
    const lines = [
      [9.5, 6.0, 2.0, 0.30],
      [7.0, 9.0, 1.0, 0.22],
      [4.5, 5.0, 3.0, 0.28],
      [11.5, 7.0, 1.0, 0.18],
      [2.0, 8.0, 2.0, 0.22],
    ];
    const starts = [0.15, 0.55, 0.85, 0.35, 0.7];

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      final y = groundY - u * l[0];
      final len = u * l[1];
      final x = ((starts[i] * w) - run.value * w * l[2]) % w;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: l[3])
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  // ── The student (white silhouette) ──
  void _drawStudent(
    Canvas canvas,
    double cx,
    double groundY,
    double u,
    double p,
  ) {
    final thigh = u * 2.7;
    final shin = u * 2.7;
    final upperArm = u * 1.9;
    final foreArm = u * 1.8;
    final torsoLen = u * 3.6;
    final lean = 0.22; // leans forward (to the right)

    final bob = math.cos(p * 2).abs() * u * 0.45;
    final hip = Offset(cx, groundY - (thigh + shin) * 0.9 - bob);

    // Soft shadow on the ground
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + u * 0.2),
        width: u * 6 - bob * 2,
        height: u * 0.9,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final shoulder =
        hip + Offset(math.sin(lean) * torsoLen, -math.cos(lean) * torsoLen);

    // Far limbs first (dimmer, for depth), then body, then near limbs
    _drawLeg(canvas, hip, p + math.pi, thigh, shin, u, 0.55);
    _drawArm(canvas, shoulder, p, upperArm, foreArm, u, 0.55);

    // Backpack
    canvas.save();
    canvas.translate((hip.dx + shoulder.dx) / 2, (hip.dy + shoulder.dy) / 2);
    canvas.rotate(lean);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-u * 1.35, -u * 0.1),
          width: u * 1.7,
          height: u * 2.8,
        ),
        Radius.circular(u * 0.6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.restore();

    // Torso
    canvas.drawLine(
      hip,
      shoulder,
      Paint()
        ..color = Colors.white
        ..strokeWidth = u * 1.7
        ..strokeCap = StrokeCap.round,
    );

    // Head
    final headCenter =
        shoulder + Offset(math.sin(lean) * u * 1.9, -math.cos(lean) * u * 1.9);
    canvas.drawCircle(headCenter, u * 1.15, Paint()..color = Colors.white);

    // Near limbs
    _drawLeg(canvas, hip, p, thigh, shin, u, 1.0);
    _drawArm(canvas, shoulder, p + math.pi, upperArm, foreArm, u, 1.0);
  }

  void _drawLeg(
    Canvas canvas,
    Offset hip,
    double p,
    double thigh,
    double shin,
    double u,
    double alpha,
  ) {
    final a = math.sin(p) * 0.95; // thigh swing (forward is positive)
    final bend = 0.35 + 1.0 * math.max(0.0, -math.cos(p)); // knee bends on the back swing
    final s = a - bend;

    final knee = hip + Offset(math.sin(a) * thigh, math.cos(a) * thigh);
    final foot = knee + Offset(math.sin(s) * shin, math.cos(s) * shin);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = u * 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(foot.dx, foot.dy),
      paint..style = PaintingStyle.stroke,
    );

    // Shoe
    canvas.drawLine(
      foot,
      foot + Offset(u * 0.9, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = u * 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawArm(
    Canvas canvas,
    Offset shoulder,
    double p,
    double upperArm,
    double foreArm,
    double u,
    double alpha,
  ) {
    final a = -math.sin(p) * 0.85; // upper arm swing, opposite to the same-side leg
    final f = a + 1.35; // forearm stays bent forward

    final elbow = shoulder + Offset(math.sin(a) * upperArm, math.cos(a) * upperArm);
    final hand = elbow + Offset(math.sin(f) * foreArm, math.cos(f) * foreArm);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = u * 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter oldDelegate) => false;
}