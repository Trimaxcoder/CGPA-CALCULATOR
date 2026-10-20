// ══════════════════════════════════════════════════════════
//  MOBILE PAGE HEADER — light header used instead of the big blue block
//  Back tile + title/subtitle + optional action tiles.
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';

/// Small rounded square button used in headers.
class HeaderTile extends StatelessWidget {
  const HeaderTile({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final tile = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: color ?? (isDark ? Colors.white : Colors.black87),
      ),
    );
    final child = GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: tile),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            if (showBack) ...[
              HeaderTile(
                icon: Icons.arrow_back_rounded,
                onTap: onBack ?? () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                ],
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
      ),
    );
  }
}