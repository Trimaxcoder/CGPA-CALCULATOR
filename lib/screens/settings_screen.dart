import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_notifier.dart';
import '../widgets/update_check_tile.dart';
import '../models/studentProfile_model.dart';
import '../services/api_service.dart';
import '../screens/landing_page.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/snackBar.dart';
import '../widgets/ui_helpers.dart';
import '../utils/responsive.dart';
import '../widgets/notification_toggle.dart';
import '../widgets/personal_reminders_toggle.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _blue = Color(0xFF1565C0);
  static const Color _teal = Color(0xFF0891B2);
  static const Color _purple = Color(0xFF7C3AED);

  StudentProfile profile = StudentProfile();
  bool _hideCgpa = false;

  /// Selected category on desktop
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPrefs();
  }

  // ── data ──────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final pd = prefs.getString('profile');
    if (pd != null && mounted) {
      setState(
        () => profile = StudentProfile.fromMap(
          Map<String, dynamic>.from(jsonDecode(pd)),
        ),
      );
    }
    // pull fresh from the server (also used by pull-to-refresh)
    try {
      final userData = await AuthService().getMe();
      if (userData['profile'] != null) {
        final fresh = StudentProfile.fromMap(
          Map<String, dynamic>.from(userData['profile'] as Map),
        );
        if (!mounted) return;
        setState(() => profile = fresh);
        await prefs.setString('profile', jsonEncode(fresh.toMap()));
      }
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hideCgpa = prefs.getBool('cgpaHidden') ?? false);
  }

  Future<void> _setHideCgpa(bool v) async {
    setState(() => _hideCgpa = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cgpaHidden', v);
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.push<StudentProfile>(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(profile: profile)),
    );
    if (updated != null && mounted) setState(() => profile = updated);
  }

  // ── actions ───────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (profile.email.trim().isEmpty) {
      AppSnackBar.showError(context, 'Add your email in Profile first.');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Reset your password?',
      message: 'We\'ll email a password reset link to ${profile.email}.',
      confirmLabel: 'Send link',
      icon: Icons.lock_reset_rounded,
    );
    if (!ok || !mounted) return;
    try {
      await AuthService().forgotPassword(email: profile.email.trim());
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Reset link sent — check your inbox ✓');
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not connect. Try again.');
      }
    }
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        'I use SchoolLife to track my timetable, classes and grades. '
        'Try it: https://gradexapp.web.app',
      );
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'Could not open share.');
    }
  }

  Future<void> _signOut() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'Your data stays saved on this device.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
      color: Colors.orange,
    );
    if (!ok) return;

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

  Future<void> _deleteAccount() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'This permanently deletes your account and all your data. This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever_rounded,
      color: Colors.red,
    );
    if (!ok) return;

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

  // ══════════════════════════════════════════════════════════
  //  SHARED BUILDING BLOCKS
  // ══════════════════════════════════════════════════════════
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

  Widget _iconTile(IconData icon, Color color) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 19),
  );

  Widget _row({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final sub = isDark ? Colors.white54 : Colors.black45;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _iconTile(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor ??
                          (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: sub, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => _row(
    isDark: isDark,
    icon: icon,
    color: color,
    title: title,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
  );

  Widget _group(String label, List<Widget> rows, bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
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
      Container(
        decoration: _deco(isDark),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 66,
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.06),
                ),
            ],
          ],
        ),
      ),
    ],
  );

  // ── the rows of each group (shared by phone + desktop) ────
  List<Widget> _appearanceRows(ThemeNotifier theme, bool isDark) => [
    _row(
      isDark: isDark,
      icon: switch (theme.themeMode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      },
      color: _blue,
      title: 'App theme',
      subtitle: theme.label,
      onTap: () => _pickTheme(theme),
    ),
  ];

  /// Pop-up with Light / Dark / System as radio options.
  Future<void> _pickTheme(ThemeNotifier theme) async {
    var selected = theme.themeMode;
    const options = [
      (ThemeMode.light, 'Light theme', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark theme', Icons.dark_mode_rounded),
      (ThemeMode.system, 'System theme', Icons.brightness_auto_rounded),
    ];

    final result = await showAppDialog<ThemeMode>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          return AppDialog(
            title: 'App theme',
            message: 'Choose how SchoolLife looks.',
            icon: Icons.palette_rounded,
            child: Column(
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setD(() => selected = o.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected == o.$1
                              ? _blue.withOpacity(dark ? 0.2 : 0.08)
                              : (dark
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFFF5F7FA)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected == o.$1
                                ? _blue.withOpacity(0.6)
                                : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              o.$3,
                              size: 21,
                              color: selected == o.$1
                                  ? _blue
                                  : (dark ? Colors.white54 : Colors.black45),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                o.$2,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            // radio button
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected == o.$1
                                      ? _blue
                                      : (dark
                                            ? Colors.white30
                                            : Colors.black26),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: selected == o.$1 ? 10 : 0,
                                  height: selected == o.$1 ? 10 : 0,
                                  decoration: const BoxDecoration(
                                    color: _blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              const DialogCancelButton(),
              DialogConfirmButton(
                label: 'Apply',
                onPressed: () => Navigator.pop(ctx, selected),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) await theme.setThemeMode(result);
  }

  List<Widget> _notificationRows() => const [
    NotificationToggle(),
    PersonalRemindersToggle(),
  ];

  List<Widget> _privacyRows(bool isDark) => [
    _switchRow(
      isDark: isDark,
      icon: Icons.visibility_off_rounded,
      color: _purple,
      title: 'Hide CGPA',
      subtitle: 'Keep your CGPA hidden on the Grades screen',
      value: _hideCgpa,
      onChanged: _setHideCgpa,
    ),
    _row(
      isDark: isDark,
      icon: Icons.lock_reset_rounded,
      color: _teal,
      title: 'Change password',
      subtitle: 'Get a reset link by email',
      onTap: _changePassword,
    ),
  ];

  List<Widget> _aboutRows(bool isDark) => [
    _row(
      isDark: isDark,
      icon: Icons.share_rounded,
      color: _blue,
      title: 'Share SchoolLife',
      subtitle: 'Invite your classmates',
      onTap: _shareApp,
    ),
    _row(
      isDark: isDark,
      icon: Icons.verified_outlined,
      color: Colors.green,
      title: 'App version',
      subtitle: 'SchoolLife v1.0.1',
    ),
    if (!kIsWeb) const UpdateCheckTile(),
  ];

  Widget _deleteRow(bool isDark) => _row(
    isDark: isDark,
    icon: Icons.delete_forever_rounded,
    color: Colors.red,
    title: 'Delete account',
    subtitle: 'Permanently remove your account and data',
    titleColor: Colors.red,
    onTap: _deleteAccount,
  );

  Widget _logoutButton(bool isDark) => PressScale(
    onTap: _signOut,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Text(
            'Log out',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _avatar(double size, double font) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
      ),
    ),
    child: Center(
      child: Text(
        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: font,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isDark = theme.isDarkMode;

    if (context.isExpanded) return _buildDesktop(theme, isDark);
    return _buildMobile(theme, isDark);
  }

  // ── Phone / tablet ───────────────────────────────────────
  Widget _buildMobile(ThemeNotifier theme, bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    // compact profile row: just the name + a Profile button
    final profileRow = PressScale(
      onTap: _openProfile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _deco(isDark),
        child: Row(
          children: [
            _avatar(48, 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                profile.name.isNotEmpty ? profile.name : 'Your name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _blue.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, color: _blue, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final side = responsiveSidePadding(c.maxWidth, maxWidth: 640);
            return RefreshIndicator(
              color: _blue,
              onRefresh: () async {
                await _loadProfile();
                await _loadPrefs();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(side, 14, side, 120),
                children: staggered([
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1, bottom: 16),
                    child: Text(
                      'Manage your account and app',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ),
                  profileRow,
                  const SizedBox(height: 24),
                  _group('Appearance', _appearanceRows(theme, isDark), isDark),
                  const SizedBox(height: 22),
                  _group('Notifications', _notificationRows(), isDark),
                  const SizedBox(height: 22),
                  _group('Privacy & security', _privacyRows(isDark), isDark),
                  const SizedBox(height: 22),
                  _group('About', _aboutRows(isDark), isDark),
                  const SizedBox(height: 22),
                  _group('Account', [_deleteRow(isDark)], isDark),
                  const SizedBox(height: 26),
                  _logoutButton(isDark),
                ], stepMs: 55),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DESKTOP (>= 900 px): categories on the left, panel on the right
  // ══════════════════════════════════════════════════════════
  static const _sections = [
    (Icons.person_outline_rounded, 'Profile', 'Your personal and academic details'),
    (Icons.palette_outlined, 'Appearance', 'Choose how SchoolLife looks'),
    (Icons.notifications_outlined, 'Notifications', 'Class and study reminders'),
    (Icons.shield_outlined, 'Privacy & security', 'Control what is shown and secure your account'),
    (Icons.info_outline_rounded, 'About', 'Version, updates and sharing'),
    (Icons.manage_accounts_outlined, 'Account', 'Delete your account or log out'),
  ];

  Widget _buildDesktop(ThemeNotifier theme, bool isDark) {
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final cw = c.maxWidth;
            final side = responsiveSidePadding(cw, maxWidth: 1200);
            final stacked = cw < 820;

            final pane = RefreshIndicator(
              color: _blue,
              onRefresh: () async {
                await _loadProfile();
                await _loadPrefs();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _desktopPane(theme, isDark, cardBg, text, sub),
                    ),
                  ),
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(side, 26, side, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your account and app',
                    style: TextStyle(fontSize: 14, color: sub),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var i = 0; i < _sections.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _navPill(i, isDark, text),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(child: pane),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 260,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: _deco(isDark),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < _sections.length; i++)
                                        _navRow(i, isDark, text, sub),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(child: pane),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _navRow(int i, bool isDark, Color text, Color sub) {
    final selected = _section == i;
    final item = _sections[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _section = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Icon(item.$1, size: 20, color: selected ? Colors.white : sub),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navPill(int i, bool isDark, Color text) {
    final selected = _section == i;
    final item = _sections[i];
    return GestureDetector(
      onTap: () => setState(() => _section = i),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  )
                : null,
            color: selected
                ? null
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 18, color: selected ? Colors.white : text),
              const SizedBox(width: 8),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopPane(
    ThemeNotifier theme,
    bool isDark,
    Color cardBg,
    Color text,
    Color sub,
  ) {
    final item = _sections[_section];

    final Widget body;
    switch (_section) {
      case 0:
        body = _profilePane(isDark, cardBg, text, sub);
        break;
      case 1:
        body = _appearancePane(theme, isDark, cardBg, text, sub);
        break;
      case 2:
        body = _group('Reminders', _notificationRows(), isDark);
        break;
      case 3:
        body = _group('Privacy & security', _privacyRows(isDark), isDark);
        break;
      case 4:
        body = _group('About', _aboutRows(isDark), isDark);
        break;
      default:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _group('Danger zone', [_deleteRow(isDark)], isDark),
            const SizedBox(height: 26),
            SizedBox(width: 260, child: _logoutButton(isDark)),
          ],
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            const SizedBox(height: 2),
            Text(item.$3, style: TextStyle(fontSize: 13, color: sub)),
            const SizedBox(height: 20),
            body,
          ],
        ),
      ),
    );
  }

  Widget _profilePane(bool isDark, Color cardBg, Color text, Color sub) {
    Widget info(IconData icon, String label, String value) => Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(icon, _blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: sub)),
                const SizedBox(height: 3),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: _deco(isDark),
          child: Wrap(
            spacing: 22,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatar(72, 30),
                  const SizedBox(width: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isNotEmpty ? profile.name : 'Your name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile.email,
                          style: TextStyle(fontSize: 13, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _openProfile,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit profile',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ResponsiveGrid(
          minItemWidth: 240,
          spacing: 14,
          runSpacing: 14,
          children: [
            info(Icons.account_balance, 'School', profile.school),
            info(Icons.badge_outlined, 'Matric number', profile.matricNumber),
            info(Icons.account_balance_outlined, 'Faculty', profile.faculty),
            info(Icons.school_outlined, 'Department', profile.department),
            info(
              Icons.stairs_outlined,
              'Level',
              profile.level.isNotEmpty ? '${profile.level} Level' : '',
            ),
          ],
        ),
      ],
    );
  }

  Widget _appearancePane(
    ThemeNotifier theme,
    bool isDark,
    Color cardBg,
    Color text,
    Color sub,
  ) {
    Widget mini(bool dark) {
      final pBg = dark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
      final pCard = dark ? const Color(0xFF15181D) : Colors.white;
      final pSide = dark ? const Color(0xFF0D1B2A) : const Color(0xFFE9EDF4);
      return Container(
        color: pSide,
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 8,
                      width: 44,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: pCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget themeCard(String label, ThemeMode mode, IconData icon) {
      final selected = theme.themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => theme.setThemeMode(mode),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: _deco(isDark).copyWith(
                border: Border.all(
                  color: selected ? _blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 110,
                      child: mode == ThemeMode.system
                          ? Row(
                              children: [
                                Expanded(child: ClipRect(child: mini(false))),
                                Expanded(child: ClipRect(child: mini(true))),
                              ],
                            )
                          : mini(mode == ThemeMode.dark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(icon, size: 17, color: selected ? _blue : sub),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 19,
                        color: selected ? _blue : sub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        themeCard('Light theme', ThemeMode.light, Icons.light_mode_rounded),
        const SizedBox(width: 14),
        themeCard('Dark theme', ThemeMode.dark, Icons.dark_mode_rounded),
        const SizedBox(width: 14),
        themeCard('System theme', ThemeMode.system, Icons.brightness_auto_rounded),
      ],
    );
  }
}