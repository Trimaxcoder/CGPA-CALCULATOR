// lib/screens/class_settings_screen.dart
//
// Settings of a class. Only admins can open it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../widgets/snackBar.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

class _Pal {
  final bool isDark;
  const _Pal(this.isDark);

  Color get bg => isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
  Color get card => isDark ? const Color(0xFF15181D) : Colors.white;
  Color get text => isDark ? Colors.white : Colors.black87;
  Color get sub => isDark ? Colors.white54 : Colors.black45;
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.07);
  Color get field => isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.05);
}

class ClassSettingsScreen extends StatefulWidget {
  const ClassSettingsScreen({super.key, required this.room});

  final ClassRoom room;

  @override
  State<ClassSettingsScreen> createState() => _ClassSettingsScreenState();
}

class _ClassSettingsScreenState extends State<ClassSettingsScreen> {
  final _service = ClassService();

  late ClassRoom _room;
  late final TextEditingController _name;
  late final TextEditingController _description;

  bool _saving = false;
  bool _regenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _name = TextEditingController(text: _room.name)..addListener(_refresh);
    _description = TextEditingController(text: _room.description)
      ..addListener(_refresh);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _dirty =>
      _name.text.trim() != _room.name ||
      _description.text.trim() != _room.description;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'The class name must be at least 2 letters.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _service.update(
        _room.id,
        name: name,
        description: _description.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _room = updated;
        _saving = false;
      });
      AppSnackBar.auto(context, 'Class details saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  /// Changes a switch right away, and puts it back if the server refuses.
  Future<void> _toggle({bool? requireApproval, bool? chatLocked}) async {
    final before = _room;
    setState(() {
      _room = _room.copyWith(
        requireApproval: requireApproval,
        chatLocked: chatLocked,
      );
    });

    try {
      final updated = await _service.update(
        _room.id,
        requireApproval: requireApproval,
        chatLocked: chatLocked,
      );
      if (mounted) setState(() => _room = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _room = before);
      AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _room = before);
      AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a new code?'),
        content: const Text(
          'The old code and link stop working right away. '
          'People already in the class stay in it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Make new code'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _regenerating = true);
    try {
      final result = await _service.regenerateCode(_room.id);
      if (!mounted) return;
      setState(() {
        _room = _room.copyWith(
          joinCode: result.joinCode,
          inviteLink: result.inviteLink,
        );
        _regenerating = false;
      });
      AppSnackBar.auto(context, 'New code ready');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  void _copy() {
    final code = _room.joinCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    AppSnackBar.auto(context, 'Code copied');
  }

  void _share() {
    final code = _room.joinCode ?? '';
    final link = _room.inviteLink ?? '';
    final text = StringBuffer('Join "${_room.name}" on SchoolLife.\n')
      ..write('Class code: $code');
    // Only real web links are tappable in chat apps
    if (link.startsWith('http')) text.write('\n$link');
    Share.share(text.toString());
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context.watch<ThemeNotifier>().isDarkMode);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _header(p),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      32 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      _sectionTitle(p, 'CLASS DETAILS'),
                      _detailsCard(p),
                      _sectionTitle(p, 'JOINING'),
                      _switchCard(
                        p,
                        icon: Icons.how_to_reg_rounded,
                        title: 'Approve students before they join',
                        subtitle:
                            'Anyone with the code waits for an admin to approve them.',
                        value: _room.requireApproval,
                        onChanged: (v) => _toggle(requireApproval: v),
                      ),
                      _sectionTitle(p, 'CHAT'),
                      _switchCard(
                        p,
                        icon: Icons.lock_outline_rounded,
                        title: 'Lock the chat',
                        subtitle:
                            'Only admins can send messages. Good for announcements.',
                        value: _room.chatLocked,
                        onChanged: (v) => _toggle(chatLocked: v),
                      ),
                      _sectionTitle(p, 'CLASS CODE'),
                      _codeCard(p),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(_Pal p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: p.text),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
                Text(
                  _room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(_Pal p, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: p.sub,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(_Pal p) => BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      );

  InputDecoration _fieldDecoration(_Pal p, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.sub),
        counterText: '',
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _detailsCard(_Pal p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: p.text),
            decoration: _fieldDecoration(p, 'Class name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: p.text),
            decoration: _fieldDecoration(p, 'Description (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (_dirty && !_saving) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _blue.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save changes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard(
    _Pal p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: _cardDecoration(p),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: _accent),
        activeThumbColor: _accent,
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: p.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: p.sub, height: 1.3),
        ),
      ),
    );
  }

  Widget _codeCard(_Pal p) {
    final code = _room.joinCode ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(p),
      child: Column(
        children: [
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: _accent,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: code.isEmpty ? null : _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.text,
                    side: BorderSide(color: p.border),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: code.isEmpty ? null : _share,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.text,
                    side: BorderSide(color: p.border),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _regenerating ? null : _regenerate,
            child: _regenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text(
                    'Make a new code',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          Text(
            'Use this if the code was shared with the wrong people.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.sub),
          ),
        ],
      ),
    );
  }
}