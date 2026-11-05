// lib/screens/people_screen.dart
//
// Friends, friend requests and finding people.
//   Friends   – everyone you can message privately
//   Requests  – people who asked to be your friend, and people you asked
//   Find      – search by name or username, plus "let others find me"

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_socket.dart';
import '../services/friend_service.dart';
import '../widgets/person_sheet.dart';
import '../widgets/snackBar.dart';

const _blue = Color(0xFF1565C0);
const _accent = Color(0xFF1E88E5);

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, this.initialTab = 0});

  /// 0 = Friends, 1 = Requests, 2 = Find
  final int initialTab;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen>
    with SingleTickerProviderStateMixin {
  final _service = FriendService();
  final _socket = ClassSocket();
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
  );

  FriendsData _data = const FriendsData();
  bool _loading = true;
  String? _error;
  StreamSubscription<ClassEvent>? _sub;

  // Find tab
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  List<Person> _results = [];
  bool _searching = false;
  String? _searchError;
  String _lastQuery = '';

  bool _findable = true;
  bool _findableLoaded = false;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _sub = _socket.onClassEvent.listen((e) {
      if (e.name.startsWith('friend:')) _load(silent: true);
    });
    _load();
    _loadFindable();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _searchCtl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await _service.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
      // keep the visible search results in step (Add -> Requested, ...)
      if (_lastQuery.isNotEmpty) _search(_lastQuery, quiet: true);
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

  Future<void> _loadFindable() async {
    try {
      final v = await _service.getFindable();
      if (!mounted) return;
      setState(() {
        _findable = v;
        _findableLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _setFindable(bool v) async {
    final before = _findable;
    setState(() => _findable = v);
    try {
      await _service.setFindable(v);
      if (mounted) {
        AppSnackBar.auto(
          context,
          v ? 'Others can find you by name or username' : 'You are hidden from search',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _findable = before);
      AppSnackBar.auto(context, 'Could not save that. Try again.');
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    final q = v.trim().replaceFirst(RegExp(r'^@'), '');
    if (q.length < 2) {
      setState(() {
        _results = [];
        _lastQuery = '';
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q, {bool quiet = false}) async {
    if (!quiet) setState(() => _searching = true);
    _lastQuery = q;
    try {
      final list = await _service.search(q);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = list;
        _searching = false;
        _searchError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!quiet) _searchError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!quiet) _searchError = 'Search failed. Try again.';
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _do(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (ok != null && mounted) AppSnackBar.auto(context, ok);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong. Please try again.');
    }
    await _load(silent: true);
  }

  Future<void> _message(Person p) async {
    try {
      final ClassRoom room = await _service.openChat(p.id);
      if (!mounted) return;
      await openPrivateChat(context, room);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Could not open the chat.');
    }
  }

  Future<void> _openCard(Person p) async {
    await showPersonSheet(context, userId: p.id, name: p.name);
    if (mounted) _load(silent: true);
  }

  void _showBlocked() {
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF15181D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final text = isDark ? Colors.white : Colors.black87;
        final sub = isDark ? Colors.white54 : Colors.black45;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocked people',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: text),
                ),
                const SizedBox(height: 10),
                if (_data.blocked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text('You have not blocked anyone.', style: TextStyle(color: sub)),
                  )
                else
                  for (final p in _data.blocked)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                      trailing: TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _do(() => _service.unblock(p.id), ok: 'Unblocked ${p.name}');
                        },
                        child: const Text('Unblock'),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F8FA);
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;
    final requests = _data.incoming.length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: text),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Text(
                          'People',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: text),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: text),
                        onSelected: (v) {
                          if (v == 'blocked') _showBlocked();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'blocked', child: Text('Blocked people')),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: _blue,
                  unselectedLabelColor: sub,
                  indicatorColor: _blue,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: [
                    const Tab(text: 'Friends'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Requests'),
                          if (requests > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$requests',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Find'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _friendsTab(isDark, text, sub),
                      _requestsTab(isDark, text, sub),
                      _findTab(isDark, text, sub),
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

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _friendsTab(bool isDark, Color text, Color sub) {
    if (_loading && _data.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data.friends.isEmpty) {
      return _emptyState('cloud_off', _error!, sub, text, retry: _load);
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _data.friends.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _emptyState(
                  'people',
                  'No friends yet.\nFind a classmate and add them to start a private chat.',
                  sub,
                  text,
                  action: ('Find people', () => _tabs.animateTo(2)),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final p in _data.friends)
                  _row(
                    p,
                    text,
                    sub,
                    trailing: IconButton(
                      tooltip: 'Message',
                      icon: const Icon(Icons.chat_bubble_rounded, color: _accent),
                      onPressed: () => _message(p),
                    ),
                    onTap: () => _message(p),
                    onLongPress: () => _openCard(p),
                  ),
              ],
            ),
    );
  }

  Widget _requestsTab(bool isDark, Color text, Color sub) {
    final empty = _data.incoming.isEmpty && _data.outgoing.isEmpty;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: empty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_emptyState('mail', 'No friend requests right now.', sub, text)],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_data.incoming.isNotEmpty) _label('Asked to be your friend', sub),
                for (final p in _data.incoming)
                  _row(
                    p,
                    text,
                    sub,
                    onTap: () => _openCard(p),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decline',
                          icon: Icon(Icons.close_rounded, color: sub),
                          onPressed: () => _do(() => _service.decline(p.id)),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _do(
                            () => _service.accept(p.id),
                            ok: 'You are now friends with ${p.name}',
                          ),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ),
                if (_data.outgoing.isNotEmpty) _label('Requests you sent', sub),
                for (final p in _data.outgoing)
                  _row(
                    p,
                    text,
                    sub,
                    onTap: () => _openCard(p),
                    trailing: TextButton(
                      onPressed: () => _do(() => _service.cancelRequest(p.id)),
                      child: const Text('Cancel'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _findTab(bool isDark, Color text, Color sub) {
    final field = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final typed = _searchCtl.text.trim().replaceFirst(RegExp(r'^@'), '');

    Widget body;
    if (_searching && _results.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_searchError != null) {
      body = _emptyState('cloud_off', _searchError!, sub, text);
    } else if (typed.length < 2) {
      body = _emptyState(
        'search',
        'Search a classmate by name or username.\nStudents with a username are found by it.',
        sub,
        text,
      );
    } else if (_results.isEmpty) {
      body = _emptyState('person_search', 'Nobody found for "$typed".', sub, text);
    } else {
      body = Column(
        children: [for (final p in _results) _resultRow(p, text, sub)],
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            controller: _searchCtl,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              hintText: 'Search name or @username',
              hintStyle: TextStyle(color: sub),
              prefixIcon: Icon(Icons.search_rounded, color: sub),
              suffixIcon: _searchCtl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: sub),
                      onPressed: () {
                        _searchCtl.clear();
                        _onQueryChanged('');
                      },
                    ),
              filled: true,
              fillColor: field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_findableLoaded)
          SwitchListTile(
            value: _findable,
            onChanged: _setFindable,
            activeColor: _blue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              'Let others find me',
              style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Text(
              _findable
                  ? 'Students can search for you and send a friend request.'
                  : 'You are hidden from search. Classmates can still tap your name in a class.',
              style: TextStyle(color: sub, fontSize: 12.5),
            ),
          ),
        body,
      ],
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────

  Widget _label(String s, Color sub) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(
          s.toUpperCase(),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: sub),
        ),
      );

  Widget _emptyState(
    String icon,
    String message,
    Color sub,
    Color text, {
    VoidCallback? retry,
    (String, VoidCallback)? action,
  }) {
    final data = switch (icon) {
      'cloud_off' => Icons.cloud_off_rounded,
      'people' => Icons.people_alt_rounded,
      'mail' => Icons.mail_outline_rounded,
      'search' => Icons.search_rounded,
      _ => Icons.person_search_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 0),
      child: Column(
        children: [
          Icon(data, size: 54, color: sub),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: text.withValues(alpha: 0.75)),
          ),
          if (retry != null) TextButton(onPressed: retry, child: const Text('Try again')),
          if (action != null)
            TextButton(onPressed: action.$2, child: Text(action.$1)),
        ],
      ),
    );
  }

  Widget _row(
    Person p,
    Color text,
    Color sub, {
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            _avatar(p),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: text),
                  ),
                  if (p.detail.isNotEmpty)
                    Text(
                      p.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _avatar(Person p) {
    return Container(
      width: 46,
      height: 46,
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
        p.initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }

  Widget _resultRow(Person p, Color text, Color sub) {
    Widget trailing;
    switch (p.relation) {
      case 'friends':
        trailing = FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
          onPressed: () => _message(p),
          child: const Text('Message'),
        );
        break;
      case 'sent':
        trailing = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('Requested', style: TextStyle(fontWeight: FontWeight.w700)),
        );
        break;
      case 'received':
        trailing = FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _blue, minimumSize: const Size(0, 36)),
          onPressed: () => _do(() => _service.accept(p.id), ok: 'You are now friends with ${p.name}'),
          child: const Text('Accept'),
        );
        break;
      case 'blocked':
        trailing = TextButton(
          onPressed: () => _do(() => _service.unblock(p.id)),
          child: const Text('Unblock'),
        );
        break;
      default:
        trailing = FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _blue, minimumSize: const Size(0, 36)),
          onPressed: () => _do(() async {
            final r = await _service.sendRequest(p.id);
            if (mounted) {
              AppSnackBar.auto(
                context,
                r == 'friends' ? 'You are now friends with ${p.name}' : 'Request sent to ${p.name}',
              );
            }
          }),
          child: const Text('Add'),
        );
    }
    return _row(p, text, sub, trailing: trailing, onTap: () => _openCard(p));
  }
}