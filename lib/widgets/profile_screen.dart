// ══════════════════════════════════════════════════════════
//  PROFILE SCREEN — edit your details
//  Opened from Settings. Pops with the updated StudentProfile.
// ══════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/studentProfile_model.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../uniport_courses.dart';
import '../utils/responsive.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/combo_field.dart';
import '../widgets/desktop_page.dart';
import '../widgets/snackBar.dart';
import '../widgets/ui_helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final StudentProfile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _blue = Color(0xFF1565C0);

  final _fk = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _emailC;
  late final TextEditingController _matricC;
  late final TextEditingController _schoolC;
  late final TextEditingController _facC;
  late final TextEditingController _deptC;
  late String _level;
  bool _saving = false;

  static const _levels = ['100', '200', '300', '400', '500', '600', '700'];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameC = TextEditingController(text: p.name);
    _emailC = TextEditingController(text: p.email);
    _matricC = TextEditingController(text: p.matricNumber);
    _schoolC = TextEditingController(text: p.school);
    _facC = TextEditingController(text: p.faculty);
    _deptC = TextEditingController(text: p.department);
    _level = p.level.isNotEmpty ? p.level : '100';
    for (final c in [_nameC, _emailC, _matricC, _schoolC, _facC, _deptC]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_nameC, _emailC, _matricC, _schoolC, _facC, _deptC]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty {
    final p = widget.profile;
    return _nameC.text.trim() != p.name ||
        _emailC.text.trim() != p.email ||
        _matricC.text.trim() != p.matricNumber ||
        _schoolC.text.trim() != p.school ||
        _facC.text.trim() != p.faculty ||
        _deptC.text.trim() != p.department ||
        _level != (p.level.isNotEmpty ? p.level : '100');
  }

  String? _findBestMatch(String input, List<String> options) {
    final query = input.toLowerCase().trim();
    if (query.isEmpty) return null;

    for (final opt in options) {
      if (opt.toLowerCase().trim() == query) return opt;
    }
    final sub = options.where((o) => o.toLowerCase().contains(query)).toList();
    if (sub.length == 1) return sub.first;

    if (sub.isEmpty) {
      final rev = options.where((o) => query.contains(o.toLowerCase())).toList();
      if (rev.length == 1) return rev.first;
    }
    final words = options.where((o) {
      final w = o.toLowerCase().split(RegExp(r'\s+'));
      return w.any((x) => x.startsWith(query) || query.startsWith(x));
    }).toList();
    if (words.length == 1) return words.first;
    return null;
  }

  Future<void> _back() async {
    if (_dirty && !_saving) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard changes?',
        message: 'You have unsaved changes to your profile.',
        confirmLabel: 'Discard',
        icon: Icons.edit_off_rounded,
        color: Colors.orange,
      );
      if (!discard) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _saving = true);

    final school = _findBestMatch(_schoolC.text, getAllSchools()) ?? _schoolC.text.trim();
    final faculty = _findBestMatch(_facC.text, getFaculties()) ?? _facC.text.trim();
    final dept = _findBestMatch(_deptC.text, getDepartments(faculty)) ??
        _deptC.text.trim();

    final updated = StudentProfile(
      name: _nameC.text.trim(),
      email: _emailC.text.trim(),
      matricNumber: _matricC.text.trim(),
      school: school,
      faculty: faculty,
      department: dept,
      level: _level,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(updated.toMap()));

    String? serverError;
    try {
      await ProfileService().updateProfile(updated.toMap());
    } catch (e) {
      serverError = '$e';
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (serverError == null) {
      AppSnackBar.showSuccess(context, 'Profile updated ✓');
    } else {
      AppSnackBar.showError(context, 'Saved on this device. Server: $serverError');
    }
    Navigator.pop(context, updated);
  }

  // ── styling helpers ───────────────────────────────────────
  InputDecoration _dec(String label, IconData icon, bool isDark) =>
      InputDecoration(
        labelText: label,
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
        fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      );

  Widget _section(String label, List<Widget> fields, bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF15181D) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          fields[i],
        ],
      ],
    ),
  );

  Widget _textField(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark,
    String? Function(String?) validator, {
    TextInputType? keyboard,
    TextCapitalization cap = TextCapitalization.none,
  }) => TextFormField(
    controller: c,
    keyboardType: keyboard,
    textCapitalization: cap,
    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
    validator: validator,
    decoration: _dec(label, icon, isDark),
  );

  List<Widget> _formChildren(bool isDark) {
    final initial = _nameC.text.trim().isNotEmpty
        ? _nameC.text.trim()[0].toUpperCase()
        : '?';
    final text = isDark ? Colors.white : Colors.black87;

    return [
      // avatar
      Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _nameC.text.trim().isEmpty ? 'Your name' : _nameC.text.trim(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _section('Personal', [
        _textField(
          _nameC,
          'Full name',
          Icons.person_outline,
          isDark,
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          cap: TextCapitalization.words,
        ),
        _textField(
          _emailC,
          'Email',
          Icons.email_outlined,
          isDark,
          (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!isValidEmail(v.trim())) return 'Enter a valid email';
            return null;
          },
          keyboard: TextInputType.emailAddress,
        ),
        _textField(
          _matricC,
          'Matric number',
          Icons.badge_outlined,
          isDark,
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          cap: TextCapitalization.characters,
        ),
      ], isDark),
      const SizedBox(height: 16),
      _section('Academic', [
        ComboField(
          controller: _schoolC,
          label: 'School / University',
          icon: Icons.account_balance,
          suggestions: getAllSchools(),
          dark: !isDark,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (_findBestMatch(v, getAllSchools()) == null) {
              return 'Select a valid school from the list';
            }
            return null;
          },
        ),
        ComboField(
          controller: _facC,
          label: 'Faculty',
          icon: Icons.account_balance_outlined,
          suggestions: getFaculties(),
          dark: !isDark,
          onSuggestionSelected: (_) => setState(() => _deptC.clear()),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (_findBestMatch(v, getFaculties()) == null) {
              return 'Select a valid faculty from the list';
            }
            return null;
          },
        ),
        Builder(
          builder: (_) {
            final opts = _facC.text.trim().isNotEmpty
                ? getDepartments(_facC.text.trim())
                : <String>[];
            return ComboField(
              controller: _deptC,
              label: 'Department',
              icon: Icons.school_outlined,
              suggestions: opts,
              dark: !isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (_findBestMatch(v, opts) == null) {
                  return 'Select a valid department from the list';
                }
                return null;
              },
            );
          },
        ),
        DropdownButtonFormField<String>(
          value: _level,
          onChanged: (v) => setState(() => _level = v!),
          style: TextStyle(color: text),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          decoration: _dec('Level', Icons.stairs_outlined, isDark),
          items: [
            for (final l in _levels)
              DropdownMenuItem(value: l, child: Text('$l Level')),
          ],
        ),
      ], isDark),
    ];
  }

  Widget _saveButton() => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton.icon(
      onPressed: (_saving || !_dirty) ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_rounded),
      label: Text(
        _saving ? 'Saving…' : 'Save changes',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _blue.withOpacity(0.35),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final text = isDark ? Colors.white : Colors.black87;

    final form = Form(
      key: _fk,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(children: _formChildren(isDark)),
    );

    // ── Desktop ──
    if (context.isExpanded) {
      return DesktopPage(
        title: 'Profile',
        subtitle: 'Update your personal and academic details',
        maxWidth: 820,
        onBack: _back,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              form,
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 260, child: _saveButton()),
              ),
            ],
          ),
        ),
      );
    }

    // ── Phone / tablet ──
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
                    onTap: _back,
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
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => ListView(
                  padding: EdgeInsets.fromLTRB(
                    responsiveSidePadding(c.maxWidth, maxWidth: 640),
                    8,
                    responsiveSidePadding(c.maxWidth, maxWidth: 640),
                    24,
                  ),
                  children: staggered([form], stepMs: 60),
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
              child: _saveButton(),
            ),
          ],
        ),
      ),
    );
  }
}