part of 'homescreen.dart';

// ══════════════════════════════════════════════════════════
//  GRADES — MODERN SUMMARY + CHART (phone / tablet)
//  Adds a donut chart (grade distribution), an animated CGPA ring,
//  per-semester rings and animated entrances. Colors are unchanged.
// ══════════════════════════════════════════════════════════

extension _GradesModern on _HomeScreenState {
  // ── Data helpers ──────────────────────────────────────────
  Map<String, int> _gradeCounts() {
    final m = <String, int>{};
    for (final r in grading.rules) {
      m[r.grade] = 0;
    }
    for (final c in courses) {
      final g = grading.getGrade(c.score);
      m[g] = (m[g] ?? 0) + 1;
    }
    return m;
  }

  BoxDecoration _gCardDeco() => BoxDecoration(
    color: isDarkMode ? Colors.black : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDarkMode
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.05),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _gTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    ),
  );

  // ── Donut chart ───────────────────────────────────────────
  Widget _gradeDonut(double size, Map<String, int> counts) {
    final entries = counts.entries.where((e) => e.value > 0).toList();
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: 0.6 + 0.4 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: size * 0.30,
                startDegreeOffset: -90,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value.toDouble(),
                      color: _gradeColor(e.key),
                      radius: size * 0.17,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${courses.length}',
                  style: TextStyle(
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                Text(
                  'courses',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Grade distribution card. [compact] = smaller version for the desktop
  /// summary strip.
  Widget _gradeDistributionCard({bool compact = false}) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final counts = _gradeCounts();
    final shown = counts.entries.where((e) => e.value > 0).toList();
    final total = courses.length;

    if (courses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 22),
        decoration: _gCardDeco(),
        child: Row(
          children: [
            Icon(Icons.donut_large_rounded, color: _HomeScreenState._primary.withOpacity(0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add courses to see your grade distribution',
                style: TextStyle(fontSize: 13, color: subColor),
              ),
            ),
          ],
        ),
      );
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _gCardDeco(),
        child: Row(
          children: [
            _gradeDonut(100, counts),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Grade distribution',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      for (final e in shown)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _gradeColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${e.key} ${e.value}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _gCardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grade distribution',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _gradeDonut(132, counts),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (final e in shown)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _gradeColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Grade ${e.key}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${e.value} · ${(e.value * 100 / total).round()}%',
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Semester rings ────────────────────────────────────────
  Widget _semesterRings() {
    final items = <({String label, double gpa, int count})>[];
    for (var y = 1; y <= 7; y++) {
      for (var s = 1; s <= 2; s++) {
        final l = _semCourses(y, s);
        if (l.isNotEmpty) {
          items.add((label: 'Y$y · S$s', gpa: _gpa(l), count: l.length));
        }
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gTitle('Semester performance'),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final it = items[i];
              final color = degreeColor(it.gpa, maxGP);
              return FadeSlideIn(
                delay: Duration(milliseconds: 120 + i * 70),
                offset: const Offset(0.1, 0),
                child: Container(
                  width: 124,
                  padding: const EdgeInsets.all(14),
                  decoration: _gCardDeco(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ProgressRing(
                        size: 72,
                        strokeWidth: 8,
                        value: maxGP > 0 ? it.gpa / maxGP : 0,
                        color: color,
                        child: AnimatedCount(
                          value: it.gpa,
                          decimals: 2,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        it.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${it.count} course${it.count == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SUMMARY TAB (modern)
  // ══════════════════════════════════════════════════════════
  Widget _buildSummaryModern() {
    final top = topCourse;

    final hero = RepaintBoundary(
      key: _shareKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _HomeScreenState._primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            if (profile.name.isNotEmpty) ...[
              Text(
                profile.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.department.isNotEmpty)
                Text(
                  profile.department,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 16),
            ],
            ProgressRing(
              size: 150,
              strokeWidth: 12,
              value: _cgpaHidden || maxGP <= 0 ? 0 : cgpa / maxGP,
              color: Colors.white,
              trackColor: Colors.white24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CGPA',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  _cgpaHidden
                      ? const Text(
                          '••••',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : AnimatedCount(
                          value: cgpa,
                          decimals: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!_cgpaHidden)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: degreeColor(cgpa, maxGP).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: degreeColor(cgpa, maxGP).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  getDegreeClass(cgpa, maxGP),
                  style: TextStyle(
                    color: degreeColor(cgpa, maxGP),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _pill('Courses', '$totalCourses'),
                _pill('Units', '$totalUnits'),
                _pill('Max GP', maxGP.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );

    final actions = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareImage,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _HomeScreenState._primary,
              side: BorderSide(color: _HomeScreenState._primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportPDF,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _HomeScreenState._primary,
              side: BorderSide(color: _HomeScreenState._primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );

    final stats = Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statCard(
                  'Best Semester',
                  bestSemLabel,
                  Icons.emoji_events,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Top Course',
                  top != null ? '${top.name}\n(Score: ${top.score})' : '—',
                  Icons.star,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statCard(
                  'Total Units',
                  '$totalUnits credits',
                  Icons.library_books,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Courses Taken',
                  '$totalCourses',
                  Icons.menu_book,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: staggered([
          hero,
          const SizedBox(height: 14),
          actions,
          const SizedBox(height: 20),
          _gradeDistributionCard(),
          const SizedBox(height: 20),
          _semesterRings(),
          const SizedBox(height: 20),
          stats,
        ], stepMs: 70),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CHART TAB (modern): line chart + donut
  // ══════════════════════════════════════════════════════════
  Widget _buildChartModern() {
    if (courses.isEmpty) return _buildChart();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: staggered([
        Container(
          height: 340,
          decoration: _gCardDeco(),
          child: _buildChart(),
        ),
        const SizedBox(height: 16),
        _gradeDistributionCard(),
      ], stepMs: 80),
    );
  }
}