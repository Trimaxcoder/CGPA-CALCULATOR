// lib/screens/class_screen.dart
//
// One class space: live chat.
//
// Two modes:
//  • normal   (phones): a full screen with a back button, as before.
//  • embedded (tablet / desktop / web): the right-hand pane of the
//    WhatsApp-style split view. Fills the space it is given, has no back
//    button, Enter sends and Shift+Enter adds a new line.
//
// In embedded mode the parent MUST give it a key tied to the room so that
// switching rooms builds a fresh chat store:
//   ClassScreen(key: ValueKey(room.id), room: room, embedded: true, ...)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../stores/class_chat_store.dart';
import '../widgets/snackBar.dart';
import 'anon_screen.dart';
import 'members_screen.dart';
import 'class_settings_screen.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

const _senderColors = [
  Color(0xFF1E88E5),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFD97706),
  Color(0xFF059669),
  Color(0xFFDB2777),
];

Color _senderColor(String id) {
  final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
  return _senderColors[sum % _senderColors.length];
}

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

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Action(this.icon, this.label, this.onTap, {this.danger = false});
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ClassScreen extends StatefulWidget {
  const ClassScreen({
    super.key,
    required this.room,
    this.embedded = false,
    this.onRemoved,
  });

  final ClassRoom room;

  /// true = used as the right-hand pane of the split view (wide screens).
  final bool embedded;

  /// Embedded mode only: called when the user was removed from this class,
  /// so the parent can clear its selection instead of popping a route.
  final VoidCallback? onRemoved;

  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen> {
  late final ClassChatStore _store;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  ChatMessage? _replyingTo;
  bool _closing = false;

  /// Width of the area the chat is drawn in (not the whole window), so
  /// bubbles and padding scale with the pane on desktop.
  double _paneW = 400;

  @override
  void initState() {
    super.initState();
    _store = ClassChatStore(widget.room.id, initialRoom: widget.room);
    _store.addListener(_checkRemoved);
    _scroll.addListener(_onScroll);
    unawaited(_store.init());
  }

  @override
  void dispose() {
    _store.removeListener(_checkRemoved);
    _store.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Desktop behaviour (embedded only): Enter sends, Shift+Enter = new line.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!widget.embedded) return KeyEventResult.ignored;
    final isEnter = e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (e is KeyDownEvent &&
        isEnter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The list is upside down (newest at the bottom), so "the top" of the
  /// conversation is the end of the scroll range: load older messages there.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _store.loadOlder();
    }
  }

  void _checkRemoved() {
    if (_store.removed && !_closing && mounted) {
      _closing = true;
      AppSnackBar.auto(context, 'You were removed from this class.');
      if (widget.embedded) {
        widget.onRemoved?.call();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final reply = _replyingTo;
    _input.clear();
    setState(() => _replyingTo = null);

    // keep typing on desktop without clicking back into the field
    if (widget.embedded) _focus.requestFocus();

    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    final ack = await _store.send(text, replyTo: reply);
    if (!ack.ok && ack.error != 'OFFLINE' && mounted) {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  // ── Sheets (width-limited so they look right on desktop) ──────────────────

  Future<void> _sheet(_Pal p, WidgetBuilder builder) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (ctx) =>
          SafeArea(child: SingleChildScrollView(child: builder(ctx))),
    );
  }

  // ── Message actions ────────────────────────────────────────────────────────

  void _showActions(ChatMessage m) {
    if (m.sendState == SendState.sending || m.deleted) return;

    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final room = _store.room ?? widget.room;
    final mine = _store.isMine(m);
    final actions = <_Action>[];

    if (m.sendState == SendState.failed) {
      actions.add(_Action(
        Icons.refresh_rounded,
        'Try again',
        () => _store.retry(m.id),
      ));
      actions.add(_Action(
        Icons.delete_outline_rounded,
        'Discard',
        () => _store.discardFailed(m.id),
        danger: true,
      ));
    } else {
      actions.add(_Action(Icons.reply_rounded, 'Reply', () {
        setState(() => _replyingTo = m);
        _focus.requestFocus();
      }));
      actions.add(_Action(Icons.copy_rounded, 'Copy', () {
        Clipboard.setData(ClipboardData(text: m.text));
        AppSnackBar.auto(context, 'Message copied');
      }));
      if (room.isAdmin) {
        actions.add(_Action(
          m.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          m.pinned ? 'Unpin' : 'Pin to top',
          () => _togglePin(m),
        ));
      }
      if (mine || room.isAdmin) {
        actions.add(_Action(
          Icons.delete_outline_rounded,
          'Delete',
          () => _confirmDelete(m),
          danger: true,
        ));
      }
      if (!mine) {
        actions.add(_Action(
          Icons.flag_outlined,
          'Report',
          () => _report(m),
          danger: true,
        ));
      }
    }

    _sheet(
      p,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(p),
            const SizedBox(height: 8),
            for (final a in actions)
              ListTile(
                leading: Icon(
                  a.icon,
                  color: a.danger ? Colors.redAccent : p.text,
                ),
                title: Text(
                  a.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: a.danger ? Colors.redAccent : p.text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  a.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(ChatMessage m) async {
    try {
      await _store.pin(m.id, pinned: !m.pinned);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  Future<void> _confirmDelete(ChatMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes the message for everyone in the class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ack = await _store.deleteMessage(m.id);
    if (!ack.ok && mounted) AppSnackBar.auto(context, ack.errorText);
  }

  Future<void> _report(ChatMessage m) async {
    try {
      await _store.report(m.id);
      if (mounted) AppSnackBar.auto(context, 'Report sent to the class admins.');
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  void _showPinned() {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final pins = _store.pinned;
    if (pins.isEmpty) return;

    _sheet(
      p,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _handle(p)),
            const SizedBox(height: 16),
            Text(
              'Pinned messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: p.text,
              ),
            ),
            const SizedBox(height: 12),
            for (final m in pins)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _senderColor(m.senderId),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(m.text, style: TextStyle(color: p.text, height: 1.35)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showInfo(ClassRoom room) {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final code = room.joinCode;

    _sheet(
      p,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _handle(p)),
            const SizedBox(height: 16),
            Text(
              room.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: p.text,
              ),
            ),
            if (room.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                room.description,
                style: TextStyle(fontSize: 14, color: p.sub, height: 1.35),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${room.memberCount} ${room.memberCount == 1 ? 'member' : 'members'}',
              style: TextStyle(fontSize: 13, color: p.sub),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => MembersScreen(room: room),
                        ),
                      )
                      .then((_) => _store.refresh());
                },
                icon: const Icon(Icons.groups_rounded, size: 20),
                label: Text(
                  room.isAdmin ? 'Members and requests' : 'Members',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.text,
                  side: BorderSide(color: p.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (room.isAdmin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => ClassSettingsScreen(room: room),
                          ),
                        )
                        .then((_) => _store.refresh());
                  },
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  label: const Text(
                    'Class settings',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.text,
                    side: BorderSide(color: p.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            if (code != null) ...[
              const SizedBox(height: 20),
              Text(
                'CLASS CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: p.sub,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    Navigator.pop(ctx);
                    AppSnackBar.auto(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'Copy code',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
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

    final chat = LayoutBuilder(
      builder: (context, c) {
        _paneW = c.maxWidth;
        return ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final room = _store.room ?? widget.room;
            return Column(
              children: [
                _header(p, room),
                if (!_store.online) _offlineBanner(),
                _anonBanner(p, room),
                _pinnedBar(p),
                Expanded(child: _body(p)),
                _typingLine(p),
                _composer(p, room),
              ],
            );
          },
        );
      },
    );

    // Right-hand pane of the split view: fill whatever space we are given.
    if (widget.embedded) {
      return Material(color: p.bg, child: chat);
    }

    // Phone: full screen, as before.
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: chat,
          ),
        ),
      ),
    );
  }

  void _openAnon(ClassRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnonScreen(room: room)),
    );
  }

  /// Shown under the header while an anonymous session is open.
  Widget _anonBanner(_Pal p, ClassRoom room) {
    final s = _store.activeSession;
    if (s == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openAnon(room),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            const Icon(Icons.masks_rounded, size: 18, color: Color(0xFF059669)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.prompt.isEmpty
                    ? 'An anonymous session is open. Tap to post without your name.'
                    : 'Anonymous: ${s.prompt}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.sub),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _avatar(ClassRoom room, {double size = 40}) {
    final c = _senderColor(room.id);
    final name = room.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.18),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: c,
        ),
      ),
    );
  }

  Widget _header(_Pal p, ClassRoom room) {
    final embedded = widget.embedded;

    return Container(
      padding: EdgeInsets.fromLTRB(embedded ? 14 : 4, 6, 8, 6),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          if (!embedded)
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: p.text),
              onPressed: () => Navigator.maybePop(context),
            ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showInfo(room),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    if (embedded) ...[
                      _avatar(room),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: p.text,
                            ),
                          ),
                          Text(
                            '${room.memberCount} ${room.memberCount == 1 ? 'member' : 'members'}',
                            style: TextStyle(fontSize: 12, color: p.sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Anonymous space',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.masks_rounded, color: p.text),
                if (_store.activeSession != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        shape: BoxShape.circle,
                        border: Border.all(color: p.card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _openAnon(room),
          ),
          IconButton(
            tooltip: 'Class info',
            icon: Icon(Icons.info_outline_rounded, color: p.text),
            onPressed: () => _showInfo(room),
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.orange.withValues(alpha: 0.18),
      child: const Text(
        'Connecting...',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.orange,
        ),
      ),
    );
  }

  Widget _pinnedBar(_Pal p) {
    final pins = _store.pinned;
    if (pins.isEmpty) return const SizedBox.shrink();
    final top = pins.first;

    return GestureDetector(
      onTap: _showPinned,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.1),
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin_rounded, size: 16, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${top.senderName}: ${top.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: p.text),
              ),
            ),
            if (pins.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '+${pins.length - 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────────────

  Widget _body(_Pal p) {
    final msgs = _store.messages;

    if (_store.loading && msgs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_store.error != null && msgs.isEmpty) {
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

    if (msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 52, color: p.sub),
              const SizedBox(height: 12),
              Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Say hello to the class.',
                style: TextStyle(fontSize: 13, color: p.sub),
              ),
            ],
          ),
        ),
      );
    }

    // On a wide pane keep the conversation in a comfortable column instead
    // of pinning bubbles to the far edges.
    final sidePad = widget.embedded && _paneW > 900 ? (_paneW - 900) / 2 : 0.0;

    final n = msgs.length;
    return ListView.builder(
      controller: _scroll,
      reverse: true, // index 0 = newest, so the chat stays at the bottom
      padding: EdgeInsets.fromLTRB(
        (widget.embedded ? 16 : 12) + sidePad,
        8,
        (widget.embedded ? 16 : 12) + sidePad,
        8,
      ),
      itemCount: n + (_store.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == n) {
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

        final m = msgs[n - 1 - i];
        final older = i + 1 < n ? msgs[n - 2 - i] : null;
        final mine = _store.isMine(m);
        final showDate = older == null || !_sameDay(older.createdAt, m.createdAt);
        final newSender = older == null || older.senderId != m.senderId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _dateChip(p, m.createdAt),
            _bubble(
              p,
              m,
              mine: mine,
              showName: !mine && (showDate || newSender),
              topGap: showDate ? 4 : (newSender ? 10 : 3),
            ),
          ],
        );
      },
    );
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
            _dayLabel(d),
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

  Widget _bubble(
    _Pal p,
    ChatMessage m, {
    required bool mine,
    required bool showName,
    required double topGap,
  }) {
    final failed = m.sendState == SendState.failed;
    final sending = m.sendState == SendState.sending;
    final fg = mine ? Colors.white : p.text;
    final subFg = mine ? Colors.white70 : p.sub;
    // sized from the pane, not the window, so it is right in the split view
    final maxBubble = (_paneW * (widget.embedded ? 0.72 : 0.78))
        .clamp(0.0, widget.embedded ? 620.0 : 520.0)
        .toDouble();

    final Widget content = m.deleted
        ? Text(
            'This message was deleted',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: subFg,
            ),
          )
        : Text(
            m.text,
            style: TextStyle(fontSize: 15, color: fg, height: 1.3),
          );

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showActions(m),
          // desktop: right-click opens the same menu
          onSecondaryTap: () => _showActions(m),
          onTap: failed ? () => _showActions(m) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubble),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: mine ? _blue : p.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: mine ? null : Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        m.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _senderColor(m.senderId),
                        ),
                      ),
                    ),
                  if (m.replyTo != null && !m.deleted)
                    _replyBox(p, m.replyTo!, mine),
                  content,
                  const SizedBox(height: 3),
                  if (failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _store.failReason(m.id) ?? 'Not sent. Tap to retry.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFB4AB),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (m.pinned && !m.deleted)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded, size: 11, color: subFg),
                        ),
                      Text(
                        TimeOfDay.fromDateTime(m.createdAt).format(context),
                        style: TextStyle(fontSize: 10.5, color: subFg),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        if (sending)
                          Icon(Icons.access_time_rounded, size: 12, color: subFg)
                        else if (failed)
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: Color(0xFFFFB4AB),
                          )
                        else
                          Icon(Icons.done_rounded, size: 14, color: subFg),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _replyBox(_Pal p, ReplyPreview r, bool mine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: mine ? Colors.white.withValues(alpha: 0.16) : p.field,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: mine ? Colors.white70 : _accent),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: mine ? Colors.white : _accent,
                          ),
                        ),
                        Text(
                          r.deleted ? 'Message deleted' : r.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle:
                                r.deleted ? FontStyle.italic : FontStyle.normal,
                            color: mine ? Colors.white70 : p.sub,
                          ),
                        ),
                      ],
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

  // ── Typing line + composer ─────────────────────────────────────────────────

  Widget _typingLine(_Pal p) {
    final names = _store.typingNames;
    if (names.isEmpty) return const SizedBox.shrink();

    final String text;
    if (names.length == 1) {
      text = '${names[0]} is typing...';
    } else if (names.length == 2) {
      text = '${names[0]} and ${names[1]} are typing...';
    } else {
      text = 'Several people are typing...';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: p.sub,
          ),
        ),
      ),
    );
  }

  Widget _notice(_Pal p, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: p.sub),
      ),
    );
  }

  Widget _composer(_Pal p, ClassRoom room) {
    if (room.archived) return _notice(p, 'This class has been archived.');
    if (room.chatLocked && !room.isAdmin) {
      return _notice(p, 'Only admins can send messages right now.');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null) _replyBar(p, _replyingTo!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: p.text, fontSize: 15),
                  onChanged: (v) {
                    if (v.trim().isNotEmpty) _store.userIsTyping();
                  },
                  decoration: InputDecoration(
                    hintText: widget.embedded
                        ? 'Type a message (Enter to send, Shift+Enter for a new line)'
                        : 'Message',
                    hintStyle: TextStyle(color: p.sub),
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
                color: _blue,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _send,
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 21),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _replyBar(_Pal p, ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: p.field,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: _accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${m.senderName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                        Text(
                          m.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.sub),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: p.sub),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}