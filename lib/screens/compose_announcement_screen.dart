// lib/screens/compose_announcement_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/announcement_service.dart';
import '../stores/announcement_store.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

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
                    // NEW — quick access to edit/delete sent announcements
                    IconButton(
                      icon: const Icon(Icons.list_alt_rounded,
                          color: Colors.white),
                      tooltip: 'Manage my announcements',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageAnnouncementsScreen(),
                        ),
                      ),
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
                padding: const EdgeInsets.all(20),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _levels.map((l) {
                      final selected = _level == l.value;
                      return GestureDetector(
                        onTap: () => setState(() => _level = l.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _primary
                                : _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: selected
                                ? null
                                : Border.all(
                                    color: _primary.withOpacity(0.3)),
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
                      );
                    }).toList(),
                  ),

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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageAnnouncementsScreen(),
                      ),
                    ),
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