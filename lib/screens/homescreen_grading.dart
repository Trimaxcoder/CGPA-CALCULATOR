part of 'homescreen.dart';

// ══════════════════════════════════════════════════════════
//  GRADING SYSTEM EDITOR  (replaces the old _showGradingSettings)
//  Opens as a bottom sheet from the "Grading" tool and the ⋯ menu.
//  Presets only fill the fields — nothing changes until you press Save.
// ══════════════════════════════════════════════════════════

Future<void> _showGradingSheet(BuildContext context, _HomeScreenState s) async {
  try {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GradingSheet(s: s),
    );
  } catch (e) {
    AppSnackBar.showError(context, 'Could not open the grading system: $e');
  }
}

class _GRow {
  _GRow(this.grade, int min, double gp)
    : min = TextEditingController(text: '$min'),
      gp = TextEditingController(text: gp.toStringAsFixed(1));

  final String grade;
  final TextEditingController min;
  final TextEditingController gp;

  void dispose() {
    min.dispose();
    gp.dispose();
  }
}

class _GradingSheet extends StatefulWidget {
  const _GradingSheet({required this.s});

  final _HomeScreenState s;

  @override
  State<_GradingSheet> createState() => _GradingSheetState();
}

class _GradingSheetState extends State<_GradingSheet> {
  static const Color _blue = Color(0xFF1565C0);

  late List<_GRow> _rows;
  String? _error;
  bool _saving = false;

  _HomeScreenState get s => widget.s;

  @override
  void initState() {
    super.initState();
    _rows = _build(s.grading.rules);
  }

  List<_GRow> _build(List<GradeRule> rules) => [
    for (final r in rules) _GRow(r.grade, r.minScore, r.gradePoint),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _applyPreset(GradingModel preset) {
    final old = _rows;
    setState(() {
      _rows = _build(preset.rules);
      _error = null;
    });
    // dispose the old controllers only after the new rows are on screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in old) {
        r.dispose();
      }
    });
  }

  String? _validate() {
    int? previous;
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final last = i == _rows.length - 1;
      final min = last ? 0 : int.tryParse(r.min.text.trim());
      final gp = double.tryParse(r.gp.text.trim());
      if (min == null || min < 0 || min > 100) {
        return 'Grade ${r.grade}: minimum score must be 0–100';
      }
      if (gp == null || gp < 0) {
        return 'Grade ${r.grade}: enter a valid grade point';
      }
      if (previous != null && min >= previous) {
        return 'Minimum scores must go from high to low (check ${r.grade})';
      }
      previous = min;
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      AppSnackBar.showError(context, err);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final rules = <GradeRule>[
      for (var i = 0; i < _rows.length; i++)
        GradeRule(
          grade: _rows[i].grade,
          minScore: i == _rows.length - 1
              ? 0
              : int.parse(_rows[i].min.text.trim()),
          gradePoint: double.parse(_rows[i].gp.text.trim()),
        ),
    ];

    s.grading = GradingModel(rules: rules);
    await s._saveGrading();

    // keep the server in sync (both presets and custom scales)
    try {
      await ProfileService().updateGrading([
        for (final r in rules)
          {
            'grade': r.grade,
            'minScore': r.minScore,
            'gradePoint': r.gradePoint,
          },
      ]);
    } catch (e) {
      debugPrint('Grading server save failed: $e');
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    AppSnackBar.showSuccess(context, 'Grading system updated ✓');
  }

  InputDecoration _deco(String label, bool isDark, {bool enabled = true}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        isDense: true,
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(enabled ? 0.06 : 0.03)
            : (enabled ? const Color(0xFFF5F7FA) : Colors.grey.shade200),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    Widget presetChip(String label, GradingModel Function() preset) => Expanded(
      child: OutlinedButton(
        onPressed: () => _applyPreset(preset()),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: BorderSide(color: _blue.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15181D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.orange),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grading system',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: text,
                          ),
                        ),
                        Text(
                          'Minimum score and grade point for each grade',
                          style: TextStyle(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  presetChip('5.0 scale', GradingModel.defaultNigerian5),
                  const SizedBox(width: 10),
                  presetChip('4.0 scale', GradingModel.defaultNigerian4),
                ],
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: s
                                  ._gradeColor(_rows[i].grade)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Text(
                                _rows[i].grade,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: s._gradeColor(_rows[i].grade),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].min,
                              enabled: i != _rows.length - 1,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: text, fontSize: 14),
                              decoration: _deco(
                                i == _rows.length - 1
                                    ? 'Below all'
                                    : 'Min score',
                                isDark,
                                enabled: i != _rows.length - 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].gp,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: text, fontSize: 14),
                              decoration: _deco('Grade point', isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save grading system',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
