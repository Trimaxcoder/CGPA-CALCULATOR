// ══════════════════════════════════════════════════════════
//  BRAND MARK + NOTIFICATION BELL (shared by the shell and Home)
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/notification_store.dart';
import '../screens/notifications_screen.dart';

const Color _blue = Color(0xFF1565C0);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.showText});

  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'SCHOOLLIFE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Notification bell with an animated unread badge.
class BellButton extends StatelessWidget {
  const BellButton({
    super.key,
    required this.isDark,
    required this.badgeBorder,
    this.size = 42,
  });

  final bool isDark;
  final Color badgeBorder;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationStore>(
      builder: (context, store, _) {
        final count = store.unreadCount;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: _blue,
                    size: 21,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: anim,
                        curve: Curves.elasticOut,
                      ),
                      child: child,
                    ),
                    child: count > 0
                        ? Container(
                            key: ValueKey(count),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: badgeBorder, width: 2),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}