// ══════════════════════════════════════════════════════════
//  BECOME A CLASS REP — request screen (a full page, no sheet)
//  The server checks the name, matric number and level against the
//  student's profile, then the super admin reviews the request.
// ══════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/studentProfile_model.dart';
import '../providers/theme_notifier.dart';
import '../services/timetable_service.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_page.dart';
import '../widgets/snackBar.dart';

class RepRequestScreen extends StatefulWidget {
  const RepRequestScreen({super.key});

  @override
  State<RepRequestScreen> createState() => _RepRequestScreenState();
}

class _RepRequestScreenState extends State<RepRequestScreen> {
  static const Color _blue = Color(0xFF1565C0);
  static const _levels = ['100', '200', '300', '400', '500', '600', '700'];

  final _fk = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _matricC = TextEditingController();
  final _reasonC = TextEditingController();

  String _level = '100';
  int? _semester;
  String? _finalLevel;

  // shown in the "you will manage" card
  String _school = '';
  String _department = '';

  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _matricC.dispose();
    _reasonC.dispose();
    super.dispose();
  }

  /// Pre-fills the form from the profile, so it is quick to confirm.
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('profile');
      if (raw == null) return;
      final p = StudentProfile.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (!mounted) return;
      setState(() {
        _nameC.text = p.name;
        _matricC.text = p.matricNumber;
        if (_levels.contains(p.level)) _level = p.level;
        _school = p.school;
        _department = p.department;
      });
    } catch (_) {
      // the fields just stay empty
    }
  }

  /// Last-level choices: your current level up to 700.
  List<String> get _finalOptions =>
      _levels.where((l) => int.parse(l) >= int.parse(_level)).toList();

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _submit() async {
    if (_sending) return;
    if (!_fk.currentState!.validate()) return;
    if (_semester == null) {
      setState(() => _error = 'Choose your current semester.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await TimetableService().requestAdmin({
        'fullName': _nameC.text.trim(),
        'matricNumber': _matricC.text.trim(),
        'level': _level,
        'semester': _semester,
        'finalLevel': _finalLevel,
        'reason': _reasonC.text.trim(),
      });
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Request sent. You will be notified when it is reviewed.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _cleanError(e);
        });
      }
    }
  }

  // ── styling ───────────────────────────────────────────────
  InputDecoration _dec(
    String label,
    IconData icon,
    bool isDark, {
    String? helper,
  }) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _blue, size: 18),
        ),
        filled: true,
        fillColor:
            isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      );

  Widget _semesterChip(int n, bool isDark) {
    final selected = _semester == n;
    return GestureDetector(
      onTap: () => setState(() {
        _semester = n;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _blue : _blue.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: _blue.withOpacity(0.3)),
        ),
        child: Text(
          'Semester $n',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : (isDark ? Colors.white70 : _blue),
          ),
        ),
      ),
    );
  }

  Widget _form(bool isDark) {
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black54;
    final dropdownBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Form(
      key: _fk,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What they are asking to manage
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withOpacity(isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: _blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _department.isEmpty
                            ? 'Your class'
                            : '$_department · $_level level',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _school.isEmpty
                            ? 'Class reps manage the timetable and announcements for one class.'
                            : '$_school. Class reps manage the timetable and announcements for this class.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _nameC,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: text),
            decoration: _dec(
              'Full name',
              Icons.person_outline,
              isDark,
              helper: 'Must match the name in your profile.',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _matricC,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: text),
            decoration: _dec(
              'Matric number',
              Icons.badge_outlined,
              isDark,
              helper: 'Must match the matric number in your profile.',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _level,
            onChanged: (v) => setState(() {
              _level = v!;
              if (_finalLevel != null && !_finalOptions.contains(_finalLevel)) {
                _finalLevel = null;
              }
            }),
            style: TextStyle(color: text),
            dropdownColor: dropdownBg,
            decoration: _dec(
              'Current level',
              Icons.stairs_outlined,
              isDark,
              helper: 'Must be the level in your profile.',
            ),
            items: [
              for (final l in _levels)
                DropdownMenuItem(value: l, child: Text('$l Level')),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Current semester',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sub,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [_semesterChip(1, isDark), _semesterChip(2, isDark)],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _finalLevel,
            onChanged: (v) => setState(() => _finalLevel = v),
            style: TextStyle(color: text),
            dropdownColor: dropdownBg,
            hint: Text(
              'Choose',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            ),
            decoration: _dec(
              'Last level before graduation',
              Icons.flag_outlined,
              isDark,
              helper:
                  'Your programme may be longer or shorter than the usual 4 years.',
            ),
            items: [
              for (final l in _finalOptions)
                DropdownMenuItem(value: l, child: Text('$l Level')),
            ],
            validator: (v) => v == null ? 'Choose your last level' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _reasonC,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: text),
            decoration: _dec(
              'Anything to add? (optional)',
              Icons.notes_rounded,
              isDark,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(isDark ? 0.15 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: isDark ? Colors.redAccent : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: isDark ? Colors.redAccent : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _submitButton() => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 20),
          label: Text(
            _sending ? 'Sending…' : 'Send request',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _blue.withOpacity(0.35),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final text = isDark ? Colors.white : Colors.black87;

    // ── Desktop ──
    if (context.isExpanded) {
      return DesktopPage(
        title: 'Become a class rep',
        subtitle: 'Confirm your details. The super admin will review them.',
        maxWidth: 720,
        onBack: () => Navigator.pop(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              _form(isDark),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 260, child: _submitButton()),
              ),
            ],
          ),
        ),
      );
    }

    // ── Phone / tablet: header, scrolling form, button pinned at the bottom ──
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: text, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Become a class rep',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    responsiveSidePadding(c.maxWidth, maxWidth: 640),
                    8,
                    responsiveSidePadding(c.maxWidth, maxWidth: 640),
                    24,
                  ),
                  child: _form(isDark),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              child: _submitButton(),
            ),
          ],
        ),
      ),
    );
  }
}