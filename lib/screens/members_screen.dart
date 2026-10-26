// lib/screens/members_screen.dart
//
// Members of a class. Admins approve join requests, promote, mute and remove
// people. Everyone can leave; the owner can archive the class.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../services/class_socket.dart';
import '../widgets/snackBar.dart';
import '../widgets/class_layout.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);
const _green = Color(0xFF059669);

const _avatarColors = [
  Color(0xFF1E88E5),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFD97706),
  Color(0xFF059669),
  Color(0xFFDB2777),
];

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
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Action(this.icon, this.label, this.onTap, {this.danger = false});
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.room});

  final ClassRoom room;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _service = ClassService();
  final _socket = ClassSocket();

  List<ClassMember> _members = [];
  bool _loading = true;
  String? _error;
  String _myId = '';
  String? _busyId; // the member an action is running for
  StreamSubscription<ClassEvent>? _sub;

  bool get _isAdmin => widget.room.isAdmin;
  bool get _isOwner => widget.room.isOwner;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    // Someone joined, left, asked to join, or was changed: refresh quietly
    _sub = _socket.onClassEvent.listen((e) {
      if (e.classId == widget.room.id) _load(silent: true);
    });
    _loadMe();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await AuthService().getMe();
      final id = (me['_id'] ?? me['id'] ?? '').toString();
      if (mounted) setState(() => _myId = id);
    } catch (_) {
      // Only the "(You)" tag and the Leave button need this
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.members(widget.room.id);
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
        _error = null;
      });
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

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Runs one server call for a member, then refreshes the list.
  Future<void> _run(
    ClassMember m,
    Future<void> Function() call,
    String doneMessage,
  ) async {
    setState(() => _busyId = m.userId);
    try {
      await call();
      await _load(silent: true);
      if (mounted) AppSnackBar.auto(context, doneMessage);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(ClassMember m) => _run(
        m,
        () => _service.memberAction(widget.room.id, m.userId, 'approve'),
        '${m.name} was approved',
      );

  Future<void> _decline(ClassMember m) => _run(
        m,
        () => _service.removeMember(widget.room.id, m.userId),
        'Request declined',
      );

  Future<void> _removeMember(ClassMember m) async {
    final ok = await _confirm(
      'Remove ${m.name}?',
      'They will leave the class and can join again only with the class code.',
      'Remove',
    );
    if (!ok) return;
    await _run(
      m,
      () => _service.removeMember(widget.room.id, m.userId),
      '${m.name} was removed',
    );
  }

  Future<void> _leave() async {
    if (_myId.isEmpty) {
      AppSnackBar.auto(context, 'Could not find your account. Please try again.');
      return;
    }
    final ok = await _confirm(
      'Leave this class?',
      'You will stop receiving its messages. You can join again later with the class code.',
      'Leave',
    );
    if (!ok) return;

    try {
      await _service.removeMember(widget.room.id, _myId);
      if (mounted) _closeToHub();
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  Future<void> _archive() async {
    final ok = await _confirm(
      'Archive this class?',
      'It closes the class for everyone and ends any open anonymous session. This cannot be undone.',
      'Archive',
    );
    if (!ok) return;

    try {
      await _service.archive(widget.room.id);
      if (mounted) _closeToHub();
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  /// Leaves or archives: phones go back to the class list, desktop just
  /// closes this page and the sidebar drops the class.
  void _closeToHub() {
    final wide = MediaQuery.sizeOf(context).width >= kClassSplitBreakpoint;
    if (wide) {
      Navigator.of(context).pop();
      classListRefresh.value++;
    } else {
      var popped = 0;
      Navigator.of(context).popUntil((_) => popped++ >= 2);
    }
  }

  List<_Action> _actionsFor(ClassMember m) {
    if (!_isAdmin || m.isPending || m.isOwner || m.userId == _myId) {
      return const [];
    }

    final id = widget.room.id;
    final list = <_Action>[];

    if (!m.isAdmin) {
      list.add(_Action(
        Icons.shield_outlined,
        'Make admin',
        () => _run(
          m,
          () => _service.memberAction(id, m.userId, 'promote'),
          '${m.name} is now an admin',
        ),
      ));
      list.add(_Action(
        m.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
        m.muted ? 'Unmute' : 'Mute in chat',
        () => _run(
          m,
          () => _service.memberAction(id, m.userId, m.muted ? 'unmute' : 'mute'),
          m.muted ? '${m.name} was unmuted' : '${m.name} was muted',
        ),
      ));
    }

    if (m.isAdmin && _isOwner) {
      list.add(_Action(
        Icons.remove_moderator_outlined,
        'Remove admin rights',
        () => _run(
          m,
          () => _service.memberAction(id, m.userId, 'demote'),
          '${m.name} is no longer an admin',
        ),
      ));
    }

    // Only the owner can remove another admin
    if (!m.isAdmin || _isOwner) {
      list.add(_Action(
        Icons.person_remove_outlined,
        'Remove from class',
        () => _removeMember(m),
        danger: true,
      ));
    }
    return list;
  }

  void _showActions(ClassMember m) {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);
    final actions = _actionsFor(m);
    if (actions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
              ),
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context.watch<ThemeNotifier>().isDarkMode);
    final activeCount = _members.where((m) => !m.isPending).length;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _header(p, activeCount),
                Expanded(child: _content(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(_Pal p, int count) {
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
                  'Members',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: p.text,
                  ),
                ),
                Text(
                  _loading && _members.isEmpty
                      ? widget.room.name
                      : '$count ${count == 1 ? 'member' : 'members'} · ${widget.room.name}',
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

  Widget _content(_Pal p) {
    if (_loading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: p.sub),
              const SizedBox(height: 12),
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

    final pending = _members.where((m) => m.isPending).toList();
    final admins = _members.where((m) => !m.isPending && m.isAdmin).toList();
    final others = _members.where((m) => !m.isPending && !m.isAdmin).toList();

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_isAdmin && pending.isNotEmpty) ...[
            _sectionTitle(p, 'WAITING FOR APPROVAL (${pending.length})'),
            for (final m in pending) _pendingTile(p, m),
          ],
          if (admins.isNotEmpty) ...[
            _sectionTitle(p, 'ADMINS'),
            for (final m in admins) _memberTile(p, m),
          ],
          if (others.isNotEmpty) ...[
            _sectionTitle(p, 'MEMBERS'),
            for (final m in others) _memberTile(p, m),
          ],
          const SizedBox(height: 24),
          _bottomButton(p),
        ],
      ),
    );
  }

  Widget _sectionTitle(_Pal p, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
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

  Widget _avatar(ClassMember m) {
    final sum = m.userId.codeUnits.fold<int>(0, (a, b) => a + b);
    final color = _avatarColors[sum % _avatarColors.length];
    final initial = m.name.isNotEmpty ? m.name[0].toUpperCase() : 'S';

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _subtitle(ClassMember m) {
    final parts = <String>[
      if (m.level.isNotEmpty) '${m.level} Level',
      if (m.department.isNotEmpty) m.department,
    ];
    return parts.join(' · ');
  }

  Widget _tileShell(_Pal p, ClassMember m, Widget trailing) {
    final sub = _subtitle(m);
    final isMe = _myId.isNotEmpty && m.userId == _myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          _avatar(m),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '${m.name} (You)' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                    ),
                    if (m.isOwner)
                      _badge('OWNER', _blue)
                    else if (m.isAdmin)
                      _badge('ADMIN', _accent),
                    if (m.muted) _badge('MUTED', Colors.orange),
                  ],
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.sub),
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _memberTile(_Pal p, ClassMember m) {
    final busy = _busyId == m.userId;
    final hasActions = _actionsFor(m).isNotEmpty;

    Widget trailing = const SizedBox(width: 8);
    if (busy) {
      trailing = const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (hasActions) {
      trailing = IconButton(
        icon: Icon(Icons.more_horiz_rounded, color: p.sub),
        onPressed: () => _showActions(m),
      );
    }

    return GestureDetector(
      onLongPress: hasActions && !busy ? () => _showActions(m) : null,
      child: _tileShell(p, m, trailing),
    );
  }

  Widget _pendingTile(_Pal p, ClassMember m) {
    final busy = _busyId == m.userId;

    final Widget trailing = busy
        ? const Padding(
            padding: EdgeInsets.all(10),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decline',
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                onPressed: () => _decline(m),
              ),
              IconButton(
                tooltip: 'Approve',
                icon: const Icon(Icons.check_rounded, color: _green),
                onPressed: () => _approve(m),
              ),
            ],
          );

    return _tileShell(p, m, trailing);
  }

  Widget _bottomButton(_Pal p) {
    // The owner archives; everyone else leaves
    if (_isOwner) {
      return _dangerButton(
        icon: Icons.inventory_2_outlined,
        label: 'Archive class',
        onTap: _archive,
      );
    }
    if (_myId.isEmpty) return const SizedBox.shrink();
    return _dangerButton(
      icon: Icons.logout_rounded,
      label: 'Leave class',
      onTap: _leave,
    );
  }

  Widget _dangerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}