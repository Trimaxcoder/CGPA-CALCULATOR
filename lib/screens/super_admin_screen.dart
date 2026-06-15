import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';
import '../services/timetable_service.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _svc = TimetableService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.getPendingRequests();
      setState(() => _requests = list);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String status, bool isDark) async {
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          status == 'approved' ? '✅ Approve Request' : '❌ Reject Request',
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == 'approved'
                  ? 'This user will become a course rep admin for their department.'
                  : 'Please provide a reason for rejection.',
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: status == 'approved'
                    ? 'Optional note...'
                    : 'Reason for rejection...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
          ],
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
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _svc.reviewRequest(id, status, reviewNote: noteCtrl.text.trim());
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final navBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final navFg = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: navBg,
        foregroundColor: navFg,
        elevation: 0,
        centerTitle: true,
        title: Text('Admin Requests',
            style: TextStyle(color: navFg, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: navFg),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('No Pending Requests',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 8),
                      Text('All admin requests will appear here',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black45)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (_, i) {
                      final r = _requests[i];
                      final user = r['user'] as Map<String, dynamic>? ?? {};
                      final profile =
                          user['profile'] as Map<String, dynamic>? ?? {};

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.3 : 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User info
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        Colors.blue.withOpacity(0.15),
                                    child: Icon(Icons.person_rounded,
                                        color: Colors.blue.shade400),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile['name'] ??
                                              user['email'] ??
                                              'Unknown',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                        ),
                                        Text(
                                          user['email'] ?? '',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Department info
                              _infoRow(Icons.school_rounded, 'Department',
                                  r['department'] ?? '—', isDark),
                              const SizedBox(height: 6),
                              _infoRow(
                                  Icons.account_balance_outlined,
                                  'Faculty',
                                  r['faculty'] ?? '—',
                                  isDark),
                              const SizedBox(height: 6),
                              _infoRow(Icons.stairs_outlined, 'Level',
                                  '${r['level'] ?? '—'} Level', isDark),
                              const SizedBox(height: 6),
                              _infoRow(
                                  Icons.account_balance_rounded,
                                  'School',
                                  r['school'] ?? '—',
                                  isDark),
                              const SizedBox(height: 12),

                              // Reason
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                    Text(
                                      r['reason'] ?? '—',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Approve / Reject buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _review(
                                          r['_id'], 'rejected', isDark),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 16),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                            color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _review(
                                          r['_id'], 'approved', isDark),
                                      icon: const Icon(
                                          Icons.check_rounded,
                                          size: 16),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) =>
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