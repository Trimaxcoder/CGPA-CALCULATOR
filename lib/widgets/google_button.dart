// ══════════════════════════════════════════════════════════
//  GOOGLE BUTTON WIDGET (reusable)
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';



class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      side: const BorderSide(color: Colors.white, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: EdgeInsets.zero,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Google "G" logo drawn with colored quadrants
        SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: GoogleLogoPainter()),
        ),
        const SizedBox(width: 12),
        const Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}


class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw coloured arcs for G logo approximation
    final colors = [
      const Color(0xFF4285F4), // blue  (top)
      const Color(0xFF34A853), // green (bottom-right)
      const Color(0xFFFBBC05), // yellow(bottom-left)
      const Color(0xFFEA4335), // red   (top-left)
    ];
    final starts = [-0.5, 0.0, 0.5, 1.0].map((v) => v * 3.14159).toList();

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.2
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.72),
        starts[i],
        3.14159 * 0.5,
        false,
        paint,
      );
    }

    // horizontal bar of G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - size.height * 0.12,
        r * 0.72,
        size.height * 0.24,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
