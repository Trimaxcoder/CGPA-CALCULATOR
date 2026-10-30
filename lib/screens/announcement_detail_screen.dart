// lib/screens/announcement_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/announcement.dart';
import '../providers/theme_notifier.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_page.dart';
import '../widgets/page_header.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  static const Color _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    // ── Desktop: a centered "reading" card ─────────────────
    if (context.isExpanded) {
      return DesktopPage(
        title: 'Announcement',
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(34),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15181D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _content(isDark, titleSize: 30, bodySize: 16),
          ),
        ),
      );
    }

    // ── Phone / tablet ─────────────────────────────────────
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA),
      body: Column(
        children: [
          const MobileHeader(title: 'Announcement'),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.of(context).padding.bottom + 40,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF15181D) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _content(isDark, titleSize: 22, bodySize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chips, title, author row and message (shared by both layouts)
  Widget _content(
    bool isDark, {
    required double titleSize,
    required double bodySize,
  }) {
    final a = announcement;

    // General announcements get one "General" chip; class announcements
    // show where they were posted (empty parts are skipped).
    final scopeChips = <Widget>[
      if (a.isGlobal)
        const _Chip(label: 'General', color: _primary, textColor: Colors.white)
      else ...[
        if (a.school.isNotEmpty) _Chip(label: a.school),
        if (a.faculty.isNotEmpty) _Chip(label: a.faculty),
        if (a.department.isNotEmpty) _Chip(label: a.department),
        _Chip(label: a.levelLabel, color: _primary, textColor: Colors.white),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: scopeChips),

        const SizedBox(height: 20),

        // Title
        Text(
          a.title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        // Admin + date row
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded,
                  color: _primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.adminName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _primary,
                    ),
                  ),
                  Text(
                    a.wasEdited
                        ? '${_formatDate(a.createdAt)} · edited'
                        : _formatDate(a.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        ),

        // Message body
        SelectableText(
          a.message,
          style: TextStyle(
            fontSize: bodySize,
            height: 1.65,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month - 1]} ${d.year} · $h:$m $period';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  static const Color _primary = Color(0xFF1565C0);

  const _Chip({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color ?? _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor ?? _primary,
          ),
        ),
      );
}