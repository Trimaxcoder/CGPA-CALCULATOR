// lib/screens/classes_hub_screen.dart
//
// "Join a class" landing page: the classes I'm in, plus Create and Join.
//
// Two modes:
//  • normal   (phones): a full page. Tapping a class slides its chat in.
//  • embedded (desktop / wide): the left sidebar of the split view. Tapping a
//    class calls onSelect so the chat opens in the right-hand pane.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';
import '../widgets/animations.dart';
import '../widgets/snackBar.dart';
import '../widgets/class_layout.dart';
import 'class_screen.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

class _Palette {
  final bool isDark;
  const _Palette(this.isDark);

  Color get bg => isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
  Color get card => isDark ? const Color(0xFF15181D) : Colors.white;
  Color get text => isDark ? Colors.white : Colors.black87;
  Color get sub => isDark ? Colors.white54 : Colors.black45;
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.07);
  Color get field => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ClassesHubScreen extends StatefulWidget {
  const ClassesHubScreen({
    super.key,
    this.embedded = false,
    this.selectedId,
    this.onSelect,
    this.onLoaded,
  });

  /// true when shown as the sidebar of the desktop split view
  final bool embedded;

  /// the class currently open in the chat pane (highlighted in the list)
  final String? selectedId;

  /// desktop: called when a class is tapped
  final ValueChanged<ClassRoom>? onSelect;

  /// called every time the list reloads
  final ValueChanged<List<ClassRoom>>? onLoaded;

  @override
  State<ClassesHubScreen> createState() => _ClassesHubScreenState();
}

class _ClassesHubScreenState extends State<ClassesHubScreen> {
  final _service = ClassService();
  final _socket = ClassSocket();

  List<ClassRoom> _classes = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<ClassEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    // Approved, removed, class archived, member counts... refresh quietly
    _sub = _socket.onClassEvent.listen((_) => _load(silent: true));
    classListRefresh.addListener(_onRefreshSignal);
    _load();
  }

  @override
  void dispose() {
    classListRefresh.removeListener(_onRefreshSignal);
    _sub?.cancel();
    super.dispose();
  }

  void _onRefreshSignal() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.myClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
        _loading = false;
        _error = null;
      });
      widget.onLoaded?.call(list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Something went wrong. Please try again.';
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showJoin() async {
    final p = _Palette(context.read<ThemeNotifier>().isDarkMode);
    final room = await showModalBottomSheet<ClassRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      builder: (_) => _JoinSheet(service: _service, palette: p),
    );
    if (room == null || !mounted) return;

    await _load(silent: true);
    if (!mounted) return;
    if (room.isPending) {
      AppSnackBar.auto(context, 'Request sent. An admin needs to approve you.');
    } else {
      AppSnackBar.auto(context, 'You joined ${room.name}');
      widget.onSelect?.call(room); // desktop: open it straight away
    }
  }

  Future<void> _showCreate() async {
    final p = _Palette(context.read<ThemeNotifier>().isDarkMode);
    final room = await showModalBottomSheet<ClassRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      builder: (_) => _CreateSheet(service: _service, palette: p),
    );
    if (room == null || !mounted) return;

    await _load(silent: true);
    if (!mounted) return;
    await _showCreated(room);
    if (mounted) widget.onSelect?.call(room); // desktop: open it straight away
  }

  Future<void> _showCreated(ClassRoom room) async {
    final code = room.joinCode ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Class created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 14),
            const Text('Share this code with your classmates:'),
            const SizedBox(height: 10),
            Center(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: _accent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              AppSnackBar.auto(context, 'Code copied');
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => _share(room),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _share(ClassRoom room) {
    final code = room.joinCode ?? '';
    final link = room.inviteLink ?? '';
    final text = StringBuffer('Join "${room.name}" on SchoolLife.\n')
      ..write('Class code: $code');
    // Only real web links are tappable in chat apps
    if (link.startsWith('http')) text.write('\n$link');
    Share.share(text.toString());
  }

  void _open(ClassRoom c) {
    if (c.isPending) {
      AppSnackBar.auto(context, 'Waiting for an admin to approve you.');
      return;
    }

    // Desktop: show the chat in the right-hand pane
    final onSelect = widget.onSelect;
    if (onSelect != null) {
      onSelect(c);
      return;
    }

    // Phone: the chat slides in; refresh the list when coming back
    Navigator.of(context)
        .push(classSlideRoute<void>(ClassScreen(room: c)))
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = _Palette(context.watch<ThemeNotifier>().isDarkMode);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(p),
        _actions(p),
        Expanded(child: _content(p)),
      ],
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: widget.embedded
            ? body
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: body,
                ),
              ),
      ),
    );
  }

  Widget _header(_Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_rounded, color: p.text),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
                Text(
                  'Join or create a class space',
                  style: TextStyle(fontSize: 13, color: p.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(_Palette p) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 14 : 20,
        12,
        widget.embedded ? 14 : 20,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              p,
              icon: Icons.group_add_rounded,
              label: 'Join with code',
              filled: true,
              onTap: _showJoin,
            ),
          ),
          SizedBox(width: widget.embedded ? 10 : 12),
          Expanded(
            child: _actionButton(
              p,
              icon: Icons.add_rounded,
              label: 'Create class',
              filled: false,
              onTap: _showCreate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    _Palette p, {
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final fg = filled ? Colors.white : p.text;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: filled ? _blue : p.card,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: p.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(_Palette p) {
    if (_loading && _classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? 12 : 20,
          8,
          widget.embedded ? 12 : 20,
          32,
        ),
        children: [
          if (_error != null && _classes.isEmpty)
            _errorView(p)
          else if (_classes.isEmpty)
            _emptyView(p)
          else
            for (final c in _classes) _classCard(c, p),
        ],
      ),
    );
  }

  Widget _emptyView(_Palette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 60, color: p.sub),
          const SizedBox(height: 14),
          Text(
            'No classes yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join one with a code from your class rep,\nor create your own.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: p.sub, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _errorView(_Palette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: p.sub),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.text),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _classCard(ClassRoom c, _Palette p) {
    final role = c.isOwner ? 'Owner' : (c.isAdmin ? 'Admin' : 'Member');
    final members = '${c.memberCount} ${c.memberCount == 1 ? 'member' : 'members'}';
    final subtitle = c.isPending ? 'Waiting for approval' : '$members · $role';
    final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C';
    final selected = widget.embedded && c.id == widget.selectedId;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.embedded ? 10 : 12),
      child: PressScale(
        onTap: () => _open(c),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.14) : p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _accent.withValues(alpha: 0.55) : p.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.sub),
                    ),
                  ],
                ),
              ),
              if (c.isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange,
                    ),
                  ),
                )
              else if (!widget.embedded)
                Icon(Icons.chevron_right_rounded, color: p.sub),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED SHEET PIECES
// ══════════════════════════════════════════════════════════════════════════════

InputDecoration _fieldDecoration(_Palette p, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.sub),
    filled: true,
    fillColor: p.field,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

Widget _sheetHandle(_Palette p) {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: p.isDark ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _sheetButton({
  required String label,
  required bool busy,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: busy ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _blue.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
    ),
  );
}

/// Turns what the student types into capital letters.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  JOIN SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.service, required this.palette});

  final ClassService service;
  final _Palette palette;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Finds a class code in text the student copied: the bare code, a shared
  /// message ("Class code: ABC123"), or an invite link ending in /join/ABC123.
  String? _extractCode(String raw) {
    final text = raw.trim();

    if (RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(text)) {
      return text.toUpperCase();
    }

    final shared = RegExp(
      r'Class code:\s*([A-Za-z0-9]{6})',
      caseSensitive: false,
    ).firstMatch(text);
    if (shared != null) return shared.group(1)!.toUpperCase();

    final link = RegExp(
      r'/join/([A-Za-z0-9]{6})(?:[/?#].*)?$',
    ).firstMatch(text);
    if (link != null) return link.group(1)!.toUpperCase();

    return null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = _extractCode(data?.text ?? '');
    if (!mounted) return;

    if (code == null) {
      setState(() => _error = 'No class code found in your clipboard.');
      return;
    }
    setState(() {
      _code.text = code;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character code.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final room = await widget.service.join(code);
      if (!mounted) return;
      Navigator.pop(context, room);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(p),
          const SizedBox(height: 18),
          Text(
            'Join a class',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Type the 6-character code from your class rep',
            style: TextStyle(fontSize: 13, color: p.sub),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            autofocus: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: p.text,
            ),
            decoration: _fieldDecoration(p, 'ABC123'),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : _paste,
              icon: const Icon(Icons.content_paste_rounded, size: 16),
              label: const Text('Paste from clipboard'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          _sheetButton(label: 'Join class', busy: _busy, onTap: _submit),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CREATE SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({required this.service, required this.palette});

  final ClassService service;
  final _Palette palette;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _requireApproval = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Give the class a name (at least 2 letters).');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final room = await widget.service.create(
        name: name,
        description: _description.text.trim(),
        requireApproval: _requireApproval,
      );
      if (!mounted) return;
      Navigator.pop(context, room);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(p),
          const SizedBox(height: 18),
          Text(
            'Create a class',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'You will be the admin of this class',
            style: TextStyle(fontSize: 13, color: p.sub),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: p.text),
            decoration: _fieldDecoration(p, 'Class name, e.g. CSC 300L'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: p.text),
            decoration: _fieldDecoration(p, 'What is this class for? (optional)'),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _accent,
            value: _requireApproval,
            onChanged: (v) => setState(() => _requireApproval = v),
            title: Text(
              'Approve students before they join',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            subtitle: Text(
              'Anyone with the code must wait for your approval',
              style: TextStyle(fontSize: 12, color: p.sub),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          _sheetButton(label: 'Create class', busy: _busy, onTap: _submit),
        ],
      ),
    );
  }
}