// lib/screens/anon_screen.dart
//
// The anonymous space of a class. Admins start and end sessions; everyone in
// the class can post without a name while a session is open.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../stores/anon_store.dart';
import '../widgets/snackBar.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);
const _green = Color(0xFF059669);

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

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return _shortDate(d);
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class AnonScreen extends StatefulWidget {
  const AnonScreen({super.key, required this.room});

  final ClassRoom room;

  @override
  State<AnonScreen> createState() => _AnonScreenState();
}

class _AnonScreenState extends State<AnonScreen> {
  late final AnonStore _store;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool get _isAdmin => widget.room.isAdmin;

  @override
  void initState() {
    super.initState();
    _store = AnonStore(widget.room.id);
    _scroll.addListener(_onScroll);
    unawaited(_store.init());
  }

  @override
  void dispose() {
    _store.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) _store.loadOlder();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _store.sending) return;

    final ack = await _store.sendPost(text);
    if (!mounted) return;

    if (ack.ok) {
      _input.clear();
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  Future<void> _showStart() async {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      builder: (_) => _StartSheet(store: _store, palette: p),
    );
  }

  Future<void> _confirmEnd() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this session?'),
        content: const Text(
          'Students will no longer be able to post. '
          'The posts stay visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'End session',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final err = await _store.closeSession();
    if (err != null && mounted) AppSnackBar.auto(context, err);
  }

  void _showPostActions(AnonPost post) {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.visibility_off_outlined, color: p.text),
                title: Text(
                  'Hide post',
                  style: TextStyle(fontWeight: FontWeight.w600, color: p.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _hide(post, block: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                title: const Text(
                  'Hide and block sender',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlock(post);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlock(AnonPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this sender?'),
        content: const Text(
          'The post is hidden and its sender cannot post again in this '
          'session. You will not find out who they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await _hide(post, block: true);
  }

  Future<void> _hide(AnonPost post, {required bool block}) async {
    final err = await _store.hidePost(post.id, block: block);
    if (!mounted) return;
    AppSnackBar.auto(
      context,
      err ?? (block ? 'Post hidden and sender blocked' : 'Post hidden'),
    );
  }

  void _showHistory() {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final sessions = _store.sessions;
    final viewingId = _store.viewing?.id;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _handle(p)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    'Past sessions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: p.text,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in sessions)
                        ListTile(
                          title: Text(
                            s.prompt.isEmpty ? 'Anonymous session' : s.prompt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                          subtitle: Text(
                            '${_shortDate(s.createdAt)} · '
                            '${s.postCount} ${s.postCount == 1 ? 'post' : 'posts'}'
                            '${s.isOpen ? ' · Open' : ''}',
                            style: TextStyle(color: p.sub, fontSize: 12.5),
                          ),
                          trailing: s.id == viewingId
                              ? const Icon(Icons.check_rounded, color: _accent)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _store.viewSession(s);
                          },
                        ),
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

  Widget _handle(_Pal p) => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: p.isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      );

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
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                return Column(
                  children: [
                    _header(p),
                    _privacyNote(p),
                    _sessionBanner(p),
                    Expanded(child: _body(p)),
                    _composer(p),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(_Pal p) {
    final hasHistory = _store.sessions.isNotEmpty;
    final open = _store.openSession;

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
                  'Anonymous space',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
                Text(
                  widget.room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.sub),
                ),
              ],
            ),
          ),
          if (hasHistory)
            IconButton(
              tooltip: 'Past sessions',
              icon: Icon(Icons.history_rounded, color: p.text),
              onPressed: _showHistory,
            ),
          if (_isAdmin && open != null)
            TextButton(
              onPressed: _store.busy ? null : _confirmEnd,
              child: const Text(
                'End',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (_isAdmin && open == null)
            IconButton(
              tooltip: 'Start a session',
              icon: const Icon(Icons.add_circle_outline_rounded, color: _accent),
              onPressed: _store.busy ? null : _showStart,
            ),
        ],
      ),
    );
  }

  Widget _privacyNote(_Pal p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _accent.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nobody in this class, including admins, can see who posted.',
              style: TextStyle(fontSize: 12, color: p.sub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionBanner(_Pal p) {
    final s = _store.viewing;
    if (s == null) return const SizedBox.shrink();

    final open = _store.openSession;
    final browsingOld = !s.isOpen && open != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (s.isOpen ? _green : p.sub).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.isOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: s.isOpen ? _green : p.sub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${s.postCount} ${s.postCount == 1 ? 'post' : 'posts'}',
                style: TextStyle(fontSize: 12.5, color: p.sub),
              ),
              const Spacer(),
              Text(
                _shortDate(s.createdAt),
                style: TextStyle(fontSize: 12, color: p.sub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.prompt.isEmpty ? 'Say anything. No names.' : s.prompt,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.text,
              height: 1.3,
            ),
          ),
          if (browsingOld)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: _store.viewOpen,
                child: const Text(
                  'A session is open now. Tap to go there.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(_Pal p) {
    if (_store.loading && _store.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_store.error != null && _store.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: p.sub),
              const SizedBox(height: 12),
              Text(
                _store.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _store.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // Never any session in this class
    if (_store.viewing == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.masks_rounded, size: 56, color: p.sub),
              const SizedBox(height: 14),
              Text(
                'No anonymous session yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isAdmin
                    ? 'Start one so students can share questions and feedback without their names.'
                    : 'Your class admin can start one. When they do, you will be able to post without your name.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: p.sub, height: 1.4),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _store.busy ? null : _showStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Start a session',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final posts = _store.posts;
    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _store.viewing!.isOpen
                ? 'No posts yet. Be the first to say something.'
                : 'No posts in this session.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.sub),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: posts.length + (_store.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == posts.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        return _postCard(p, posts[i]);
      },
    );
  }

  Widget _postCard(_Pal p, AnonPost post) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onLongPress: _isAdmin ? () => _showPostActions(post) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  post.text,
                  style: TextStyle(fontSize: 15, color: p.text, height: 1.35),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.masks_rounded, size: 13, color: p.sub),
                  const SizedBox(width: 5),
                  Text(
                    'Anonymous · ${_ago(post.createdAt)}',
                    style: TextStyle(fontSize: 11.5, color: p.sub),
                  ),
                  const Spacer(),
                  if (_isAdmin)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showPostActions(post),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.more_horiz_rounded, size: 20, color: p.sub),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(_Pal p) {
    final s = _store.viewing;

    // No open session being viewed: nothing to type into
    if (s == null) return const SizedBox.shrink();

    if (!s.isOpen) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Text(
          'This session is closed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.sub),
        ),
      );
    }

    if (widget.room.archived) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Text(
          'This class has been archived.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.sub),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: p.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Post anonymously',
                hintStyle: TextStyle(color: p.sub),
                prefixIcon: Icon(Icons.masks_rounded, size: 20, color: p.sub),
                counterText: '',
                filled: true,
                fillColor: p.field,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _store.sending ? _blue.withValues(alpha: 0.5) : _blue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _store.sending ? null : _send,
              child: SizedBox(
                width: 46,
                height: 46,
                child: _store.sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  START SESSION SHEET (admins)
// ══════════════════════════════════════════════════════════════════════════════

class _StartSheet extends StatefulWidget {
  const _StartSheet({required this.store, required this.palette});

  final AnonStore store;
  final _Pal palette;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  final _prompt = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final err = await widget.store.startSession(_prompt.text);
    if (!mounted) return;

    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = err;
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Start an anonymous session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Everyone in the class will see it right away.',
            style: TextStyle(fontSize: 13, color: p.sub),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _prompt,
            autofocus: true,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: p.text),
            decoration: InputDecoration(
              hintText: 'What should students share? (optional)',
              hintStyle: TextStyle(color: p.sub),
              counterText: '',
              filled: true,
              fillColor: p.field,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Start session',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}