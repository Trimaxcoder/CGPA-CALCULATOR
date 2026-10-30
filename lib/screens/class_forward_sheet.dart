// lib/screens/class_forward_sheet.dart
//
// The "Forward to..." picker. Shows the classes the student can post in, with
// a search box and tick boxes (up to 5 at a time). Returns the chosen classes,
// or null if the student closes it.
//
//   final picked = await showForwardPicker(
//     context,
//     currentClassId: room.id,
//     preview: message.previewText,
//   );

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

const _maxTargets = 5;

class _Pal {
  final bool isDark;
  const _Pal(this.isDark);

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

Future<List<ClassRoom>?> showForwardPicker(
  BuildContext context, {
  required String currentClassId,
  required String preview,
}) {
  return showModalBottomSheet<List<ClassRoom>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ForwardPicker(
      currentClassId: currentClassId,
      preview: preview,
    ),
  );
}

class _ForwardPicker extends StatefulWidget {
  const _ForwardPicker({required this.currentClassId, required this.preview});

  final String currentClassId;
  final String preview;

  @override
  State<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends State<_ForwardPicker> {
  final _service = ClassService();
  final _search = TextEditingController();

  List<ClassRoom> _all = [];
  final Set<String> _picked = {};
  bool _loading = true;
  String? _error;
  String _note = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.myClasses();
      if (!mounted) return;
      setState(() {
        // Only classes where I can actually post
        _all = list
            .where((c) =>
                c.isActive &&
                !c.archived &&
                c.id != widget.currentClassId &&
                (!c.chatLocked || c.isAdmin))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your classes.';
        _loading = false;
      });
    }
  }

  List<ClassRoom> get _shown {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  void _toggle(ClassRoom c) {
    setState(() {
      _note = '';
      if (_picked.contains(c.id)) {
        _picked.remove(c.id);
      } else if (_picked.length >= _maxTargets) {
        _note = 'You can forward to up to $_maxTargets classes at a time.';
      } else {
        _picked.add(c.id);
      }
    });
  }

  void _send() {
    final chosen = _all.where((c) => _picked.contains(c.id)).toList();
    Navigator.pop(context, chosen);
  }

  Widget _row(_Pal p, ClassRoom c) {
    final on = _picked.contains(c.id);
    final initial = c.name.isEmpty ? '?' : c.name[0].toUpperCase();

    return InkWell(
      onTap: () => _toggle(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                ),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  Text(
                    '${c.memberCount} ${c.memberCount == 1 ? 'member' : 'members'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              on ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: on ? _accent : p.sub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(_Pal p) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text),
              ),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (_all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'You are not in any other class where you can post.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.sub, height: 1.4),
          ),
        ),
      );
    }

    final shown = _shown;
    if (shown.isEmpty) {
      return Center(
        child: Text(
          'No class matches "${_search.text.trim()}".',
          style: TextStyle(fontSize: 14, color: p.sub),
        ),
      );
    }

    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (_, i) => _row(p, shown[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context.watch<ThemeNotifier>().isDarkMode);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.82,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Forward to...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: p.text,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: p.sub),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // What is being forwarded
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: _accent, width: 3),
                  ),
                ),
                child: Text(
                  widget.preview.isEmpty ? 'Message' : widget.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: p.sub),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: p.text, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search your classes',
                    hintStyle: TextStyle(color: p.sub),
                    prefixIcon: Icon(Icons.search_rounded, color: p.sub),
                    filled: true,
                    fillColor: p.field,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(child: _list(p)),
              if (_note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    _note,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _picked.isEmpty ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _picked.isEmpty
                          ? 'Choose a class'
                          : 'Send to ${_picked.length} ${_picked.length == 1 ? 'class' : 'classes'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _blue.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}