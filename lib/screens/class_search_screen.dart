// lib/screens/class_search_screen.dart
//
// Search the messages of one class. Type at least 2 letters: the results list
// shows each matching message with the match highlighted. Tapping a result
// opens it in context, with the messages just before and after it.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';

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

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _thumb(String url) {
  const marker = '/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  return url.replaceFirst(marker, '${marker}c_fill,w_360,h_270,q_auto/');
}

/// The text a search result shows: the message text if it holds the search
/// words, otherwise the attachment name that does.
String _haystack(ChatMessage m, String query) {
  final q = query.toLowerCase();
  if (m.text.toLowerCase().contains(q)) return m.text;
  final a = m.attachment;
  if (a != null && a.name.toLowerCase().contains(q)) return a.name;
  return m.previewText;
}

/// A short piece of [text] around the first match, with "…" where cut.
String _snippet(String text, String query) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= 140) return flat;

  final i = flat.toLowerCase().indexOf(query.toLowerCase());
  final start = i <= 40 ? 0 : i - 40;
  final end = (start + 140).clamp(0, flat.length);
  return '${start > 0 ? '…' : ''}${flat.substring(start, end)}'
      '${end < flat.length ? '…' : ''}';
}

/// [text] split into pieces, with every match of [query] in [hi] style.
List<TextSpan> _highlight(
  String text,
  String query,
  TextStyle base,
  TextStyle hi,
) {
  final lower = text.toLowerCase();
  final q = query.toLowerCase();
  if (q.isEmpty || lower.length != text.length) {
    return [TextSpan(text: text, style: base)];
  }

  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final i = lower.indexOf(q, start);
    if (i == -1) {
      spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (i > start) spans.add(TextSpan(text: text.substring(start, i), style: base));
    spans.add(TextSpan(text: text.substring(i, i + q.length), style: hi));
    start = i + q.length;
  }
  return spans;
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEARCH SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ClassSearchScreen extends StatefulWidget {
  const ClassSearchScreen({super.key, required this.room});

  final ClassRoom room;

  @override
  State<ClassSearchScreen> createState() => _ClassSearchScreenState();
}

class _ClassSearchScreenState extends State<ClassSearchScreen> {
  final _service = ClassService();
  final _input = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  int _seq = 0; // lets a slow, older search be ignored

  String _query = ''; // what the shown results are for
  List<ChatMessage> _results = [];
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();

    if (q.length < 2) {
      _seq++;
      setState(() {
        _query = '';
        _results = [];
        _hasMore = false;
        _loading = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _service.searchMessages(widget.room.id, q);
      if (!mounted || mine != _seq) return;
      setState(() {
        _query = q;
        _results = page.messages;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || mine != _seq) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || mine != _seq) return;
      setState(() {
        _loading = false;
        _error = 'Could not search. Check your connection.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _results.isEmpty) return;
    final mine = _seq;
    setState(() => _loadingMore = true);

    try {
      final page = await _service.searchMessages(
        widget.room.id,
        _query,
        before: _results.last.id,
      );
      if (!mounted || mine != _seq) return;
      setState(() {
        _results = [..._results, ...page.messages];
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _openContext(ChatMessage m) async {
    final backToChat = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ContextScreen(
          room: widget.room,
          message: m,
          query: _query,
        ),
      ),
    );
    if (backToChat == true && mounted) Navigator.pop(context);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  Widget _searchBar(_Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: p.text),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _input,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                maxLength: 60,
                style: TextStyle(color: p.text, fontSize: 15),
                onChanged: (v) {
                  setState(() {}); // shows or hides the clear button
                  _onChanged(v);
                },
                onSubmitted: (v) {
                  _debounce?.cancel();
                  final q = v.trim();
                  if (q.length >= 2) _search(q);
                },
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.room.name}',
                  hintStyle: TextStyle(color: p.sub),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  suffixIcon: _input.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: p.sub),
                          onPressed: () {
                            _input.clear();
                            _onChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(_Pal p, IconData icon, String title, String body) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: p.sub),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: p.sub, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(_Pal p, ChatMessage m) {
    final mine = m.senderId == ClassSocket().myUserId;
    final base = TextStyle(fontSize: 14.5, color: p.text, height: 1.3);
    final hi = base.copyWith(
      fontWeight: FontWeight.w900,
      color: _accent,
      backgroundColor: _accent.withValues(alpha: 0.14),
    );
    final snippet = _snippet(_haystack(m, _query), _query);
    final a = m.attachment;

    return InkWell(
      onTap: () => _openContext(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mine ? 'You' : m.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fmtDate(m.createdAt)}, ${_fmtTime(m.createdAt)}',
                  style: TextStyle(fontSize: 11.5, color: p.sub),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a != null && !a.isImage) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 1),
                    child: Icon(
                      a.isAudio
                          ? Icons.mic_none_rounded
                          : Icons.insert_drive_file_outlined,
                      size: 17,
                      color: p.sub,
                    ),
                  ),
                ] else if (a != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 1),
                    child: Icon(Icons.photo_outlined, size: 17, color: p.sub),
                  ),
                ],
                Expanded(
                  child: RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(children: _highlight(snippet, _query, base, hi)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView(_Pal p) {
    if (_error != null) {
      return _message(p, Icons.cloud_off_rounded, 'Search failed', _error!);
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_input.text.trim().length < 2) {
      return _message(
        p,
        Icons.search_rounded,
        'Search this class',
        'Find messages, and the names of files, photos and voice notes '
            'shared here. Type at least 2 letters.',
      );
    }
    if (_query.isEmpty) return const SizedBox.shrink(); // waiting for the pause
    if (_results.isEmpty) {
      return _message(
        p,
        Icons.search_off_rounded,
        'No messages found',
        'Nothing matches "$_query".',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
      itemBuilder: (_, i) {
        if (i == _results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Show more results'),
                    ),
            ),
          );
        }
        return _resultRow(p, _results[i]);
      },
    );
  }

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
                _searchBar(p),
                Divider(height: 1, color: p.border),
                Expanded(child: _resultsView(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  A MESSAGE IN CONTEXT
// ══════════════════════════════════════════════════════════════════════════════

class _ContextScreen extends StatefulWidget {
  const _ContextScreen({
    required this.room,
    required this.message,
    required this.query,
  });

  final ClassRoom room;
  final ChatMessage message;
  final String query;

  @override
  State<_ContextScreen> createState() => _ContextScreenState();
}

class _ContextScreenState extends State<_ContextScreen> {
  final _service = ClassService();
  final _targetKey = GlobalKey();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.messageContext(
        widget.room.id,
        widget.message.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _targetKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.4,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this message.';
      });
    }
  }

  Widget _dateChip(_Pal p, DateTime d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _fmtDate(d),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.sub,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachment(_Pal p, ChatMessage m, Color fg) {
    final a = m.attachment;
    if (a == null) return const SizedBox.shrink();

    if (a.isImage && a.url.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _thumb(a.url),
            width: 180,
            height: 135,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 180,
              height: 135,
              color: p.field,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: p.sub),
            ),
          ),
        ),
      );
    }

    final icon = a.isAudio
        ? Icons.mic_none_rounded
        : Icons.insert_drive_file_outlined;
    final label = a.isAudio
        ? 'Voice note · ${_clock(a.duration)}'
        : (a.name.isEmpty ? 'File' : a.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Pal p, ChatMessage m, double maxW) {
    final mine = m.senderId == ClassSocket().myUserId;
    final isTarget = m.id == widget.message.id;
    final fg = mine ? Colors.white : p.text;
    final sub = mine ? Colors.white70 : p.sub;

    final base = TextStyle(fontSize: 15, color: fg, height: 1.25);
    final hi = base.copyWith(
      fontWeight: FontWeight.w900,
      backgroundColor: const Color(0xFFFFC62E).withValues(alpha: 0.55),
      color: mine ? Colors.white : p.text,
    );

    return Padding(
      key: isTarget ? _targetKey : null,
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 7, 11, 5),
            decoration: BoxDecoration(
              color: mine ? _blue : p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isTarget ? const Color(0xFFFFC62E) : (mine ? _blue : p.border),
                width: isTarget ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      m.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                      ),
                    ),
                  ),
                if (m.deleted)
                  Text(
                    'This message was deleted',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: sub,
                    ),
                  )
                else ...[
                  _attachment(p, m, fg),
                  if (m.text.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: isTarget
                            ? _highlight(m.text, widget.query, base, hi)
                            : [TextSpan(text: m.text, style: base)],
                      ),
                    ),
                ],
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _fmtTime(m.createdAt),
                    style: TextStyle(fontSize: 10.5, color: sub),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(_Pal p) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final maxW = (MediaQuery.sizeOf(context).width * 0.78).clamp(200.0, 460.0);

    final children = <Widget>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;
      if (prev == null || !_sameDay(prev.createdAt, m.createdAt)) {
        children.add(_dateChip(p, m.createdAt));
      }
      children.add(_bubble(p, m, maxW));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: p.text),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Message in context',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: p.text,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Back to chat'),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.border),
                Expanded(child: _body(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}