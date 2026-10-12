import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/timetable_service.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_page.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  final _svc = TimetableService();
  late TabController _tabCtrl;

  static const Color _primary = Color(0xFF1565C0);

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _admins   = [];
  bool _loadingRequests = true;
  bool _loadingAdmins   = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // keeps the desktop segmented control in sync
    _tabCtrl.addListener(() {
      if (mounted && !_tabCtrl.indexIsChanging) setState(() {});
    });
    _loadRequests();
    _loadAdmins();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final list = await _svc.getPendingRequests();
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _loadingAdmins = true);
    try {
      final list = await _svc.getAllAdmins();
      if (mounted) setState(() => _admins = list);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingAdmins = false);
    }
  }

  void _refreshAll() {
    _loadRequests();
    _loadAdmins();
  }

  Future<void> _review(String id, String status, bool isDark) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          status == 'approved' ? '✅ Approve Request' : '❌ Reject Request',
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status == 'approved'
                    ? 'This user will become a course rep admin.'
                    : 'Provide a reason for rejection.',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style:
                    TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: status == 'approved'
                      ? 'Optional note...'
                      : 'Reason for rejection...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  status == 'approved' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _svc.reviewRequest(id, status,
          reviewNote: noteCtrl.text.trim());
      await _loadRequests();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(status == 'approved'
                ? '✅ Request approved!'
                : '❌ Request rejected.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _revoke(String userId, String name, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Revoke Admin Access?',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold)),
        content: Text(
          '$name will lose admin access immediately and will be notified.',
          style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _svc.revokeAdmin(userId);
      await _loadAdmins();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin access revoked.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    if (context.isExpanded) return _buildDesktop(isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ── Fixed gradient header ────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x331565C0),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Super Admin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        _glassIconButton(
                            icon: Icons.refresh_rounded,
                            onPressed: _refreshAll)
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Padded + label-sized indicator keeps the underline inside
                  // the curved header corners
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: TabBar(
                      controller: _tabCtrl,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(color: Colors.white, width: 3),
                        insets: EdgeInsets.symmetric(horizontal: 6),
                      ),
                      tabs: const [
                        Tab(icon: Icon(Icons.pending_actions_rounded, size: 20), text: 'Pending'),
                        Tab(icon: Icon(Icons.verified_user_rounded, size: 20), text: 'Admins'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPendingTab(isDark),
                _buildAdminsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DESKTOP: segmented switch + two-column cards
  // ══════════════════════════════════════════════════════════
  Widget _buildDesktop(bool isDark) {
    return DesktopPage(
      title: 'Super Admin',
      subtitle: 'Review admin requests and manage course reps',
      maxWidth: 1200,
      actions: [
        DeskButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          isDark: isDark,
          onTap: _refreshAll,
        ),
        _segmented(isDark),
      ],
      child: _tabCtrl.index == 0
          ? _desktopPending(isDark)
          : _desktopAdmins(isDark),
    );
  }

  Widget _segmented(bool isDark) {
    final items = [
      (Icons.pending_actions_rounded, 'Pending', _requests.length),
      (Icons.verified_user_rounded, 'Admins', _admins.length),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => setState(() => _tabCtrl.index = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _tabCtrl.index == i
                        ? const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 18,
                        color: _tabCtrl.index == i
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items[i].$2} (${items[i].$3})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _tabCtrl.index == i
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Equal-width wrapped grid (cards may have different heights).
  Widget _cardGrid(List<Widget> cards) => LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 760 ? 2 : 1;
          const gap = 16.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final c in cards) SizedBox(width: w, child: c)],
              ),
            ],
          );
        },
      );

  Widget _desktopPending(bool isDark) {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requests.isEmpty) {
      return _emptyState(Icons.inbox_rounded, 'No Pending Requests',
          'All admin requests will appear here', isDark);
    }
    return _cardGrid([
      for (final r in _requests)
        _requestCard(
          r,
          r['user'] as Map<String, dynamic>? ?? {},
          (r['user'] as Map<String, dynamic>? ?? {})['profile']
                  as Map<String, dynamic>? ??
              {},
          isDark,
          desktop: true,
        ),
    ]);
  }

  Widget _desktopAdmins(bool isDark) {
    if (_loadingAdmins) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_admins.isEmpty) {
      return _emptyState(Icons.verified_user_outlined, 'No Admins Yet',
          'Approved admins will appear here', isDark);
    }
    return _cardGrid([
      for (final a in _admins)
        _adminCardDesktop(
            a, a['profile'] as Map<String, dynamic>? ?? {}, isDark),
    ]);
  }

  // Admin card without ListTile, with a labeled revoke button
  Widget _adminCardDesktop(Map admin, Map profile, bool isDark) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF15181D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.green.withOpacity(0.15),
              child: Icon(Icons.verified_user_rounded,
                  color: Colors.green.shade400),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['name'] ?? admin['email'] ?? 'Unknown',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(admin['email'] ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 2),
                  Text(
                    '${profile['department'] ?? '—'} • ${profile['level'] ?? '—'} Level',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _revoke(
                admin['_id'],
                profile['name'] ?? admin['email'] ?? 'This user',
                isDark,
              ),
              icon: const Icon(Icons.person_remove_rounded, size: 18),
              label: const Text('Revoke'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );

  // ── Pending Requests Tab (phone) ─────────────────────────────────────────
  Widget _buildPendingTab(bool isDark) {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty)
      return _emptyState(
          Icons.inbox_rounded, 'No Pending Requests',
          'All admin requests will appear here', isDark);

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: responsiveSidePadding(
              MediaQuery.sizeOf(context).width,
              maxWidth: 720),
          vertical: 16,
        ),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final r       = _requests[i];
          final user    = r['user'] as Map<String, dynamic>? ?? {};
          final profile = user['profile'] as Map<String, dynamic>? ?? {};
          return _requestCard(r, user, profile, isDark);
        },
      ),
    );
  }

  // ── Current Admins Tab (phone) ───────────────────────────────────────────
  Widget _buildAdminsTab(bool isDark) {
    if (_loadingAdmins) return const Center(child: CircularProgressIndicator());
    if (_admins.isEmpty)
      return _emptyState(Icons.verified_user_outlined,
          'No Admins Yet', 'Approved admins will appear here', isDark);

    return RefreshIndicator(
      onRefresh: _loadAdmins,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: responsiveSidePadding(
              MediaQuery.sizeOf(context).width,
              maxWidth: 720),
          vertical: 16,
        ),
        itemCount: _admins.length,
        itemBuilder: (_, i) {
          final a       = _admins[i];
          final profile = a['profile'] as Map<String, dynamic>? ?? {};
          return _adminCard(a, profile, isDark);
        },
      ),
    );
  }

  Widget _requestCard(Map r, Map user, Map profile, bool isDark,
          {bool desktop = false}) =>
      Container(
        margin: desktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark
              ? (desktop ? const Color(0xFF15181D) : const Color(0xFF1E293B))
              : Colors.white,
          borderRadius: BorderRadius.circular(desktop ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: desktop ? 12 : 8,
              offset: Offset(0, desktop ? 3 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(desktop ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.15),
                    child: Icon(Icons.person_rounded,
                        color: Colors.blue.shade400),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile['name'] ?? user['email'] ?? 'Unknown',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
                        Text(user['email'] ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _infoRow(Icons.school_rounded, 'Department',
                  r['department'] ?? '—', isDark),
              const SizedBox(height: 6),
              _infoRow(Icons.account_balance_outlined, 'Faculty',
                  r['faculty'] ?? '—', isDark),
              const SizedBox(height: 6),
              _infoRow(Icons.stairs_outlined, 'Level',
                  '${r['level'] ?? '—'} Level', isDark),
              const SizedBox(height: 6),
              _infoRow(Icons.account_balance_rounded, 'School',
                  r['school'] ?? '—', isDark),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(r['reason'] ?? '—',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _review(r['_id'], 'rejected', isDark),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _review(r['_id'], 'approved', isDark),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _adminCard(Map admin, Map profile, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.15),
            child: Icon(Icons.verified_user_rounded,
                color: Colors.green.shade400),
          ),
          title: Text(
            profile['name'] ?? admin['email'] ?? 'Unknown',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(admin['email'] ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 2),
              Text(
                '${profile['department'] ?? '—'} • ${profile['level'] ?? '—'} Level',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.person_remove_rounded,
                color: Colors.red),
            onPressed: () => _revoke(
              admin['_id'],
              profile['name'] ?? admin['email'] ?? 'This user',
              isDark,
            ),
          ),
        ),
      );

  Widget _emptyState(
          IconData icon, String title, String subtitle, bool isDark) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 64,
                  color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.white38 : Colors.black45)),
            ],
          ),
        ),
      );

  Widget _infoRow(
          IconData icon, String label, String value, bool isDark) =>
      Row(
        children: [
          Icon(icon,
              size: 15,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45)),
          Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54)),
          ),
        ],
      );
}

Widget _glassIconButton({required IconData icon, required VoidCallback onPressed}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}