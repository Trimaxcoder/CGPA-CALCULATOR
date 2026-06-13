
// ══════════════════════════════════════════════════════════
//  CUSTOM SNACKBAR SYSTEM
//  — slides in from right, stays 3 s, slides out to left,
//    has a close (×) button, stacks if multiple fire at once
// ══════════════════════════════════════════════════════════


import 'package:flutter/material.dart';

class AppSnackBar {
  static final _overlays = <OverlayEntry>[];

  static void show(
    BuildContext context,
    String message, {
    Color color = Colors.black87,
    IconData icon = Icons.info_outline,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SnackBarWidget(
        message: message,
        color: color,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          entry.remove();
          _overlays.remove(entry);
        },
      ),
    );
    Overlay.of(context).insert(entry);
    _overlays.add(entry);
  }

  static void showSuccess(BuildContext ctx, String msg) => show(
    ctx,
    msg,
    color: Colors.green.shade700,
    icon: Icons.check_circle_outline,
  );

  static void showError(BuildContext ctx, String msg) =>
      show(ctx, msg, color: Colors.red.shade700, icon: Icons.error_outline);

  static void showInfo(BuildContext ctx, String msg) =>
      show(ctx, msg, color: Colors.blue.shade700, icon: Icons.info_outline);

  static void showUndo(BuildContext ctx, String msg, VoidCallback onUndo) =>
      show(
        ctx,
        msg,
        color: Colors.grey.shade800,
        icon: Icons.delete_outline,
        actionLabel: 'UNDO',
        onAction: onUndo,
      );
}

class _SnackBarWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _SnackBarWidget({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_SnackBarWidget> createState() => _SnackBarWidgetState();
}

class _SnackBarWidgetState extends State<_SnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.onAction?.call();
                        _dismiss();
                      },
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}