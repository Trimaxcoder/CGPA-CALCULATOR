// lib/screens/class_info_screen.dart
//
// The class info screen. Opened by tapping the class name (or the info icon)
// at the top of a chat. Shows when the class was created, who created it, the
// admins, the invite code, and the photos, files and voice notes shared in it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../services/api_service.dart';
import '../services/class_service.dart';
import '../widgets/snackBar.dart';
import 'class_settings_screen.dart';
import 'members_screen.dart';

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

String _fmtDateTime(DateTime d) => '${_fmtDate(d)} at ${_fmtTime(d)}';

/// Small square thumbnails instead of full-size photos.
String _thumb(String url) {
  const marker = '/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  return url.replaceFirst(marker, '${marker}c_fill,w_240,h_240,q_auto/');
}

class ClassInfoScreen extends StatefulWidget {
  const ClassInfoScreen({super.key, required this.room});

  final ClassRoom room;

  @override
  State<ClassInfoScreen> createState() => _ClassInfoScreenState();
}

class _ClassInfoScreenState extends State<ClassInfoScreen> {
  final _service = ClassService();

  ClassInfo? _info;
  bool _loading = true;
  String? _error;

  /// My "disappearing messages" time in seconds (0 = off)
  int _disappearAfter = 0;

  ClassRoom get _room => widget.room;

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
      final info = await _service.info(_room.id);
      if (!mounted) return;
      setState(() {
        _info = info;
        _disappearAfter = info.disappearAfter;
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
        _error = 'Could not load the class info.';
        _loading = false;
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _copy(String text, String done) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.auto(context, done);
  }

  void _shareInvite() {
    final code = _room.joinCode;
    if (code == null) return;
    final link = _room.inviteLink;
    final text = StringBuffer('Join "${_room.name}" on SchoolLife.\n')
      ..write('Class code: $code');
    if (link != null && link.isNotEmpty) text.write('\n$link');
    Share.share(text.toString());
  }

  Future<void> _openFile(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) AppSnackBar.auto(context, 'Could not open this file.');
  }

  void _viewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _disappearChoices = <(int, String)>[
    (0, 'Off'),
    (24 * 3600, '24 hours'),
    (7 * 24 * 3600, '7 days'),
    (90 * 24 * 3600, '90 days'),
  ];

  String _disappearLabel(int seconds) {
    for (final c in _disappearChoices) {
      if (c.$1 == seconds) return c.$2;
    }
    return 'Off';
  }

  Future<void> _pickDisappearing() async {
    final p = _Pal(context.read<ThemeNotifier>().isDarkMode);

    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: p.card,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Disappearing messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: p.text,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Messages older than this disappear from your chat, on all '
                    'your devices. Other members are not affected, and the '
                    'files are removed from storage once everyone has cleared '
                    'them.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: p.sub),
                  ),
                ),
                for (final c in _disappearChoices)
                  ListTile(
                    title: Text(
                      c.$2,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    trailing: c.$1 == _disappearAfter
                        ? const Icon(Icons.check_circle_rounded, color: _accent)
                        : Icon(Icons.circle_outlined, color: p.sub),
                    onTap: () => Navigator.pop(ctx, c.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (chosen == null || chosen == _disappearAfter || !mounted) return;

    try {
      final saved = await _service.setDisappearing(_room.id, chosen);
      if (!mounted) return;
      setState(() => _disappearAfter = saved);
      AppSnackBar.auto(
        context,
        saved == 0
            ? 'Disappearing messages are off'
            : 'Messages now disappear after ${_disappearLabel(saved)}',
      );
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'All messages will be removed from your chat, on all your devices. '
          'Other members keep their messages. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.clearChat(_room.id);
      if (!mounted) return;
      AppSnackBar.auto(context, 'Chat cleared');
      _load(); // the shared media counts change too
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong.');
    }
  }

  void _openMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MembersScreen(room: _room)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClassSettingsScreen(room: _room)),
    );
  }

  // ── Building blocks ────────────────────────────────────────────────────────

  Widget _card(_Pal p, {required List<Widget> children, String? label}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: p.sub,
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  /// One "icon, small label, value" line. The value wraps instead of
  /// overflowing, however long it is.
  Widget _row(_Pal p, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: p.sub),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(_Pal p) {
    final initial =
        _room.name.trim().isEmpty ? '?' : _room.name.trim()[0].toUpperCase();
    final members =
        '${_room.memberCount} ${_room.memberCount == 1 ? 'member' : 'members'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _room.name,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Class · $members',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: p.sub),
          ),
          const SizedBox(height: 2),
          Text(
            'Created ${_fmtDate(_room.createdAt)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.sub),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(_Pal p) {
    if (_room.description.trim().isEmpty) return const SizedBox.shrink();
    return _card(
      p,
      label: 'About',
      children: [
        Text(
          _room.description,
          style: TextStyle(fontSize: 14.5, height: 1.4, color: p.text),
        ),
      ],
    );
  }

  String get _roleLabel {
    if (_room.isOwner) return 'Owner and admin';
    if (_room.isAdmin) return 'Admin';
    return 'Member';
  }

  Widget _detailsCard(_Pal p) {
    final info = _info;
    return _card(
      p,
      label: 'Details',
      children: [
        _row(
          p,
          Icons.event_rounded,
          'Created',
          _fmtDateTime(info?.createdAt ?? _room.createdAt),
        ),
        if (info != null)
          _row(p, Icons.person_rounded, 'Created by', info.createdByName),
        if (info != null)
          _row(
            p,
            Icons.login_rounded,
            'You joined',
            _fmtDate(info.myJoinedAt),
          ),
        _row(p, Icons.badge_outlined, 'Your role', _roleLabel),
        _row(
          p,
          Icons.how_to_reg_outlined,
          'New members',
          _room.requireApproval ? 'Need admin approval' : 'Join instantly',
        ),
        _row(
          p,
          Icons.chat_outlined,
          'Who can send messages',
          _room.chatLocked ? 'Only admins' : 'Everyone',
        ),
        if (info != null)
          _row(
            p,
            Icons.push_pin_outlined,
            'Pinned messages',
            '${info.pinnedCount}',
          ),
        if (_room.archived)
          _row(p, Icons.archive_outlined, 'Status', 'Archived'),
      ],
    );
  }

  Widget _inviteCard(_Pal p) {
    final code = _room.joinCode;
    if (code == null) return const SizedBox.shrink();
    final link = _room.inviteLink;

    return _card(
      p,
      label: 'Invite people',
      children: [
        // FittedBox shrinks the code on very narrow screens instead of
        // letting it overflow.
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: _accent,
              ),
            ),
          ),
        ),
        if (link != null && link.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            link,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: p.sub),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(code, 'Code copied'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(
                  'Copy code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.text,
                  minimumSize: const Size(0, 46),
                  side: BorderSide(color: p.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareInvite,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(
                  'Share',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _countChip(_Pal p, IconData icon, String label, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 6),
          Text(
            '$n $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaCard(_Pal p) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();

    return _card(
      p,
      label: 'Shared media',
      children: [
        if (info.mediaTotal == 0)
          Text(
            'No photos, files or voice notes have been shared yet.',
            style: TextStyle(fontSize: 14, color: p.sub),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _countChip(p, Icons.photo_outlined, 'Photos', info.imageCount),
              _countChip(
                p,
                Icons.insert_drive_file_outlined,
                'Files',
                info.fileCount,
              ),
              _countChip(
                p,
                Icons.mic_none_rounded,
                'Voice notes',
                info.audioCount,
              ),
            ],
          ),
          if (info.recentImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: info.recentImages.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 96,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (_, i) {
                final img = info.recentImages[i];
                return GestureDetector(
                  onTap: () => _viewImage(img.url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _thumb(img.url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: p.field,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: p.sub,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          if (info.recentFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final f in info.recentFiles)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openFile(f.url),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 22,
                        color: p.sub,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        f.sizeLabel,
                        style: TextStyle(fontSize: 12, color: p.sub),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  /// A tappable line: icon, title, small text underneath, and an arrow.
  Widget _tapRow(
    _Pal p,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap, {
    bool danger = false,
    String? value,
  }) {
    final color = danger ? Colors.redAccent : _accent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: danger ? Colors.redAccent : p.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 12, color: p.sub, height: 1.25),
                  ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.sub),
          ],
        ),
      ),
    );
  }

  Widget _chatCard(_Pal p) {
    if (_info == null) return const SizedBox.shrink();

    return _card(
      p,
      label: 'Your chat',
      children: [
        _tapRow(
          p,
          Icons.timer_outlined,
          'Disappearing messages',
          'Old messages disappear from your chat',
          _pickDisappearing,
          value: _disappearLabel(_disappearAfter),
        ),
        _tapRow(
          p,
          Icons.delete_sweep_outlined,
          'Clear chat',
          'Remove all messages from your chat. Others keep theirs.',
          _confirmClear,
          danger: true,
        ),
      ],
    );
  }

  Widget _adminsCard(_Pal p) {
    final info = _info;
    if (info == null || info.admins.isEmpty) return const SizedBox.shrink();

    return _card(
      p,
      label: 'Admins',
      children: [
        for (final a in info.admins)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: Text(
                    a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.isOwner ? 'Owner' : 'Admin',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionButton(
    _Pal p,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: p.text,
            backgroundColor: p.card,
            side: BorderSide(color: p.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(_Pal p) {
    return _card(
      p,
      children: [
        Text(
          _error ?? 'Something went wrong.',
          style: TextStyle(fontSize: 14, color: p.text),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try again'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context.watch<ThemeNotifier>().isDarkMode);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: p.text),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Class info',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: p.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _hero(p),
                      _aboutCard(p),
                      _detailsCard(p),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        ),
                      if (_error != null) _errorBox(p),
                      _inviteCard(p),
                      _mediaCard(p),
                      _chatCard(p),
                      _adminsCard(p),
                      _actionButton(
                        p,
                        Icons.groups_rounded,
                        _room.isAdmin ? 'Members and requests' : 'Members',
                        _openMembers,
                      ),
                      if (_room.isAdmin)
                        _actionButton(
                          p,
                          Icons.settings_outlined,
                          'Class settings',
                          _openSettings,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}