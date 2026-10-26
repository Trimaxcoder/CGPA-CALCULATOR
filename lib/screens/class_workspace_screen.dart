// lib/screens/class_workspace_screen.dart
//
// The entry point for "Join a class".
//  - Wide screens (desktop / tablet / web): WhatsApp-desktop layout. The class
//    list is a sidebar on the left, the open chat is on the right, on one page.
//  - Narrow screens (phones): the normal class list; a chat slides in on top.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../widgets/class_layout.dart';
import 'class_screen.dart';
import 'classes_hub_screen.dart';

class ClassWorkspaceScreen extends StatefulWidget {
  const ClassWorkspaceScreen({super.key});

  @override
  State<ClassWorkspaceScreen> createState() => _ClassWorkspaceScreenState();
}

class _ClassWorkspaceScreenState extends State<ClassWorkspaceScreen> {
  ClassRoom? _selected;

  void _select(ClassRoom room) {
    if (_selected?.id == room.id) return;
    setState(() => _selected = room);
  }

  void _close() {
    if (_selected == null) return;
    setState(() => _selected = null);
  }

  /// The sidebar tells us whenever it reloads. If the open class is gone (left,
  /// removed, archived) or no longer active, close its chat.
  void _onClassesLoaded(List<ClassRoom> classes) {
    final open = _selected;
    if (open == null || !mounted) return;
    final stillThere = classes.any((c) => c.id == open.id && c.isActive);
    if (!stillThere) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones: the plain list. Opening a class slides the chat in.
        if (constraints.maxWidth < kClassSplitBreakpoint) {
          return const ClassesHubScreen();
        }

        final sidebarWidth = (constraints.maxWidth * 0.32).clamp(320.0, 420.0);
        final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
        final line = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          backgroundColor: bg,
          body: CallbackShortcuts(
            // Esc closes the open chat, like WhatsApp desktop
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _close,
            },
            child: Focus(
              autofocus: true,
              child: Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: ClassesHubScreen(
                      embedded: true,
                      selectedId: _selected?.id,
                      onSelect: _select,
                      onLoaded: _onClassesLoaded,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: line),
                  Expanded(child: _pane(isDark)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pane(bool isDark) {
    final open = _selected;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
                children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: open == null
          ? _EmptyPane(key: const ValueKey('empty'), isDark: isDark)
          : ClassScreen(
              // a new key per class gives each chat a fresh state and store
              key: ValueKey(open.id),
              room: open,
              embedded: true,
              onRemoved: _close,
            ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Container(
      color: isDark ? const Color(0xFF0F1114) : const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 46,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Your class spaces',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a class on the left to open its chat.',
              style: TextStyle(fontSize: 14, color: sub),
            ),
            const SizedBox(height: 4),
            Text(
              'Press Esc to close a chat.',
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
          ],
        ),
      ),
    );
  }
}