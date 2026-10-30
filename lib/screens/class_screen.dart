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
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/attachment_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';
import '../services/voice_player.dart';
import '../services/voice_recorder.dart';
import '../stores/class_chat_store.dart';
import '../widgets/chat_doodle_background.dart';
import '../widgets/snackBar.dart';
import 'anon_screen.dart';
import 'class_info_screen.dart';
import 'class_forward_sheet.dart';
import 'class_search_screen.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

/// The six quick reactions. Written as escapes so they match the server
/// exactly (the heart carries an invisible variation selector).
const _reactionEmoji = [
  '\u{1F44D}',
  '\u2764\uFE0F',
  '\u{1F602}',
  '\u{1F62E}',
  '\u{1F622}',
  '\u{1F64F}',
];

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

enum _AttachSource { camera, gallery, file }

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
  final _files = AttachmentService();
  late final VoiceRecorder _voice = VoiceRecorder(onLimit: _finishRecording);

  ChatMessage? _replyingTo;

  /// The message whose text is being edited right now (null = normal typing)
  ChatMessage? _editing;

  /// How long after sending a message its text can still be edited
  static const _editWindow = Duration(minutes: 15);

  bool _closing = false;
  bool _hasText = false;

  // ── @mentions ──────────────────────────────────────────────────────────────
  final _classService = ClassService();

  /// Members who can be tagged: active, with a username, not me.
  List<ClassMember> _mentionPool = [];
  bool _poolLoading = false;
  bool _poolLoaded = false;

  /// What has been typed after the "@" at the cursor (null = not tagging)
  String? _mentionQuery;

  /// Where that "@" sits in the text
  int _mentionStart = 0;

  /// Panes wider than this show the messages in a centred column.
  static const double _wideAt = 880;
  static const double _columnW = 820;

  /// Space between the messages and the left / right edge of the pane.
  double get _edgePad => _paneW > _wideAt ? (_paneW - _columnW) / 2 : 18;

  /// Width of the area the chat is drawn in (not the whole window), so
  /// bubbles and padding scale with the pane on desktop.
  double _paneW = 400;

  @override
  void initState() {
    super.initState();
    _store = ClassChatStore(widget.room.id, initialRoom: widget.room);
    _store.addListener(_checkRemoved);
    _scroll.addListener(_onScroll);
    _input.addListener(_onInputChanged);
    unawaited(_store.init());
  }

  @override
  void dispose() {
    _store.removeListener(_checkRemoved);
    _store.dispose();
    _voice.dispose();
    VoicePlayer.instance.stop();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Switches the round button between the microphone (empty box) and send.
  void _onInputChanged() {
    final has = _input.text.trim().isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
    _updateMentionQuery();
  }

  /// Looks at the word just before the cursor. If it starts with "@", the
  /// member suggestions open.
  void _updateMentionQuery() {
    final text = _input.text;
    final sel = _input.selection;

    String? query;
    var start = 0;
    if (sel.isValid && sel.isCollapsed && sel.baseOffset <= text.length) {
      final before = text.substring(0, sel.baseOffset);
      final hit = RegExp(r'(^|\s)@([A-Za-z0-9_.]{0,20})$').firstMatch(before);
      if (hit != null) {
        query = hit.group(2)!.toLowerCase();
        start = before.length - query.length - 1;
      }
    }

    if (query == _mentionQuery && start == _mentionStart) return;
    if (!mounted) return;
    setState(() {
      _mentionQuery = query;
      _mentionStart = start;
    });
    if (query != null && !_poolLoaded && !_poolLoading) _loadMentionPool();
  }

  Future<void> _loadMentionPool() async {
    setState(() => _poolLoading = true);
    try {
      final all = await _classService.members(widget.room.id);
      if (!mounted) return;
      final me = _store.myId;
      setState(() {
        _mentionPool = all
            .where((m) => m.status == 'active' && m.username.isNotEmpty && m.userId != me)
            .toList();
        _poolLoaded = true;
        _poolLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Try again the next time "@" is typed
      setState(() => _poolLoading = false);
    }
  }

  List<ClassMember> get _mentionMatches {
    final q = _mentionQuery;
    if (q == null) return const [];
    final starts = <ClassMember>[];
    final contains = <ClassMember>[];
    for (final m in _mentionPool) {
      final u = m.username.toLowerCase();
      if (u.startsWith(q)) {
        starts.add(m);
      } else if (u.contains(q) || m.name.toLowerCase().contains(q)) {
        contains.add(m);
      }
    }
    return [...starts, ...contains].take(6).toList();
  }

  /// Replaces the "@abc" being typed with "@username " and moves on.
  void _pickMention(ClassMember m) {
    final text = _input.text;
    final end = _input.selection.baseOffset.clamp(0, text.length);
    final start = _mentionStart.clamp(0, end);
    final insert = '@${m.username} ';
    final next = text.replaceRange(start, end, insert);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _focus.requestFocus();
  }

  /// The suggestion list that opens above the message box.
  Widget _mentionBar(_Pal p) {
    if (_mentionQuery == null) return const SizedBox.shrink();

    final matches = _mentionMatches;
    Widget content;

    if (_poolLoading && !_poolLoaded) {
      content = const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (matches.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          _mentionPool.isEmpty
              ? 'Nobody here can be tagged yet. Members need to set a username in their profile.'
              : 'No member matches "@${_mentionQuery!}".',
          style: TextStyle(fontSize: 13, color: p.sub, height: 1.35),
        ),
      );
    } else {
      content = ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: matches.length,
        itemBuilder: (_, i) {
          final m = matches[i];
          final initial = m.name.isEmpty ? '?' : m.name[0].toUpperCase();
          return InkWell(
            onTap: () => _pickMention(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _accent,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${m.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        if (m.name.isNotEmpty && m.name != m.username)
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: p.sub),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 230),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }

  /// The message text as spans, with every tagged @name in bold colour.
  /// Only names the server confirmed as class members are highlighted.
  List<InlineSpan> _textSpans(
    ChatMessage m,
    TextStyle base, {
    required bool mine,
  }) {
    if (m.mentions.isEmpty) return [TextSpan(text: m.text, style: base)];

    final names = m.mentions.map((x) => x.username).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final re = RegExp(
      '@(${names.map(RegExp.escape).join('|')})(?![A-Za-z0-9_])',
      caseSensitive: false,
    );
    final me = _store.myId;
    final text = m.text;
    final spans = <InlineSpan>[];
    var at = 0;

    for (final hit in re.allMatches(text)) {
      // "a@name" is an email, not a tag
      if (hit.start > 0 && RegExp(r'[A-Za-z0-9_.@]').hasMatch(text[hit.start - 1])) {
        continue;
      }
      if (hit.start > at) {
        spans.add(TextSpan(text: text.substring(at, hit.start), style: base));
      }
      final name = hit.group(1)!.toLowerCase();
      final isMe = m.mentions.any(
        (x) => x.username.toLowerCase() == name && x.userId == me,
      );
      spans.add(TextSpan(
        text: hit.group(0),
        style: base.copyWith(
          fontWeight: FontWeight.w800,
          color: mine ? const Color(0xFFBBDEFB) : _accent,
          backgroundColor:
              isMe ? _accent.withValues(alpha: 0.2) : null,
        ),
      ));
      at = hit.end;
    }
    if (at < text.length) {
      spans.add(TextSpan(text: text.substring(at), style: base));
    }
    return spans;
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

  bool _canEdit(ChatMessage m) {
    final room = _store.room ?? widget.room;
    final a = m.attachment;
    return _store.isMine(m) &&
        m.sendState == SendState.sent &&
        !m.deleted &&
        !room.archived &&
        !(room.chatLocked && !room.isAdmin) &&
        !(a != null && a.isAudio) &&
        DateTime.now().difference(m.createdAt) < _editWindow;
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editing = m;
      _replyingTo = null;
    });
    _input.value = TextEditingValue(
      text: m.text,
      selection: TextSelection.collapsed(offset: m.text.length),
    );
    _focus.requestFocus();
  }

  /// Pick one or more classes and send them a copy of this message.
  Future<void> _startForward(ChatMessage m) async {
    final picked = await showForwardPicker(
      context,
      currentClassId: widget.room.id,
      preview: m.previewText,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    AppSnackBar.auto(context, 'Forwarding...');
    final ack = await _store.forward(m, [for (final c in picked) c.id]);
    if (!mounted) return;

    final raw = ack.data['results'];
    if (raw is! List) {
      AppSnackBar.auto(context, ack.errorText);
      return;
    }

    final names = {for (final c in picked) c.id: c.name};
    final done = <String>[];
    String? failure;
    for (final r in raw) {
      if (r is! Map) continue;
      final id = '${r['classId']}';
      if (r['ok'] == true) {
        done.add(names[id] ?? 'a class');
      } else {
        failure ??= SocketAck(ok: false, error: r['error'] as String?).errorText;
      }
    }

    final String text;
    if (done.isEmpty) {
      text = failure ?? 'Could not forward the message.';
    } else {
      final where = done.length == 1 ? done.first : '${done.length} classes';
      text = failure == null
          ? 'Forwarded to $where'
          : 'Forwarded to $where. Some failed: $failure';
    }
    AppSnackBar.auto(context, text);
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _input.clear();
  }

  Future<void> _submitEdit() async {
    final m = _editing;
    if (m == null) return;

    final text = _input.text.trim();
    // A text message cannot become empty. A photo or file may lose its caption.
    if (text.isEmpty && m.attachment == null) return;

    setState(() => _editing = null);
    _input.clear();
    if (text == m.text) return; // nothing changed

    final ack = await _store.editMessage(m, text);
    if (!ack.ok && ack.error != 'OFFLINE' && mounted) {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  Future<void> _send() async {
    if (_editing != null) {
      await _submitEdit();
      return;
    }

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

  // ── Attachments ────────────────────────────────────────────────────────────

  bool get _hasCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final GlobalKey _plusKey = GlobalKey();

  /// A small pop-up right above the + button (Camera / Photos / Files).
  Future<void> _showAttachMenu() async {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);

    final button = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final items = <(IconData, Color, String, _AttachSource)>[
      if (_hasCamera)
        (
          Icons.photo_camera_rounded,
          const Color(0xFFE11D48),
          'Camera',
          _AttachSource.camera,
        ),
      (
        Icons.photo_library_rounded,
        const Color(0xFF1E88E5),
        'Photos',
        _AttachSource.gallery,
      ),
      (
        Icons.insert_drive_file_rounded,
        const Color(0xFF7C3AED),
        'Files',
        _AttachSource.file,
      ),
    ];

    // The menu opens downwards from the point we give it, so start high enough
    // that it ends just above the button.
    const rowHeight = 48.0;
    final menuHeight = items.length * rowHeight + 16;
    final top = topLeft.dy - menuHeight - 6;

    final picked = await showMenu<_AttachSource>(
      context: context,
      color: p.card,
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        top,
        overlay.size.width - topLeft.dx - 170,
        overlay.size.height - top - menuHeight,
      ),
      items: [
        for (final item in items)
          PopupMenuItem<_AttachSource>(
            value: item.$4,
            height: rowHeight,
            child: Row(
              children: [
                Icon(item.$1, color: item.$2, size: 22),
                const SizedBox(width: 14),
                Text(
                  item.$3,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (picked != null && mounted) _attach(picked);
  }

  Future<void> _attach(_AttachSource source) async {
    final PickedAttachment? picked;
    try {
      switch (source) {
        case _AttachSource.camera:
          picked = await _files.pickCamera();
        case _AttachSource.gallery:
          picked = await _files.pickImage();
        case _AttachSource.file:
          picked = await _files.pickFile();
      }
    } on UploadException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
      return;
    }
    if (picked == null || !mounted) return;

    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final caption = await showDialog<String>(
      context: context,
      builder: (_) => _AttachPreviewDialog(picked: picked!, pal: p),
    );
    if (caption == null || !mounted) return;

    final reply = _replyingTo;
    setState(() => _replyingTo = null);

    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    final ack = await _store.sendAttachment(
      picked,
      caption: caption,
      replyTo: reply,
    );
    if (!ack.ok && ack.error != 'OFFLINE' && mounted) {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  Future<void> _openUrl(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      AppSnackBar.auto(context, 'Could not open that file.');
    }
  }

  void _openImage(ChatAttachment a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(
          url: a.url,
          name: a.name,
          onOpenOutside: () => _openUrl(a.url),
        ),
      ),
    );
  }

  String _clock(Duration d) {
    final m = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _toggleVoice(ChatAttachment a) async {
    try {
      await VoicePlayer.instance.toggle(
        a.url,
        knownDuration: a.duration > 0 ? Duration(seconds: a.duration) : null,
      );
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Could not play this voice note.');
    }
  }

  /// A voice note: play / pause button, a progress bar you can tap to jump
  /// around, and the time.
  Widget _voiceView(
    _Pal p,
    ChatAttachment a, {
    required bool mine,
    required double width,
    required bool uploading,
  }) {
    final fg = mine ? Colors.white : p.text;
    final subFg = mine ? Colors.white70 : p.sub;
    final track = mine ? Colors.white30 : p.border;
    final fill = mine ? Colors.white : _accent;

    return SizedBox(
      width: width,
      child: ListenableBuilder(
        listenable: VoicePlayer.instance,
        builder: (context, _) {
          final vp = VoicePlayer.instance;
          final playing = vp.isPlaying(a.url);
          final loading = vp.isLoading(a.url);
          final current = vp.isCurrent(a.url);
          final total = vp.durationOf(a.url, Duration(seconds: a.duration));
          final pos = vp.positionOf(a.url);
          final progress = current && total.inMilliseconds > 0
              ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;

          return Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : () => _toggleVoice(a),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.2)
                        : _accent.withValues(alpha: 0.14),
                  ),
                  child: (uploading || loading)
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: fg,
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: mine ? Colors.white : _accent,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: uploading || !current
                              ? null
                              : (d) => VoicePlayer.instance.seekTo(
                                    a.url,
                                    d.localPosition.dx / c.maxWidth,
                                  ),
                          child: SizedBox(
                            height: 18,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: track,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Container(
                                  height: 4,
                                  width: c.maxWidth * progress,
                                  decoration: BoxDecoration(
                                    color: fill,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Positioned(
                                  left: (c.maxWidth * progress - 6)
                                      .clamp(0.0, c.maxWidth - 12)
                                      .toDouble(),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: fill,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Text(
                      current && playing || (current && pos > Duration.zero)
                          ? '${_clock(pos)} / ${_clock(total)}'
                          : _clock(total),
                      style: TextStyle(fontSize: 11.5, color: subFg),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _fileIcon(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  /// The photo, document or voice note inside a message bubble.
  Widget _attachmentView(
    _Pal p,
    ChatMessage m, {
    required bool mine,
    required double maxBubble,
  }) {
    final a = m.attachment!;
    final uploading = m.sendState == SendState.sending && !a.isUploaded;
    final fg = mine ? Colors.white : p.text;
    final subFg = mine ? Colors.white70 : p.sub;
    final width = (maxBubble - 24).clamp(160.0, 280.0).toDouble();

    // ── Photo ──
    if (a.isImage) {
      final Widget image;
      if (!a.isUploaded && a.localBytes != null) {
        image = Image.memory(a.localBytes!, fit: BoxFit.cover);
      } else if (a.url.isNotEmpty) {
        image = Image.network(
          a.url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final total = progress.expectedTotalBytes;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: total == null
                    ? null
                    : progress.cumulativeBytesLoaded / total,
              ),
            );
          },
          errorBuilder: (context, error, stack) => Center(
            child: Icon(Icons.broken_image_outlined, color: subFg, size: 32),
          ),
        );
      } else {
        image = const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: a.isUploaded ? () => _openImage(a) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: width,
            height: width * 0.75,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: p.field, child: image),
                if (uploading)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
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

    // ── Voice note ──
    if (a.isAudio) {
      return _voiceView(p, a, mine: mine, width: width, uploading: uploading);
    }

    // ── Document ──
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: a.isUploaded ? () => _openUrl(a.url) : null,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: 0.18)
                    : _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: uploading
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    )
                  : Icon(_fileIcon(a.name), color: mine ? Colors.white : _accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name.isEmpty ? 'File' : a.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  Text(
                    uploading ? 'Uploading...' : '${a.sizeLabel}  ·  Tap to open',
                    style: TextStyle(fontSize: 11.5, color: subFg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      actions.add(_Action(
        Icons.shortcut_rounded,
        'Forward',
        () => _startForward(m),
      ));
      if (_canEdit(m)) {
        actions.add(_Action(Icons.edit_outlined, 'Edit', () => _startEdit(m)));
      }
      if (m.text.isNotEmpty) {
        actions.add(_Action(Icons.copy_rounded, 'Copy', () {
          Clipboard.setData(ClipboardData(text: m.text));
          AppSnackBar.auto(context, 'Message copied');
        }));
      }
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
            if (m.sendState != SendState.failed) _emojiRow(p, m, ctx),
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
                    Text(
                      m.previewText,
                      style: TextStyle(color: p.text, height: 1.35),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tapping the class name opens the class info screen: created date,
  /// creator, admins, invite code, shared media, members and settings.
  void _showInfo(ClassRoom room) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ClassInfoScreen(room: room)))
        .then((_) => _store.refresh());
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
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ChatDoodleBackground(isDark: p.isDark),
                      _body(p),
                    ],
                  ),
                ),
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

  void _openSearch(ClassRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClassSearchScreen(room: room)),
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
                            '${room.memberCount} ${room.memberCount == 1 ? 'member' : 'members'}  ·  tap for class info',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
            tooltip: 'Search messages',
            icon: Icon(Icons.search_rounded, color: p.text),
            onPressed: () => _openSearch(room),
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
                '${top.senderName}: ${top.previewText}',
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
        child: SingleChildScrollView(
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
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              _privacyNotice(p),
            ],
          ),
        ),
      );
    }

    // The conversation sits in a centred column, so my messages and other
    // people's messages stay close together instead of being pushed to the far
    // edges of a wide window.
    final edge = _edgePad;

    final n = msgs.length;
    final showNotice = !_store.hasMore;
    final extra = (_store.loadingMore ? 1 : 0) + (showNotice ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      reverse: true, // index 0 = newest, so the chat stays at the bottom
      padding: EdgeInsets.fromLTRB(edge, 8, edge, 8),
      itemCount: n + extra,
      itemBuilder: (context, i) {
        if (i >= n && !(i == n && _store.loadingMore)) {
          // the very top of the conversation
          return _privacyNotice(p);
        }
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
              topGap: showDate
                  ? 4
                  : (newSender ? 12 : (widget.embedded ? 1.5 : 2)),
            ),
          ],
        );
      },
    );
  }

  /// Shown at the start of every chat. Messages are NOT end-to-end encrypted,
  /// so this says so plainly.
  Widget _privacyNotice(_Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC62E).withValues(alpha: p.isDark ? 0.12 : 0.22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Everyone in this class, and its admins, can see these messages. '
            'They are protected on their way to the server, but they are not '
            'end-to-end encrypted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.35, color: p.text),
          ),
        ),
      ),
    );
  }

  Widget _dateChip(_Pal p, DateTime d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    final maxBubble = ((_paneW > _wideAt ? _columnW : _paneW - 2 * _edgePad) * 0.82)
        .clamp(0.0, 520.0)
        .toDouble();

    // Time + ticks (and a pin if the message is pinned)
    final stamp = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.pinned && !m.deleted)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.push_pin_rounded, size: 11, color: subFg),
          ),
        if (m.editedAt != null && !m.deleted)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'edited',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: subFg,
              ),
            ),
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
            _tickIcon(_store.tickOf(m)),
        ],
      ],
    );

    // A plain text message puts the time on the same line as the last words,
    // like WhatsApp, so the bubble is only as tall as the text needs.
    final inlineStamp = !m.deleted &&
        !failed &&
        m.attachment == null &&
        m.text.isNotEmpty;
    final reserve = (mine ? 86.0 : 62.0) +
        (m.pinned ? 15.0 : 0.0) +
        (m.editedAt != null ? 38.0 : 0.0);

    final Widget body;
    if (inlineStamp) {
      body = Stack(
        children: [
          Text.rich(
            TextSpan(
              children: [
                ..._textSpans(
                  m,
                  TextStyle(fontSize: 15, color: fg, height: 1.25),
                  mine: mine,
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: SizedBox(width: reserve, height: 1),
                ),
              ],
            ),
          ),
          Positioned(right: 0, bottom: 0, child: stamp),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.deleted)
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: subFg,
              ),
            )
          else ...[
            if (m.attachment != null)
              _attachmentView(p, m, mine: mine, maxBubble: maxBubble),
            if (m.attachment != null && m.text.isNotEmpty)
              const SizedBox(height: 6),
            if (m.text.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: _textSpans(
                    m,
                    TextStyle(fontSize: 15, color: fg, height: 1.25),
                    mine: mine,
                  ),
                ),
              ),
          ],
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _store.failReason(m.id) ?? 'Not sent. Tap to retry.',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB4AB),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Align(alignment: Alignment.centerRight, child: stamp),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: _withReactions(p, m, mine, _swipeable(m, GestureDetector(
          onLongPress: () => _showActions(m),
          // desktop: right-click opens the same menu
          onSecondaryTap: () => _showActions(m),
          onTap: failed ? () => _showActions(m) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubble),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                11,
                widget.embedded ? 4 : 6,
                11,
                widget.embedded ? 3 : 4,
              ),
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
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        m.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _senderColor(m.senderId),
                        ),
                      ),
                    ),
                  if (m.forwarded && !m.deleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shortcut_rounded, size: 13, color: subFg),
                          const SizedBox(width: 4),
                          Text(
                            'Forwarded',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: subFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (m.replyTo != null && !m.deleted)
                    _replyBox(p, m.replyTo!, mine),
                  body,
                ],
              ),
            ),
          ),
        ))),
      ),
    );
  }

  // ── Swipe to reply, reactions ──────────────────────────────────────────────

  /// Phones: drag a message to the right to reply to it.
  Widget _swipeable(ChatMessage m, Widget child) {
    final room = _store.room ?? widget.room;
    final canReply = !widget.embedded &&
        m.sendState == SendState.sent &&
        !m.deleted &&
        !room.archived &&
        !(room.chatLocked && !room.isAdmin);
    if (!canReply) return child;

    return _SwipeToReply(
      onReply: () {
        setState(() => _replyingTo = m);
        _focus.requestFocus();
      },
      child: child,
    );
  }

  /// The bubble, with the reactions it has received shown underneath.
  Widget _withReactions(_Pal p, ChatMessage m, bool mine, Widget bubble) {
    if (m.deleted || m.reactions.isEmpty) return bubble;

    final mineEmoji = _store.myReactionOn(m);
    final entries = m.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final e in entries)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _react(m, e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: e.key == mineEmoji
                          ? _accent.withValues(alpha: 0.18)
                          : p.field,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: e.key == mineEmoji ? _accent : p.border,
                      ),
                    ),
                    child: Text(
                      '${e.key} ${e.value.length}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _react(ChatMessage m, String emoji) async {
    final ack = await _store.react(m, emoji);
    if (!ack.ok && ack.error != 'NOT_FOUND' && mounted) {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  /// The row of quick reactions at the top of the message menu.
  Widget _emojiRow(_Pal p, ChatMessage m, BuildContext sheetContext) {
    final mineEmoji = _store.myReactionOn(m);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in _reactionEmoji)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.pop(sheetContext);
                _react(m, e);
              },
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: e == mineEmoji
                      ? _accent.withValues(alpha: 0.2)
                      : p.field,
                  border: e == mineEmoji
                      ? Border.all(color: _accent, width: 1.5)
                      : null,
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }

  /// One silver tick = sent. Two silver = a classmate's app has it.
  /// Two gold = a classmate has seen it.
  Widget _tickIcon(TickState t) {
    const silver = Color(0xFFC5CED6);
    const gold = Color(0xFFFFC62E);
    switch (t) {
      case TickState.read:
        return const Icon(Icons.done_all_rounded, size: 17, color: gold);
      case TickState.delivered:
        return const Icon(Icons.done_all_rounded, size: 17, color: silver);
      case TickState.sent:
      case TickState.sending:
      case TickState.failed:
        return const Icon(Icons.done_rounded, size: 16, color: silver);
    }
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing != null)
            _editBar(p, _editing!)
          else if (_replyingTo != null && !_voice.isRecording)
            _replyBar(p, _replyingTo!),
          if (!_voice.isRecording) _mentionBar(p),
          ListenableBuilder(
            listenable: _voice,
            builder: (context, _) =>
                _voice.isRecording ? _recordingRow(p) : _inputRow(p),
          ),
        ],
      ),
    );
  }

  /// The normal bar: [ + message box ] and a round microphone / send button.
  Widget _inputRow(_Pal p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The input box: the + button lives inside it
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: _plusKey,
                  tooltip: 'Attach',
                  icon: Icon(Icons.add_rounded, color: p.sub, size: 26),
                  onPressed: _editing != null ? null : _showAttachMenu,
                ),
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
                      hintText: 'Message',
                      hintStyle: TextStyle(color: p.sub),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Outside the box: microphone by default, send while typing
        _roundButton(
          icon: _editing != null
              ? Icons.check_rounded
              : (_hasText ? Icons.send_rounded : Icons.mic_rounded),
          onTap: (_hasText || _editing != null) ? _send : _startRecording,
          tooltip: _editing != null
              ? 'Save changes'
              : (_hasText ? 'Send' : 'Record a voice note'),
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _blue,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// While recording: [ bin ] [ red dot, time, wave ] and a send button.
  Widget _recordingRow(_Pal p) {
    final elapsed = _voice.elapsed;
    final dotOn = (elapsed.inMilliseconds ~/ 500).isEven;
    final levels = _voice.levels;

    return Row(
      children: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: _cancelRecording,
        ),
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  size: 14,
                  color: dotOn ? Colors.redAccent : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(
                  _clock(elapsed),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final count = (c.maxWidth / 5).floor();
                      final shown = levels.length > count
                          ? levels.sublist(levels.length - count)
                          : levels;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final l in shown)
                            Container(
                              width: 3,
                              height: 4 + l * 24,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _roundButton(
          icon: Icons.send_rounded,
          onTap: _finishRecording,
          tooltip: 'Send voice note',
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    VoicePlayer.instance.stop();
    try {
      final ok = await _voice.start();
      if (!ok && mounted) {
        AppSnackBar.auto(
          context,
          'Allow microphone access to record voice notes.',
        );
      }
    } on UploadException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    }
  }

  Future<void> _cancelRecording() => _voice.cancel();

  Future<void> _finishRecording() async {
    if (!_voice.isRecording) return;

    final RecordedVoice? voice;
    try {
      voice = await _voice.stop();
    } on UploadException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
      return;
    }

    if (voice == null) {
      if (mounted) AppSnackBar.auto(context, 'Voice note was too short.');
      return;
    }
    if (!mounted) return;

    final reply = _replyingTo;
    setState(() => _replyingTo = null);

    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    final ack = await _store.sendAttachment(
      voice.attachment,
      replyTo: reply,
      duration: voice.seconds,
    );
    if (!ack.ok && ack.error != 'OFFLINE' && mounted) {
      AppSnackBar.auto(context, ack.errorText);
    }
  }

  /// Shown above the input while editing a message.
  Widget _editBar(_Pal p, ChatMessage m) {
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
                        const Text(
                          'Editing message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                        Text(
                          m.previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.sub),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: Icon(Icons.close_rounded, size: 18, color: p.sub),
                  onPressed: _cancelEdit,
                ),
              ],
            ),
          ),
        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                        Text(
                          m.previewText,
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

// ══════════════════════════════════════════════════════════════════════════════
//  ATTACHMENT PREVIEW (shown before a photo / file is sent)
// ══════════════════════════════════════════════════════════════════════════════

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _AttachPreviewDialog extends StatefulWidget {
  const _AttachPreviewDialog({required this.picked, required this.pal});

  final PickedAttachment picked;
  final _Pal pal;

  @override
  State<_AttachPreviewDialog> createState() => _AttachPreviewDialogState();
}

class _AttachPreviewDialogState extends State<_AttachPreviewDialog> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() => Navigator.pop(context, _caption.text.trim());

  @override
  Widget build(BuildContext context) {
    final p = widget.pal;
    final picked = widget.picked;
    final isImage = picked.kind == 'image';

    return AlertDialog(
      scrollable: true,
      backgroundColor: p.card,
      title: Text(
        isImage ? 'Send photo' : 'Send file',
        style: TextStyle(fontWeight: FontWeight.w900, color: p.text),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.memory(picked.bytes, fit: BoxFit.contain),
                  ),
                ),
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_rounded,
                    color: _accent,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          picked.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        Text(
                          _fileSize(picked.size),
                          style: TextStyle(fontSize: 12.5, color: p.sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _caption,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: p.text),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)',
                hintStyle: TextStyle(color: p.sub),
                counterText: '',
                filled: true,
                fillColor: p.field,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FULL-SCREEN PHOTO VIEWER
// ══════════════════════════════════════════════════════════════════════════════

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.url,
    required this.name,
    required this.onOpenOutside,
  });

  final String url;
  final String name;
  final VoidCallback onOpenOutside;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            tooltip: 'Open or download',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: onOpenOutside,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final total = progress.expectedTotalBytes;
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: total == null
                      ? null
                      : progress.cumulativeBytesLoaded / total,
                ),
              );
            },
            errorBuilder: (context, error, stack) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SWIPE TO REPLY
// ══════════════════════════════════════════════════════════════════════════════

/// Drag the child to the right: a reply arrow appears, and letting go after
/// a short pull starts a reply. The child springs back either way.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _trigger = 56.0;
  static const _maxPull = 72.0;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  )..addListener(() {
      setState(() => _dx = _from * (1 - Curves.easeOut.transform(_back.value)));
    });

  double _dx = 0;
  double _from = 0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    _back.stop();
    final next = (_dx + d.delta.dx).clamp(0.0, _maxPull).toDouble();
    if (_dx < _trigger && next >= _trigger) HapticFeedback.lightImpact();
    setState(() => _dx = next);
  }

  void _end(DragEndDetails _) {
    if (_dx >= _trigger) widget.onReply();
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _end(DragEndDetails()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_dx > 4)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dx / _trigger).clamp(0.0, 1.0).toDouble(),
                  child: const Icon(Icons.reply_rounded, color: _accent),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}