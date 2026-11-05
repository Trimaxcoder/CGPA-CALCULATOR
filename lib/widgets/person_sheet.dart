// lib/widgets/person_sheet.dart
//
// The small card that opens when you tap someone's name in a class chat, or
// a person in the People screen: who they are, and Add friend / Message.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_models.dart';
import '../providers/theme_notifier.dart';
import '../screens/class_screen.dart';
import '../services/api_service.dart';
import '../services/friend_service.dart';
import '../widgets/class_layout.dart';
import '../widgets/snackBar.dart';

const _blue = Color(0xFF1565C0);

/// Opens a private chat as a full page.
Future<void> openPrivateChat(BuildContext context, ClassRoom room) {
  return Navigator.of(context).push(classSlideRoute<void>(ClassScreen(room: room)));
}

/// Shows the person card. [inChat] hides the Message button (used inside
/// the private chat itself, where it would just open the same chat).
Future<void> showPersonSheet(
  BuildContext context, {
  required String userId,
  String? name,
  bool inChat = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PersonSheet(userId: userId, name: name, inChat: inChat),
  );
}

class _PersonSheet extends StatefulWidget {
  const _PersonSheet({
    required this.userId,
    required this.name,
    required this.inChat,
  });

  final String userId;
  final String? name;
  final bool inChat;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  final _service = FriendService();

  Person? _person;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.person(widget.userId);
      if (!mounted) return;
      setState(() => _person = p);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this student. Try again.');
    }
  }

  /// Runs one action, shows its error if it fails, and updates the card.
  Future<void> _run(Future<void> Function() action, {String? okMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (okMessage != null && mounted) AppSnackBar.auto(context, okMessage);
      await _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message(Person p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final room = await _service.openChat(p.id);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop(); // close the sheet
      await nav.push(classSlideRoute<void>(ClassScreen(room: room)));
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.auto(context, e.message);
    } catch (_) {
      if (mounted) AppSnackBar.auto(context, 'Could not open the chat.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String title, String body, String action, Future<void> Function() run) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _run(run);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final card = isDark ? const Color(0xFF15181D) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (_person != null)
                _content(_person!, text, sub, isDark)
              else if (_error != null)
                _errorView(text, sub)
              else
                _loading(text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(Color text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if ((widget.name ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(widget.name!, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _errorView(Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.person_off_rounded, size: 44, color: sub),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: TextStyle(color: text, fontSize: 14.5),
          ),
        ],
      ),
    );
  }

  Widget _content(Person p, Color text, Color sub, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 78,
          height: 78,
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
            p.initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          p.name,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: text),
        ),
        if (p.username.isNotEmpty && p.username != p.name) ...[
          const SizedBox(height: 2),
          Text('@${p.username}', style: TextStyle(fontSize: 14, color: sub)),
        ],
        if (p.detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(p.detail, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: sub)),
        ],
        const SizedBox(height: 22),
        ..._actions(p, isDark, text),
      ],
    );
  }

  Widget _primary(String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _busy ? null : onTap,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }

  Widget _secondary(String label, VoidCallback? onTap, Color text, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton(
        onPressed: _busy ? null : onTap,
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: color ?? text, fontSize: 14.5),
        ),
      ),
    );
  }

  List<Widget> _actions(Person p, bool isDark, Color text) {
    const gap = SizedBox(height: 6);
    switch (p.relation) {
      case 'self':
        return [
          Text('This is you', style: TextStyle(color: text.withValues(alpha: 0.6))),
        ];

      case 'friends':
        return [
          if (!widget.inChat) ...[
            _primary('Message', Icons.chat_bubble_rounded, () => _message(p)),
            gap,
          ],
          _secondary(
            'Unfriend',
            () => _confirm(
              'Unfriend ${p.name}?',
              'Your private chat will be hidden. You can become friends again later.',
              'Unfriend',
              () => _service.unfriend(p.id),
            ),
            text,
          ),
          _secondary(
            'Block',
            () => _confirm(
              'Block ${p.name}?',
              'They will not be able to find you, message you or send you requests.',
              'Block',
              () => _service.block(p.id),
            ),
            text,
            color: Colors.red,
          ),
        ];

      case 'sent':
        return [
          _primary('Request sent', Icons.check_rounded, null),
          gap,
          _secondary('Cancel request', () => _run(() => _service.cancelRequest(p.id)), text),
        ];

      case 'received':
        return [
          _primary(
            'Accept request',
            Icons.person_add_alt_1_rounded,
            () => _run(() => _service.accept(p.id), okMessage: 'You are now friends'),
          ),
          gap,
          _secondary('Decline', () => _run(() => _service.decline(p.id)), text),
          _secondary(
            'Block',
            () => _confirm(
              'Block ${p.name}?',
              'They will not be able to find you, message you or send you requests.',
              'Block',
              () => _service.block(p.id),
            ),
            text,
            color: Colors.red,
          ),
        ];

      case 'blocked':
        return [
          _primary('Unblock', Icons.lock_open_rounded, () => _run(() => _service.unblock(p.id))),
        ];

      default: // none
        return [
          _primary(
            'Add friend',
            Icons.person_add_alt_1_rounded,
            () => _run(() async {
              final r = await _service.sendRequest(p.id);
              if (r == 'friends' && mounted) AppSnackBar.auto(context, 'You are now friends');
            }, okMessage: null),
          ),
          gap,
          _secondary(
            'Block',
            () => _confirm(
              'Block ${p.name}?',
              'They will not be able to find you, message you or send you requests.',
              'Block',
              () => _service.block(p.id),
            ),
            text,
            color: Colors.red,
          ),
        ];
    }
  }
}