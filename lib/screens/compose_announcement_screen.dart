// lib/screens/compose_announcement_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/announcement_service.dart';
import '../stores/announcement_store.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_page.dart';
import 'manage_announcements_screen.dart';

class ComposeAnnouncementScreen extends StatefulWidget {
  const ComposeAnnouncementScreen({super.key});

  @override
  State<ComposeAnnouncementScreen> createState() =>
      _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState
    extends State<ComposeAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _level = 'all';
  bool   _sending = false;

  static const Color _primary = Color(0xFF1565C0);

  static const List<({String value, String label})> _levels = [
    (value: 'all', label: 'Everyone'),
    (value: '100', label: '100 Level'),
    (value: '200', label: '200 Level'),
    (value: '300', label: '300 Level'),
    (value: '400', label: '400 Level'),
    (value: '500', label: '500 Level'),
  ];

  @override
  void initState() {
    super.initState();
    // keeps the desktop live preview in sync while typing
    _titleCtrl.addListener(_refresh);
    _messageCtrl.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final result = await AnnouncementService.postAnnouncement(
        title:   _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        level:   _level,
      );

      await AnnouncementStore().refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Sent! ${result.notifiedCount} student${result.notifiedCount == 1 ? '' : 's'} notified.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openManage() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageAnnouncementsScreen()),
      );

  // ── "Send to" level chips (shared) ─────────────────────────────────────
  Widget _levelChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _levels.map((l) {
          final selected = _level == l.value;
          return GestureDetector(
            onTap: () => setState(() => _level = l.value),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _primary : _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: selected
                      ? null
                      : Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: Text(
                  l.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _primary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    if (context.isExpanded) return _buildDesktop(isDark);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
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
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
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
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'New Announcement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    // quick access to edit/delete sent announcements
                    IconButton(
                      icon: const Icon(Icons.list_alt_rounded,
                          color: Colors.white),
                      tooltip: 'Manage my announcements',
                      onPressed: _openManage,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: responsiveSidePadding(
                    MediaQuery.sizeOf(context).width,
                    maxWidth: 640,
                  ),
                  vertical: 20,
                ),
                children: [
                  Text(
                    'Send to',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _levelChips(),

                  const SizedBox(height: 24),

                  _Field(
                    controller: _titleCtrl,
                    label: 'Title',
                    hint: 'e.g. Exam timetable update',
                    icon: Icons.title_rounded,
                    isDark: isDark,
                    maxLines: 1,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  _Field(
                    controller: _messageCtrl,
                    label: 'Message',
                    hint: 'Write your announcement here…',
                    icon: Icons.message_rounded,
                    isDark: isDark,
                    maxLines: 8,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message is required'
                        : null,
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'Sending…' : 'Send Announcement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary entry point too, in case the icon is missed
                  TextButton.icon(
                    onPressed: _openManage,
                    icon: const Icon(Icons.list_alt_rounded,
                        size: 18, color: _primary),
                    label: const Text(
                      'View / edit / delete my announcements',
                      style: TextStyle(color: _primary),
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

  // ══════════════════════════════════════════════════════════
  //  DESKTOP: form on the left, live preview on the right
  // ══════════════════════════════════════════════════════════
  Widget _buildDesktop(bool isDark) {
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    final shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            t.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: textSecondary,
            ),
          ),
        );

    final form = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Send to'),
            _levelChips(),
            const SizedBox(height: 26),
            _Field(
              controller: _titleCtrl,
              label: 'Title',
              hint: 'e.g. Exam timetable update',
              icon: Icons.title_rounded,
              isDark: isDark,
              maxLines: 1,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _messageCtrl,
              label: 'Message',
              hint: 'Write your announcement here…',
              icon: Icons.message_rounded,
              isDark: isDark,
              maxLines: 10,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Message is required'
                  : null,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Sending…' : 'Send Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ── Live preview ──
    final levelLabel =
        _levels.firstWhere((l) => l.value == _level).label;
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Preview'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: _primary, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'How students will see it',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      levelLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title.isEmpty ? 'Your title appears here' : title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: title.isEmpty
                      ? textSecondary.withOpacity(0.6)
                      : textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message.isEmpty
                    ? 'Your message appears here as you type…'
                    : message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: message.isEmpty
                      ? textSecondary.withOpacity(0.6)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return DesktopPage(
      title: 'New Announcement',
      subtitle: 'Send an update to your students',
      maxWidth: 1200,
      actions: [
        DeskButton(
          icon: Icons.list_alt_rounded,
          label: 'My announcements',
          isDark: isDark,
          onTap: _openManage,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, c) {
          final twoCol = c.maxWidth >= 860;
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: form),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: preview),
                  ],
                )
              else ...[
                form,
                const SizedBox(height: 24),
                preview,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final String? Function(String?) validator;

  static const Color _primary = Color(0xFF1565C0);

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.maxLines,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _primary, size: 20),
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
        validator: validator,
      );
}