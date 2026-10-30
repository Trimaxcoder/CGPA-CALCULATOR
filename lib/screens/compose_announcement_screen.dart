// lib/screens/compose_announcement_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/announcement_service.dart';
import '../stores/announcement_store.dart';
import '../utils/responsive.dart';
import '../widgets/app_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/page_header.dart';
import '../widgets/snackBar.dart';
import 'manage_announcements_screen.dart';

class ComposeAnnouncementScreen extends StatefulWidget {
  const ComposeAnnouncementScreen({super.key});

  @override
  State<ComposeAnnouncementScreen> createState() =>
      _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState extends State<ComposeAnnouncementScreen> {
  static const Color _primary = Color(0xFF1565C0);
  static const int _titleMax = 120;
  static const int _messageMax = 2000;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  PostingRights? _rights;
  bool _loadingRights = true;
  String? _rightsError;

  /// 'class' (rep → own class) or 'global' (super admin → everyone)
  String _scope = 'class';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadRights();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadRights() async {
    setState(() {
      _loadingRights = true;
      _rightsError = null;
    });
    try {
      final rights = await AnnouncementService.fetchPostingRights();
      if (!mounted) return;
      setState(() {
        _rights = rights;
        _scope = rights.canPostClass ? 'class' : 'global';
      });
    } catch (e) {
      if (mounted) setState(() => _rightsError = _clean(e));
    } finally {
      if (mounted) setState(() => _loadingRights = false);
    }
  }

  bool get _isGlobal => _scope == 'global';

  String get _audienceLabel =>
      _isGlobal ? 'Everyone' : '${_rights?.level ?? ''} Level';

  String get _subtitle =>
      _isGlobal ? 'Send an update to everyone' : 'Send an update to your class';

  Future<void> _send() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;

    // Going to every student in the app deserves a second look.
    if (_isGlobal) {
      final ok = await showConfirmDialog(
        context,
        title: 'Send to everyone?',
        message:
            'Every student in the app will be notified straight away. You can delete it afterwards, but the notification can\'t be unsent.',
        confirmLabel: 'Send',
        icon: Icons.campaign_rounded,
        color: _primary,
      );
      if (!ok) return;
    }

    setState(() => _sending = true);
    try {
      final result = await AnnouncementService.postAnnouncement(
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        scope: _scope,
      );

      await AnnouncementStore().refresh();

      if (mounted) {
        final n = result.notifiedCount;
        AppSnackBar.auto(
          context,
          '✅ Sent! $n student${n == 1 ? '' : 's'} notified.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.auto(context, 'Error: ${_clean(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openManage() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageAnnouncementsScreen()),
      );

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final r = _rights;

    final Widget body;
    if (_loadingRights) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_rightsError != null) {
      body = _stateMessage(
        isDark,
        icon: Icons.wifi_off_rounded,
        title: 'Could not load your permissions',
        subtitle: _rightsError!,
        actionLabel: 'Retry',
        onAction: _loadRights,
      );
    } else if (r == null || !r.canPost) {
      body = _stateMessage(
        isDark,
        icon: Icons.lock_outline_rounded,
        title: 'You can\'t post announcements',
        subtitle: (r?.isAdmin ?? false)
            ? 'Your course rep class isn\'t set yet. Please contact the super admin.'
            : 'Only course reps and the super admin can post announcements.',
      );
    } else {
      body = context.isExpanded ? _desktopBody(isDark) : _mobileBody(isDark);
    }

    return _shell(isDark, body);
  }

  /// Page chrome: desktop page or phone/tablet scaffold.
  Widget _shell(bool isDark, Widget child) {
    if (context.isExpanded) {
      return DesktopPage(
        title: 'New Announcement',
        subtitle: _subtitle,
        maxWidth: 1200,
        actions: [
          DeskButton(
            icon: Icons.list_alt_rounded,
            label: 'My announcements',
            isDark: isDark,
            onTap: _openManage,
          ),
        ],
        child: child,
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          MobileHeader(
            title: 'New announcement',
            subtitle: _subtitle,
            actions: [
              HeaderTile(
                icon: Icons.list_alt_rounded,
                tooltip: 'My announcements',
                onTap: _openManage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PHONE / TABLET
  // ══════════════════════════════════════════════════════════
  Widget _mobileBody(bool isDark) {
    final side = responsiveSidePadding(
      MediaQuery.sizeOf(context).width,
      maxWidth: 640,
    );

    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          side,
          20,
          side,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          Text(
            'Send to',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          _targetSection(isDark),
          const SizedBox(height: 24),
          ..._fields(isDark, messageLines: 8),
          const SizedBox(height: 28),
          _sendButton(fullWidth: true),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _openManage,
              icon: const Icon(Icons.list_alt_rounded,
                  size: 18, color: _primary),
              label: const Text(
                'View / edit / delete my announcements',
                textAlign: TextAlign.center,
                style: TextStyle(color: _primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DESKTOP: form on the left, live preview on the right
  //  (stacks into one column when the area is narrow)
  // ══════════════════════════════════════════════════════════
  Widget _desktopBody(bool isDark) {
    final cardBg = isDark ? const Color(0xFF15181D) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    final shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            t.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: textSecondary,
            ),
          ),
        );

    final form = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Send to'),
            _targetSection(isDark),
            const SizedBox(height: 26),
            ..._fields(isDark, messageLines: 10),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _sendButton(fullWidth: false),
            ),
          ],
        ),
      ),
    );

    // Only the preview rebuilds while typing.
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Preview'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadow,
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_titleCtrl, _messageCtrl]),
            builder: (context, _) {
              final title = _titleCtrl.text.trim();
              final message = _messageCtrl.text.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.campaign_rounded,
                            color: _primary, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'How students will see it',
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _audienceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title.isEmpty ? 'Your title appears here' : title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: title.isEmpty
                          ? textSecondary.withOpacity(0.6)
                          : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message.isEmpty
                        ? 'Your message appears here as you type…'
                        : message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: message.isEmpty
                          ? textSecondary.withOpacity(0.6)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= 860;
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (twoCol)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: form),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: preview),
                ],
              )
            else ...[
              form,
              const SizedBox(height: 24),
              preview,
            ],
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SHARED PIECES
  // ══════════════════════════════════════════════════════════

  /// Who this announcement goes to. Reps see their own class (fixed — the
  /// server enforces it too). Only someone who can post both gets a switch.
  Widget _targetSection(bool isDark) {
    final r = _rights!;
    final both = r.canPostClass && r.canPostGlobal;

    final title = _isGlobal ? 'Everyone in the app' : r.classLabel;
    final helper = _isGlobal
        ? 'Every student will be notified.'
        : 'Only students in this class will be notified.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (both) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choice('My class', 'class'),
              _choice('General', 'global'),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primary.withOpacity(isDark ? 0.15 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _isGlobal ? Icons.public_rounded : Icons.groups_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choice(String label, String value) {
    final selected = _scope == value;
    return GestureDetector(
      onTap: () => setState(() => _scope = value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _primary : _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: _primary.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _primary,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(bool isDark, {required int messageLines}) => [
        _Field(
          controller: _titleCtrl,
          label: 'Title',
          hint: 'e.g. Exam timetable update',
          icon: Icons.title_rounded,
          isDark: isDark,
          maxLines: 1,
          maxLength: _titleMax,
          action: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: 16),
        _Field(
          controller: _messageCtrl,
          label: 'Message',
          hint: 'Write your announcement here…',
          icon: Icons.message_rounded,
          isDark: isDark,
          maxLines: messageLines,
          maxLength: _messageMax,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Message is required' : null,
        ),
      ];

  Widget _sendButton({required bool fullWidth}) {
    final button = ElevatedButton.icon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(_sending ? 'Sending…' : 'Send Announcement'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, height: 52, child: button)
        : button;
  }

  Widget _stateMessage(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 56,
                    color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ],
            ),
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final int maxLength;
  final TextInputAction? action;
  final String? Function(String?) validator;

  static const Color _primary = Color(0xFF1565C0);

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.maxLines,
    required this.maxLength,
    required this.validator,
    this.action,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        textInputAction: action,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _primary, size: 20),
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
        validator: validator,
      );
}