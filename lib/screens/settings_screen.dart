import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_notifier.dart';
import '../widgets/update_check_tile.dart';
import '../models/studentProfile_model.dart';
import '../services/api_service.dart';
import '../screens/landing_page.dart';
import '../widgets/combo_field.dart';
import '../widgets/snackBar.dart';
import '../widgets/ui_helpers.dart';
import '../uniport_courses.dart';
import '../services/api_service.dart';
import '../widgets/notification_toggle.dart';
import '../widgets/personal_reminders_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StudentProfile profile = StudentProfile();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  static const Color _primary = Color(0xFF1565C0);

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final pd = prefs.getString('profile');
    if (pd != null) {
      setState(
        () => profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(jsonDecode(pd)),
        ),
      );
    }
    // Pull fresh from server
    try {
      final userData = await AuthService().getMe();
      if (userData['profile'] != null) {
        final fresh = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        setState(() => profile = fresh);
        await prefs.setString('profile', jsonEncode(fresh.toMap()));
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toMap()));
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final isDark = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ── Unified gradient header: title + profile ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x331565C0),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name.isNotEmpty ? profile.name : 'Your Name',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (profile.department.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.department,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _profileInfoBox(
                            Icons.account_balance,
                            'School',
                            profile.school,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _profileInfoBox(
                            Icons.badge_outlined,
                            'Matric',
                            profile.matricNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _profileInfoBox(
                            Icons.account_balance_outlined,
                            'Faculty',
                            profile.faculty,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _profileInfoBox(
                            Icons.school_outlined,
                            'Department',
                            profile.department,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Settings sections ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _sectionLabel('Appearance', isDark),
                const SizedBox(height: 8),
                _buildCard(isDark, [
                  _switchTile(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    iconColor: _primary,
                    title: 'Dark Mode',
                    subtitle: isDark ? 'Using dark theme' : 'Using light theme',
                    value: isDark,
                    onChanged: (_) => themeNotifier.toggleTheme(),
                    isDark: isDark,
                  ),
                ]),
                const SizedBox(height: 20),

                _sectionLabel('Notifications', isDark),
                const SizedBox(height: 8),
                _buildCard(isDark, [
                  const NotificationToggle(),
                  const PersonalRemindersToggle(),
                ]),
                const SizedBox(height: 20),

                _sectionLabel('Account', isDark),
                const SizedBox(height: 8),
                _buildCard(isDark, [
                  _actionTile(
                    icon: Icons.edit_outlined,
                    iconColor: _primary,
                    title: 'Edit Profile',
                    subtitle: 'Update your name, school, department',
                    onTap: () => _showEditProfile(isDark),
                    isDark: isDark,
                  ),
                  _divider(isDark),
                  _actionTile(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.orange,
                    title: 'Sign Out',
                    subtitle: 'Log out of your GradeX account',
                    onTap: _signOut,
                    isDark: isDark,
                    textColor: Colors.orange,
                  ),
                  _divider(isDark),
                  _actionTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your account and data',
                    onTap: _deleteAccount,
                    isDark: isDark,
                    textColor: Colors.red,
                  ),
                ]),
                const SizedBox(height: 20),

                _sectionLabel('About', isDark),
                const SizedBox(height: 8),
                _buildCard(isDark, [
                  _actionTile(
                    icon: Icons.verified_outlined,
                    iconColor: Colors.green,
                    title: 'App Version',
                    subtitle: 'GradeX v1.0.0',
                    onTap: null,
                    isDark: isDark,
                  ),
                ]),
                const SizedBox(height: 20),
                _sectionLabel('App Update', isDark),
                const SizedBox(height: 8),
                _buildCard(isDark, [
                  const UpdateCheckTile(),
                ]),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileInfoBox(IconData icon, String label, String value) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 9, color: Colors.white60),
                  ),
                  Text(
                    value.isNotEmpty ? value : '—',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String? _findBestMatch(String input, List<String> options) {
    final query = input.toLowerCase().trim();
    if (query.isEmpty) return null;

    for (final opt in options) {
      if (opt.toLowerCase().trim() == query) return opt;
    }

    final substringMatches = options
        .where((opt) => opt.toLowerCase().contains(query))
        .toList();
    if (substringMatches.length == 1) return substringMatches.first;

    if (substringMatches.isEmpty) {
      final reverseMatches = options
          .where((opt) => query.contains(opt.toLowerCase()))
          .toList();
      if (reverseMatches.length == 1) return reverseMatches.first;
    }

    final wordMatches = options.where((opt) {
      final words = opt.toLowerCase().split(RegExp(r'\s+'));
      return words.any((w) => w.startsWith(query) || query.startsWith(w));
    }).toList();
    if (wordMatches.length == 1) return wordMatches.first;

    return null;
  }

  void _showEditProfile(bool isDark) {
    final fk = GlobalKey<FormState>();
    final nameC = TextEditingController(text: profile.name);
    final emailC = TextEditingController(text: profile.email);
    final matricC = TextEditingController(text: profile.matricNumber);
    final schoolC = TextEditingController(text: profile.school);
    final facC = TextEditingController(text: profile.faculty);
    final deptC = TextEditingController(text: profile.department);
    String selectedLevel = profile.level.isNotEmpty ? profile.level : '100';

    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final fillColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Edit Profile', style: TextStyle(color: textColor)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: fk,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField(
                    nameC,
                    'Full Name',
                    Icons.person_outline,
                    textColor,
                    labelColor,
                    fillColor,
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    emailC,
                    'Email',
                    Icons.email_outlined,
                    textColor,
                    labelColor,
                    fillColor,
                    (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.trim().contains('@'))
                        return 'Email must contain @';
                      if (!isValidEmail(v.trim())) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    matricC,
                    'Matric Number',
                    Icons.badge_outlined,
                    textColor,
                    labelColor,
                    fillColor,
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  ComboField(
                    controller: schoolC,
                    label: 'School / University',
                    icon: Icons.account_balance,
                    suggestions: getAllSchools(),
                    dark: !isDark,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (_findBestMatch(v, getAllSchools()) == null) {
                        return 'Please select a valid school from the list';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ComboField(
                    controller: facC,
                    label: 'Faculty',
                    icon: Icons.account_balance_outlined,
                    suggestions: getFaculties(),
                    dark: !isDark,
                    onSuggestionSelected: (_) => setD(() => deptC.clear()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (_findBestMatch(v, getFaculties()) == null) {
                        return 'Please select a valid faculty from the list';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (_, setSub) {
                      final deptOptions = facC.text.trim().isNotEmpty
                          ? getDepartments(facC.text.trim())
                          : <String>[];
                      return ComboField(
                        controller: deptC,
                        label: 'Department',
                        icon: Icons.school_outlined,
                        suggestions: deptOptions,
                        dark: !isDark,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (_findBestMatch(v, deptOptions) == null) {
                            return 'Please select a valid department from the list';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    onChanged: (v) => setD(() => selectedLevel = v!),
                    style: TextStyle(color: textColor),
                    dropdownColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Level',
                      prefixIcon: const Icon(
                        Icons.stairs_outlined,
                        color: Colors.blue,
                      ),
                      filled: true,
                      fillColor: fillColor,
                      labelStyle: TextStyle(color: labelColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    items: ['100', '200', '300', '400', '500', '600', '700']
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text('$l Level'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!fk.currentState!.validate()) return;

                final canonicalSchool =
                    _findBestMatch(schoolC.text, getAllSchools()) ??
                    schoolC.text.trim();
                final canonicalFaculty =
                    _findBestMatch(facC.text, getFaculties()) ??
                    facC.text.trim();
                final deptOptions = getDepartments(canonicalFaculty);
                final canonicalDept =
                    _findBestMatch(deptC.text, deptOptions) ??
                    deptC.text.trim();

                final updated = StudentProfile(
                  name: nameC.text.trim(),
                  email: emailC.text.trim(),
                  matricNumber: matricC.text.trim(),
                  school: canonicalSchool,
                  faculty: canonicalFaculty,
                  department: canonicalDept,
                  level: selectedLevel,
                );
                setState(() => profile = updated);
                await _saveProfile();
                if (ctx.mounted) Navigator.pop(ctx);
                ProfileService()
                    .updateProfile(updated.toMap())
                    .then(
                      (_) =>
                          AppSnackBar.showSuccess(context, 'Profile updated ✓'),
                    )
                    .catchError(
                      (e) => AppSnackBar.showError(
                        context,
                        'Saved locally. Server: $e',
                      ),
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to sign out? '
          'Your data will remain saved locally.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AuthService().logout();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('refreshToken');
    await prefs.remove('savedEmail');

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeRoute(const LandingPage()), (_) => false);
  }

  // ── Delete Account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'This will permanently delete your account and all data. '
          'This cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ProfileService().deleteAccount();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeRoute(const LandingPage()), (_) => false);
  }

  // ── _editField ────────────────────────────────────────────────────────────
  Widget _editField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    Color textColor,
    Color labelColor,
    Color fillColor,
    String? Function(String?) validator,
  ) => TextFormField(
    controller: ctrl,
    style: TextStyle(color: textColor),
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor),
      prefixIcon: Icon(icon, color: Colors.blue, size: 20),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  // ── UI helpers ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark ? Colors.indigo.shade300 : Colors.blue.shade700,
      ),
    ),
  );

  Widget _buildCard(bool isDark, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(children: children),
  );

  Widget _divider(bool isDark) => Divider(
    height: 1,
    indent: 52,
    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
  );

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        _iconBox(icon, iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
      ],
    ),
  );

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isDark,
    Color? textColor,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _iconBox(icon, iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color:
                        textColor ?? (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
        ],
      ),
    ),
  );

  Widget _iconBox(IconData icon, Color color) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: 18),
  );
}
