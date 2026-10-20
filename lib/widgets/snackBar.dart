// ══════════════════════════════════════════════════════════
//  APP SNACKBAR  (overlay based)
//  Always appears ON TOP of everything — bottom sheets, dialogs, the
//  bottom nav — so no success / error message is ever hidden.
//  Same API as before: showSuccess / showError / showInfo / showUndo,
//  plus auto() which picks the style from the message text.
// ══════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

enum _Kind { success, error, info }

class AppSnackBar {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static _ToastState? _state;

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, _Kind.success);

  static void showError(BuildContext context, String message) =>
      _show(context, message, _Kind.error);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, _Kind.info);

  static void showUndo(
    BuildContext context,
    String message,
    VoidCallback onUndo,
  ) => _show(
    context,
    message,
    _Kind.info,
    actionLabel: 'UNDO',
    onAction: onUndo,
    duration: const Duration(seconds: 5),
  );

  /// Picks success / error / info from the wording of the message.
  static void auto(BuildContext context, String message) {
    final m = message.toLowerCase();
    final isError =
        m.startsWith('error') ||
        m.contains('failed') ||
        m.contains('could not') ||
        m.contains("couldn't") ||
        m.contains('incorrect') ||
        m.contains('invalid') ||
        m.contains('missing') ||
        m.contains('not found') ||
        m.contains('unable');
    if (isError) {
      showError(context, message);
      return;
    }
    final isSuccess =
        message.contains('✓') ||
        message.contains('✅') ||
        RegExp(
          r'\b(added|saved|updated|deleted|sent|submitted|approved|restored|'
          r'cleared|enabled|revoked|resigned|applied|created|muted|unmuted|'
          r'removed|set)\b',
        ).hasMatch(m);
    if (isSuccess) {
      showSuccess(context, message);
    } else {
      showInfo(context, message);
    }
  }

  static void _show(
    BuildContext context,
    String message,
    _Kind kind, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final overlay =
        NavigationService.navigatorKey.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _remove(immediate: true);

    final entry = OverlayEntry(
      builder: (_) => _Toast(
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction,
        onClose: () => _remove(),
        register: (s) => _state = s,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(
      duration ??
          (kind == _Kind.error
              ? const Duration(milliseconds: 4500)
              : const Duration(milliseconds: 3200)),
      () => _remove(),
    );
  }

  static void _remove({bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    final st = _state;
    _entry = null;
    _state = null;
    if (entry == null) return;

    if (immediate || st == null) {
      try {
        entry.remove();
      } catch (_) {}
      return;
    }
    st.hide().then((_) {
      try {
        entry.remove();
      } catch (_) {}
    });
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.kind,
    required this.onClose,
    required this.register,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _Kind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;
  final void Function(_ToastState) register;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    widget.register(this);
    _c.forward();
  }

  Future<void> hide() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final phone = media.size.width < 600;

    late final Color accent;
    late final IconData icon;
    switch (widget.kind) {
      case _Kind.success:
        accent = const Color(0xFF22C55E);
        icon = Icons.check_circle_rounded;
        break;
      case _Kind.error:
        accent = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        break;
      case _Kind.info:
        accent = const Color(0xFF1E88E5);
        icon = Icons.info_rounded;
        break;
    }

    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    return Positioned(
      left: 16,
      right: 16,
      // above the bottom bar on phones
      bottom: media.padding.bottom + (phone ? 96 : 24),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: widget.onClose,
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 120) widget.onClose();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withOpacity(0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              widget.onAction?.call();
                              widget.onClose();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              minimumSize: const Size(0, 34),
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}