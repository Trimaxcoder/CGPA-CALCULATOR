// ══════════════════════════════════════════════════════════
//  APP DIALOG  — the one design for confirmations and dialogs
//  Centered card, tinted icon circle, title, message, two buttons,
//  soft scale + fade entrance.
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

const Color _blue = Color(0xFF1565C0);

/// Reusable shell. Pass your own [actions] / [child] for custom dialogs.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = _blue,
    this.child,
    this.actions = const [],
    this.maxWidth = 380,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Color color;
  final Widget? child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black54;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15181D) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: sub),
                    ),
                  ],
                  if (child != null) ...[const SizedBox(height: 16), child!],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows any dialog with the app's entrance animation.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

/// Yes/No confirmation. Returns true when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  Color color = _blue,
}) async {
  final res = await showAppDialog<bool>(
    context,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      icon: icon,
      color: color,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
            side: BorderSide(
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white24
                  : Colors.black12,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            cancelLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  return res ?? false;
}