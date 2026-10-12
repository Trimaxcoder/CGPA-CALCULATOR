// ══════════════════════════════════════════════════════════
//  ANIMATION TOOLKIT
//  Small reusable building blocks used across the app:
//    FadeSlideIn   – entrance animation (fade + slide), supports delay
//    staggered()   – applies FadeSlideIn with increasing delays to a list
//    AnimatedCount – number that counts up
//    ProgressRing  – animated circular progress
//    PressScale    – tap feedback (scales down slightly)
//    PulseDot      – glowing "live" dot
//    Skeleton      – pulsing loading placeholder
//    WavingHand    – 👋 that waves once
// ══════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curve;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: widget.offset,
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Wraps every widget with a [FadeSlideIn] whose delay grows with its index.
List<Widget> staggered(
  List<Widget> items, {
  int stepMs = 55,
  int startMs = 0,
  int maxSteps = 10,
}) => [
  for (var i = 0; i < items.length; i++)
    FadeSlideIn(
      delay: Duration(milliseconds: startMs + math.min(i, maxSteps) * stepMs),
      child: items[i],
    ),
];

class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1000),
  });

  final double value;
  final int decimals;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: value),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (_, v, __) =>
        Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
  );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 72,
    this.strokeWidth = 8,
    this.trackColor,
    this.child,
    this.duration = const Duration(milliseconds: 1100),
  });

  /// 0.0 – 1.0
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: v,
              color: color,
              track: trackColor ?? color.withOpacity(0.15),
              stroke: strokeWidth,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null
        ? SystemMouseCursors.basic
        : SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = widget.pressedScale),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = Colors.greenAccent, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.55 * (1 - _c.value)),
            spreadRadius: widget.size * 0.9 * _c.value,
          ),
        ],
      ),
    ),
  );
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 64, this.radius = 16});

  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.10 + 0.12 * _c.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class WavingHand extends StatefulWidget {
  const WavingHand({super.key, this.size = 22});

  final double size;

  @override
  State<WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.rotate(
      angle: math.sin(_c.value * math.pi * 6) * 0.35 * (1 - _c.value),
      alignment: Alignment.bottomRight,
      child: child,
    ),
    child: Text('👋', style: TextStyle(fontSize: widget.size)),
  );
}