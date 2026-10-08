part of 'homescreen.dart';

// ══════════════════════════════════════════════════════════
//  GRADES — DESKTOP LAYOUT (screens >= 1024 px)
//  Re-uses every method of _HomeScreenState (add, edit, delete, sync,
//  calculators, PDF, chart...) — only the layout is different.
// ══════════════════════════════════════════════════════════

class _GradesDesktop extends StatefulWidget {
  const _GradesDesktop({required this.s});

  final _HomeScreenState s;

  @override
  State<_GradesDesktop> createState() => _GradesDesktopState();
}

class _GradesDesktopState extends State<_GradesDesktop> {
  static const Color _blue = Color(0xFF1565C0);

  int _view = 0; // 0 = Courses, 1 = Chart
  int _sem = 0; // selected semester page (0..13)
  int _seenParentPage = -1;
  final _search = TextEditingController();
  String _query = '';

  _HomeScreenState get s => widget.s;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    // Follow the parent when it jumps to a semester (e.g. after adding courses)
    if (s.currentPage != _seenParentPage) {
      _seenParentPage = s.currentPage;
      _sem = s.currentPage.clamp(0, 13);
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final cw = c.maxWidth;
            final side = responsiveSidePadding(cw, maxWidth: 1400);
            final twoCol = cw >= 1180;
            final workbenchH = (c.maxHeight - 500)
                .clamp(580.0, 920.0)
                .toDouble();

            final left = _card(
              isDark,
              cardBg,
              _leftPanel(isDark, textPrimary, textSecondary),
            );
            final right = _card(
              isDark,
              cardBg,
              _addPanel(isDark, textPrimary, textSecondary),
            );

            return ListView(
              padding: EdgeInsets.fromLTRB(side, 26, side, 40),
              children: [
                _header(isDark, textPrimary, textSecondary),
                const SizedBox(height: 22),
                _summary(),
                const SizedBox(height: 24),
                if (twoCol)
                  SizedBox(
                    height: workbenchH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 24),
                        SizedBox(width: cw >= 1300 ? 430 : 390, child: right),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(height: 640, child: left),
                  const SizedBox(height: 20),
                  SizedBox(height: 600, child: right),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────

  Widget _card(bool isDark, Color cardBg, Widget child) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _btn({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    Color? color,
  }) {
    final fg = color ?? (isDark ? Colors.white70 : Colors.black87);
    return Material(
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _header(bool isDark, Color textPrimary, Color textSecondary) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 14,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Grades',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track your results and plan your CGPA',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _btn(
              icon: s._cgpaHidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              label: s._cgpaHidden ? 'Show CGPA' : 'Hide CGPA',
              isDark: isDark,
              onTap: () {
                s._cgpaHidden = !s._cgpaHidden;
                s._savePref('cgpaHidden', s._cgpaHidden);
                setState(() {});
              },
            ),
            if (!kIsWeb)
              _btn(
                icon: Icons.share_rounded,
                label: 'Share',
                isDark: isDark,
                onTap: s._shareImage,
              ),
            _btn(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Export PDF',
              isDark: isDark,
              onTap: s._exportPDF,
            ),
            _btn(
              icon: Icons.delete_forever_rounded,
              label: 'Clear all',
              color: Colors.red,
              isDark: isDark,
              onTap: s._clearAll,
            ),
          ],
        ),
      ],
    );
  }

  // ── Summary strip: CGPA hero + stat cards ────────────────

  Widget _summary() {
    final top = s.topCourse;
    return SizedBox(
      height: 316,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _hero()),
          const SizedBox(width: 20),
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: s._statCard(
                          'Best Semester',
                          s.bestSemLabel,
                          Icons.emoji_events,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: s._statCard(
                          'Top Course',
                          top != null
                              ? '${top.name}\n(Score: ${top.score})'
                              : '—',
                          Icons.star,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: s._statCard(
                          'Total Units',
                          '${s.totalUnits} credits',
                          Icons.library_books,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: s._statCard(
                          'Courses Taken',
                          '${s.totalCourses}',
                          Icons.menu_book,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final profile = s.profile;
    final cgpa = s.cgpa;
    final maxGP = s.maxGP;

    return RepaintBoundary(
      key: s._shareKey,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _blue.withOpacity(0.3),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (profile.name.isNotEmpty) ...[
              Text(
                profile.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),
            ],
            const Text(
              'CGPA',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            Text(
              s._cgpaHidden ? '••••' : cgpa.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            if (!s._cgpaHidden)
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
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                s._pill('Courses', '${s.totalCourses}'),
                s._pill('Units', '${s.totalUnits}'),
                s._pill('Max GP', maxGP.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Left panel: Courses / Chart ───────────────────────────

  Widget _leftPanel(bool isDark, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              _segmented(isDark),
              const Spacer(),
              if (_view == 0)
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: textSecondary,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 16,
                                color: textSecondary,
                              ),
                              onPressed: () => setState(() {
                                _query = '';
                                _search.clear();
                              }),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
        Expanded(
          child: _view == 1
              ? s._buildChart()
              : _coursesPane(isDark, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _segmented(bool isDark) {
    const items = [
      (Icons.list_alt_rounded, 'Courses'),
      (Icons.show_chart_rounded, 'Chart'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => setState(() => _view = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: _view == i
                        ? const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 17,
                        color: _view == i
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _view == i
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coursesPane(bool isDark, Color textPrimary, Color textSecondary) {
    final searching = _query.trim().isNotEmpty;
    final y = (_sem ~/ 2) + 1;
    final sm = (_sem % 2) + 1;
    final list = s._semCourses(y, sm);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 204,
          child: _semesterRail(isDark, textPrimary, textSecondary),
        ),
        VerticalDivider(
          width: 1,
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
        Expanded(
          child: searching
              ? _resultsView(textPrimary, textSecondary)
              : _semesterView(y, sm, list, isDark, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _semesterRail(bool isDark, Color textPrimary, Color textSecondary) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 14,
      itemBuilder: (_, i) {
        final y = (i ~/ 2) + 1;
        final sm = (i % 2) + 1;
        final list = s._semCourses(y, sm);
        final selected = _sem == i && _query.trim().isEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                _sem = i;
                // keep the Add panel pointed at the semester being viewed
                s._selYear = y;
                s._selSem = sm;
                _query = '';
                _search.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Year $y · Sem $sm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: selected ? Colors.white : textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            list.isEmpty
                                ? 'No courses'
                                : '${list.length} course${list.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white70 : textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (list.isNotEmpty)
                      Text(
                        s._cgpaHidden ? '••' : s._gpa(list).toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : _blue,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _courseGrid(List<Course> list, double width) {
    final cols = width >= 640 ? 2 : 1;
    const gap = 12.0;
    final itemW = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      children: [
        for (final c in list)
          SizedBox(width: itemW, child: s._courseCard(c)),
      ],
    );
  }

  Widget _semesterView(
    int y,
    int sm,
    List<Course> list,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final units = list.fold<int>(0, (a, c) => a + c.unit);
    return LayoutBuilder(
      builder: (context, c) {
        const pad = 20.0;
        return ListView(
          padding: const EdgeInsets.all(pad),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Year $y · Semester $sm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                if (list.isNotEmpty) ...[
                  _chip(
                    s._cgpaHidden
                        ? 'GPA ••••'
                        : 'GPA ${s._gpa(list).toStringAsFixed(2)}',
                    _blue,
                  ),
                  _chip(
                    '${list.length} course${list.length == 1 ? '' : 's'}',
                    Colors.teal,
                  ),
                  _chip('$units units', Colors.purple),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 38,
                        color: _blue.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No courses yet',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use the panel on the right to add courses to this semester',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              _courseGrid(list, c.maxWidth - pad * 2),
          ],
        );
      },
    );
  }

  Widget _resultsView(Color textPrimary, Color textSecondary) {
    final q = _query.trim().toLowerCase();
    final results = s.courses
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
    return LayoutBuilder(
      builder: (context, c) {
        const pad = 20.0;
        return ListView(
          padding: const EdgeInsets.all(pad),
          children: [
            Text(
              results.isEmpty
                  ? 'No courses found'
                  : 'Search results (${results.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (results.isNotEmpty) _courseGrid(results, c.maxWidth - pad * 2),
          ],
        );
      },
    );
  }

  // ── Right panel: Add courses (+ tools) ────────────────────

  Widget _addPanel(bool isDark, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: _blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add courses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Year ${s._selYear} · Semester ${s._selSem}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
        Expanded(child: _addContent(isDark, textPrimary, textSecondary)),
      ],
    );
  }

  // ── Desktop Add content ───────────────────────────────────

  Widget _sectionLabel(String t, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: color,
      ),
    ),
  );

  Widget _pickChip({
    required String text,
    required bool selected,
    required bool isDark,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  )
                : null,
            color: selected
                ? null
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06)),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final titleColor = primary ? Colors.white : textPrimary;
    final subColor = primary ? Colors.white70 : textSecondary;
    return Material(
      color: primary
          ? _blue
          : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: primary
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: primary ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolTile({
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        hoverColor: color.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addContent(bool isDark, Color textPrimary, Color textSecondary) {
    void pick({int? year, int? sem}) => setState(() {
      if (year != null) s._selYear = year;
      if (sem != null) s._selSem = sem;
      _sem = (s._selYear - 1) * 2 + (s._selSem - 1);
      _query = '';
      _search.clear();
    });

    final period = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Year', textSecondary),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var y = 1; y <= 7; y++)
              _pickChip(
                text: 'Year $y',
                selected: s._selYear == y,
                isDark: isDark,
                textPrimary: textPrimary,
                onTap: () => pick(year: y),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('Semester', textSecondary),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var m = 1; m <= 2; m++)
              _pickChip(
                text: 'Semester $m',
                selected: s._selSem == m,
                isDark: isDark,
                textPrimary: textPrimary,
                onTap: () => pick(sem: m),
              ),
          ],
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Add courses', textSecondary),
        _actionTile(
          icon: Icons.table_rows_outlined,
          title: 'Enter courses manually',
          subtitle: 'Add several courses in one table',
          color: _blue,
          primary: true,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: s._showManualBatchEntry,
        ),
        const SizedBox(height: 10),
        _actionTile(
          icon: Icons.list_alt_rounded,
          title: 'Select from course list',
          subtitle: 'Pick from your department\'s courses',
          color: _blue,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: s._addFromPicker,
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.document_scanner_rounded,
            title: 'Scan result sheet',
            subtitle: 'Read courses from a photo',
            color: Colors.green.shade600,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: s._scanResultSheet,
          ),
        ],
      ],
    );

    final tools = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Tools', textSecondary),
        ResponsiveGrid(
          columns: 2,
          spacing: 12,
          runSpacing: 12,
          children: [
            _toolTile(
              icon: Icons.science_rounded,
              label: 'What-If',
              desc: 'Simulate different scores',
              color: Colors.purple,
              textSecondary: textSecondary,
              onTap: s._showWhatIf,
            ),
            _toolTile(
              icon: Icons.track_changes_rounded,
              label: 'Target',
              desc: 'Plan your target CGPA',
              color: Colors.teal,
              textSecondary: textSecondary,
              onTap: s._showTargetCalc,
            ),
            _toolTile(
              icon: Icons.calculate_outlined,
              label: 'Min Score',
              desc: 'Scores you need to reach it',
              color: Colors.indigo,
              textSecondary: textSecondary,
              onTap: s._showMinScoreCalc,
            ),
            _toolTile(
              icon: Icons.tune_rounded,
              label: 'Grading',
              desc: 'Edit your grade scale',
              color: Colors.orange,
              textSecondary: textSecondary,
              onTap: s._showGradingSettings,
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [period, const SizedBox(height: 24), actions],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 32),
                        Expanded(child: tools),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [left, const SizedBox(height: 24), tools],
                    ),
            ),
          ),
        );
      },
    );
  }
}