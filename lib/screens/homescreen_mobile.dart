part of 'homescreen.dart';

// ══════════════════════════════════════════════════════════
//  GRADES — PHONE / TABLET LAYOUT
//  Same design language as the Timetable: light header, sliding switch,
//  tinted blocks, soft cards, pull-to-refresh everywhere.
//  Tabs: Add · Courses · Chart · Summary   ("Clear all" moved to the menu)
// ══════════════════════════════════════════════════════════

class _GradesMobile extends StatefulWidget {
  const _GradesMobile({required this.s});

  final _HomeScreenState s;

  @override
  State<_GradesMobile> createState() => _GradesMobileState();
}

class _GradesMobileState extends State<_GradesMobile>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF1565C0);
  static const Color _teal = Color(0xFF0891B2);
  static const Color _purple = Color(0xFF7C3AED);

  late final TabController _tab = TabController(length: 4, vsync: this);
  final _search = TextEditingController();
  String _query = '';

  _HomeScreenState get s => widget.s;

  @override
  void initState() {
    super.initState();
    // rebuild when the tab changes (FAB visibility, switch colours)
    _tab.addListener(() {
      if (mounted && !_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── shared bits ───────────────────────────────────────────
  BoxDecoration _deco(bool isDark) => BoxDecoration(
    color: isDark ? const Color(0xFF15181D) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _label(String t, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    ),
  );

  Future<void> _refresh() => s._syncWithServer();

  void _select(int y, int sm) {
    s._selYear = y;
    s._selSem = sm;
    setState(() {});
  }

  List<Course> get _semCourses => s._semCourses(s._selYear, s._selSem);

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _tab.animateTo(0),
              icon: const Icon(Icons.add),
              label: const Text('Add course'),
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(isDark),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _switch(isDark),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _addTab(isDark),
                  _coursesTab(isDark),
                  _chartTab(isDark),
                  _summaryTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _header(bool isDark) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    Widget tile(Widget child) => Container(
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
      child: child,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grades',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${s.totalCourses} course${s.totalCourses == 1 ? '' : 's'} · ${s.totalUnits} units',
                  style: TextStyle(fontSize: 13, color: sub),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              s._cgpaHidden = !s._cgpaHidden;
              s._savePref('cgpaHidden', s._cgpaHidden);
              setState(() {});
            },
            child: tile(
              Icon(
                s._cgpaHidden
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'More',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            onSelected: (v) {
              switch (v) {
                case 'grading':
                  s._showGradingSettings();
                  break;
                case 'pdf':
                  s._exportPDF();
                  break;
                case 'clear':
                  s._clearAll();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'grading',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Grading system'),
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_rounded),
                  title: Text('Export PDF'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: Text(
                    'Clear all courses',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            child: tile(Icon(Icons.more_horiz_rounded, size: 22, color: text)),
          ),
        ],
      ),
    );
  }

  // ── Sliding switch ────────────────────────────────────────
  Widget _switch(bool isDark) {
    const items = [
      (Icons.add_circle_outline_rounded, 'Add'),
      (Icons.list_alt_rounded, 'Courses'),
      (Icons.show_chart_rounded, 'Chart'),
      (Icons.dashboard_rounded, 'Summary'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / items.length;
        return Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _tab.animation!,
            builder: (context, _) {
              final v = _tab.animation!.value;
              return Stack(
                children: [
                  Positioned(
                    left: v * w,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _tab.animateTo(i),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      items[i].$1,
                                      size: 16,
                                      color: (v - i).abs() < 0.5
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white54
                                                : Colors.black54),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      items[i].$2,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: (v - i).abs() < 0.5
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white54
                                                  : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  YEAR + SEMESTER PICKER  (shared by Add and Courses)
  // ══════════════════════════════════════════════════════════
  Widget _chip(
    String text,
    bool selected,
    VoidCallback onTap,
    bool isDark, {
    double height = 40,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  )
                : null,
            color: selected
                ? null
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodPicker(bool isDark, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: _deco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) _label('Year', isDark),
          Row(
            children: [
              for (var y = 1; y <= 7; y++) ...[
                if (y > 1) const SizedBox(width: 6),
                Expanded(
                  child: _chip(
                    'Y$y',
                    s._selYear == y,
                    () => _select(y, s._selSem),
                    isDark,
                    height: compact ? 36 : 40,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          if (!compact) _label('Semester', isDark),
          Row(
            children: [
              Expanded(
                child: _chip(
                  'Semester 1',
                  s._selSem == 1,
                  () => _select(s._selYear, 1),
                  isDark,
                  height: compact ? 36 : 40,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  'Semester 2',
                  s._selSem == 2,
                  () => _select(s._selYear, 2),
                  isDark,
                  height: compact ? 36 : 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ADD TAB
  // ══════════════════════════════════════════════════════════
  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final titleColor = primary
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final subColor = primary
        ? Colors.white70
        : (isDark ? Colors.white54 : Colors.black45);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: primary
            ? BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : _deco(isDark),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: primary ? Colors.white : color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subColor),
          ],
        ),
      ),
    );
  }

  Widget _toolTile(
    IconData icon,
    String label,
    String desc,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
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
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addTab(bool isDark) {
    final here = _semCourses.length;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return RefreshIndicator(
      color: _blue,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          _label('Add to', isDark),
          _periodPicker(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'Year ${s._selYear} · Semester ${s._selSem} — '
              '${here == 0 ? 'no courses yet' : '$here course${here == 1 ? '' : 's'} so far'}',
              style: TextStyle(fontSize: 12, color: sub),
            ),
          ),
          const SizedBox(height: 24),
          _label('Add courses', isDark),
          _actionTile(
            icon: Icons.table_rows_outlined,
            title: 'Enter courses manually',
            subtitle: 'Add several courses in one table',
            color: _blue,
            primary: true,
            isDark: isDark,
            onTap: s._showManualBatchEntry,
          ),
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.list_alt_rounded,
            title: 'Select from course list',
            subtitle: 'Pick from your department\'s courses',
            color: _blue,
            isDark: isDark,
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
              onTap: s._scanResultSheet,
            ),
          ],
          const SizedBox(height: 24),
          _label('Tools', isDark),
          Row(
            children: [
              Expanded(
                child: _toolTile(
                  Icons.science_rounded,
                  'What-If',
                  'Simulate different scores',
                  _purple,
                  isDark,
                  s._showWhatIf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _toolTile(
                  Icons.track_changes_rounded,
                  'Target',
                  'Plan your target CGPA',
                  _teal,
                  isDark,
                  s._showTargetCalc,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _toolTile(
                  Icons.calculate_outlined,
                  'Min Score',
                  'Scores you need to reach it',
                  Colors.indigo,
                  isDark,
                  s._showMinScoreCalc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _toolTile(
                  Icons.tune_rounded,
                  'Grading',
                  'Edit your grade scale',
                  Colors.orange,
                  isDark,
                  s._showGradingSettings,
                ),
              ),
            ],
          ),
        ], stepMs: 50),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  COURSES TAB
  // ══════════════════════════════════════════════════════════
  Widget _coursesTab(bool isDark) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final searching = _query.trim().isNotEmpty;

    final list = searching
        ? s.courses
              .where(
                (c) => c.name.toLowerCase().contains(_query.trim().toLowerCase()),
              )
              .toList()
        : _semCourses;

    return Column(
      children: [
        // search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search all courses',
              hintStyle: TextStyle(color: sub, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
              suffixIcon: searching
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: sub, size: 18),
                      onPressed: () => setState(() {
                        _query = '';
                        _search.clear();
                      }),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        if (!searching) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _periodPicker(isDark, compact: true),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _semesterSummary(isDark, list),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                list.isEmpty
                    ? 'No courses found'
                    : '${list.length} result${list.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sub,
                ),
              ),
            ),
          ),

        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            color: _blue,
            onRefresh: _refresh,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('${searching}_${s._selYear}_${s._selSem}'),
                child: list.isEmpty
                    ? _emptyCourses(isDark, searching)
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        children: staggered([
                          for (final c in list)
                            _courseCard(c, isDark, showPeriod: searching),
                        ], stepMs: 45),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _semesterSummary(bool isDark, List<Course> list) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final gpa = s._gpa(list);
    final max = s.maxGP > 0 ? s.maxGP : 5.0;
    final color = degreeColor(gpa, max);
    final units = list.fold<int>(0, (a, c) => a + c.unit);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _deco(isDark),
      child: Row(
        children: [
          ProgressRing(
            size: 52,
            strokeWidth: 6,
            value: list.isEmpty || s._cgpaHidden ? 0 : gpa / max,
            color: color,
            child: Icon(Icons.school_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Year ${s._selYear} · Semester ${s._selSem}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                Text(
                  '${list.length} course${list.length == 1 ? '' : 's'} · $units units',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
          if (list.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s._cgpaHidden ? 'GPA ••' : 'GPA ${gpa.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyCourses(bool isDark, bool searching) {
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: c.maxHeight < 260 ? 260 : c.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        searching
                            ? Icons.search_off_rounded
                            : Icons.inbox_outlined,
                        size: 40,
                        color: _blue.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      searching
                          ? 'No matching courses'
                          : 'No courses in Year ${s._selYear} · Sem ${s._selSem}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (!searching) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Add your courses to start tracking this semester',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _tab.animateTo(0),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add courses'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _blue,
                          side: BorderSide(color: _blue.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _courseCard(Course c, bool isDark, {bool showPeriod = false}) {
    final grade = s.grading.getGrade(c.score);
    final gp = s.grading.getPoint(c.score);
    final color = scoreColor(c.score);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(c.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          return true;
        },
        onDismissed: (_) => s._deleteCourse(c, atIndex: s.courses.indexOf(c)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _deco(isDark),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── grade block ──
              Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.score}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    if (c.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: sub),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniChip('${c.unit} unit${c.unit == 1 ? '' : 's'}', _blue),
                        _miniChip('GP ${gp.toStringAsFixed(1)}', _teal),
                        if (showPeriod)
                          _miniChip('Y${c.year} · S${c.semester}', _purple),
                      ],
                    ),
                  ],
                ),
              ),

              // ── menu ──
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') {
                    s._editCourse(c);
                  } else {
                    s._deleteCourse(c);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CHART TAB
  // ══════════════════════════════════════════════════════════
  Widget _noDataState(bool isDark, String text) => LayoutBuilder(
    builder: (context, c) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: c.maxHeight < 300 ? 300 : c.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 40,
                    color: _blue.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chartTab(bool isDark) {
    if (s.courses.isEmpty) {
      return RefreshIndicator(
        color: _blue,
        onRefresh: _refresh,
        child: _noDataState(isDark, 'Add courses to see your GPA trend'),
      );
    }
    return RefreshIndicator(
      color: _blue,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          Container(height: 340, decoration: _deco(isDark), child: s._buildChart()),
          const SizedBox(height: 16),
          s._gradeDistributionCard(),
          const SizedBox(height: 20),
          s._semesterRings(),
        ], stepMs: 70),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SUMMARY TAB
  // ══════════════════════════════════════════════════════════
  Widget _summaryTab(bool isDark) {
    if (s.courses.isEmpty) {
      return RefreshIndicator(
        color: _blue,
        onRefresh: _refresh,
        child: _noDataState(isDark, 'Your summary appears here'),
      );
    }

    final cgpa = s.cgpa;
    final maxGP = s.maxGP > 0 ? s.maxGP : 5.0;
    final top = s.topCourse;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    // compact, shareable CGPA card (replaces the huge blue block)
    final hero = RepaintBoundary(
      key: s._shareKey,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _blue.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ProgressRing(
              size: 104,
              strokeWidth: 10,
              value: s._cgpaHidden ? 0 : cgpa / maxGP,
              color: Colors.white,
              trackColor: Colors.white24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CGPA',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  s._cgpaHidden
                      ? const Text(
                          '••••',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : AnimatedCount(
                          value: cgpa,
                          decimals: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.profile.name.isNotEmpty)
                    Text(
                      s.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (s.profile.department.isNotEmpty)
                    Text(
                      s.profile.department,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (!s._cgpaHidden)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        getDegreeClass(cgpa, maxGP),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${s.totalCourses} courses · ${s.totalUnits} units',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget actionBtn(IconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 17),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: BorderSide(color: _blue.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );

    Widget stat(IconData icon, Color color, String value, String label) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _deco(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, color: sub)),
            ],
          ),
        );

    return RefreshIndicator(
      color: _blue,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          hero,
          const SizedBox(height: 12),
          Row(
            children: [
              if (!kIsWeb) ...[
                actionBtn(Icons.share_rounded, 'Share', s._shareImage),
                const SizedBox(width: 10),
              ],
              actionBtn(Icons.picture_as_pdf_rounded, 'PDF', s._exportPDF),
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            columns: 2,
            spacing: 12,
            runSpacing: 12,
            children: [
              stat(Icons.emoji_events_rounded, Colors.amber, s.bestSemLabel,
                  'Best semester'),
              stat(
                Icons.star_rounded,
                Colors.green,
                top != null ? '${top.name} (${top.score})' : '—',
                'Top course',
              ),
              stat(Icons.library_books_rounded, _blue, '${s.totalUnits}',
                  'Total units'),
              stat(Icons.menu_book_rounded, _purple, '${s.totalCourses}',
                  'Courses taken'),
            ],
          ),
          const SizedBox(height: 20),
          s._gradeDistributionCard(),
          const SizedBox(height: 20),
          s._semesterRings(),
        ], stepMs: 70),
      ),
    );
  }
}