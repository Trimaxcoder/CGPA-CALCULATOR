// lib/widgets/rep_request_checks.dart
//
// The checklist the super admin sees on each pending class rep request.
// It reads the `checks` the server worked out and shows ✓ / ✗ / ! for each.

import 'package:flutter/material.dart';

class RepRequestChecks extends StatelessWidget {
  /// One request from GET /admin/pending (includes a `checks` map).
  final Map request;
  final bool isDark;

  const RepRequestChecks({
    super.key,
    required this.request,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final checks = request['checks'];
    if (checks is! Map) return const SizedBox.shrink();

    final sem = checks['semester'] is Map ? checks['semester'] as Map : const {};
    final declared = sem['declared'];
    final calendar = sem['calendar'];
    final semMatches = sem['matches']; // true / false / null (unknown)
    final classAdmins = (checks['classAdmins'] as num?)?.toInt() ?? 0;

    final rows = <_Row>[
      _Row(
        checks['nameMatches'] == true ? _Mark.ok : _Mark.bad,
        'Name matches profile',
        '${request['fullName'] ?? '—'}',
      ),
      _Row(
        checks['matricMatches'] == true ? _Mark.ok : _Mark.bad,
        'Matric number matches profile',
        '${request['matricNumber'] ?? '—'}',
      ),
      _Row(
        checks['profileClassMatches'] == true ? _Mark.ok : _Mark.bad,
        'Profile still shows this class',
        checks['profileClassMatches'] == true
            ? null
            : 'The student changed their profile after applying',
      ),
      _Row(
        semMatches == true
            ? _Mark.ok
            : semMatches == false
                ? _Mark.warn
                : _Mark.info,
        'Semester ${declared ?? '—'}',
        semMatches == true
            ? 'Matches the school calendar'
            : semMatches == false
                ? 'Calendar says semester $calendar'
                : 'No calendar to compare with',
      ),
      _Row(
        checks['duplicateMatric'] == true ? _Mark.warn : _Mark.ok,
        checks['duplicateMatric'] == true
            ? 'Another account uses this matric number'
            : 'No other account uses this matric number',
        null,
      ),
      _Row(
        classAdmins >= 2 ? _Mark.bad : _Mark.ok,
        classAdmins == 0
            ? 'This class has no rep yet'
            : '$classAdmins rep${classAdmins == 1 ? '' : 's'} already in this class',
        classAdmins >= 2 ? 'Full: approval will be refused' : null,
      ),
      _Row(
        _Mark.info,
        'Last level before graduation',
        '${request['finalLevel'] ?? '—'}',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHECKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rows) _line(r),
        ],
      ),
    );
  }

  Widget _line(_Row r) {
    final IconData icon;
    final Color color;
    switch (r.mark) {
      case _Mark.ok:
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        break;
      case _Mark.bad:
        icon = Icons.cancel_rounded;
        color = Colors.red;
        break;
      case _Mark.warn:
        icon = Icons.error_rounded;
        color = Colors.orange;
        break;
      case _Mark.info:
        icon = Icons.info_rounded;
        color = Colors.blueGrey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (r.detail != null)
                  Text(
                    r.detail!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Mark { ok, bad, warn, info }

class _Row {
  final _Mark mark;
  final String title;
  final String? detail;
  const _Row(this.mark, this.title, this.detail);
}