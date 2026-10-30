// lib/widgets/chat_doodle_background.dart
//
// A faint pattern of school items (pencils, books, a schoolbag, markers,
// rulers...) behind the chat, like the default WhatsApp wallpaper. It is drawn
// very lightly so messages stay easy to read, in both light and dark mode.

import 'package:flutter/material.dart';

class ChatDoodleBackground extends StatelessWidget {
  const ChatDoodleBackground({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.expand(
          child: CustomPaint(painter: _DoodlePainter(isDark)),
        ),
      ),
    );
  }
}

const List<IconData> _doodles = [
  Icons.edit_rounded, // pencil
  Icons.menu_book_rounded, // open book
  Icons.backpack_rounded, // schoolbag
  Icons.border_color_rounded, // marker
  Icons.straighten_rounded, // ruler
  Icons.calculate_rounded, // calculator
  Icons.draw_rounded, // pen
  Icons.science_rounded, // lab flask
  Icons.auto_stories_rounded, // stack of books
  Icons.content_cut_rounded, // scissors
  Icons.school_rounded, // graduation cap
  Icons.public_rounded, // globe
  Icons.lightbulb_outline_rounded, // idea
  Icons.sticky_note_2_outlined, // note
];

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.isDark);

  final bool isDark;

  static const double _cell = 84; // distance between doodles
  static const double _iconSize = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFF1565C0).withValues(alpha: 0.07);

    // One text painter per icon, reused for every copy of it
    final painters = <TextPainter>[
      for (final icon in _doodles)
        TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: _iconSize,
              color: color,
            ),
          ),
        )..layout(),
    ];

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // The same pattern every time: nothing flickers or moves on rebuild
        final seed = r * 131 + c * 17;
        final index = (r * 5 + c * 3 + (seed % 4)) % painters.length;
        final jitterX = ((seed * 37) % 29) - 14.0;
        final jitterY = ((seed * 53) % 29) - 14.0;
        final angle = (((seed * 11) % 21) - 10) / 10 * 0.55;

        // every other row is shifted so the pattern is not a strict grid
        final x = c * _cell + (r.isOdd ? _cell / 2 : 0) + jitterX;
        final y = r * _cell + jitterY;

        final tp = painters[index];
        canvas.save();
        canvas.translate(x + tp.width / 2, y + tp.height / 2);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.isDark != isDark;
}