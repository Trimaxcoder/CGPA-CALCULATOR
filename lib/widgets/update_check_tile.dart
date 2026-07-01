// lib/widgets/update_check_tile.dart
//
// Drop this widget into your Settings screen wherever you list options.
// It checks for an update on mount, and the tile is only tappable
// (active/highlighted) when an update is actually available.
//
// Usage:
//   const UpdateCheckTile()
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../providers/theme_notifier.dart';

class UpdateCheckTile extends StatefulWidget {
  const UpdateCheckTile({super.key});

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  static const Color _primary = Color(0xFF1565C0);

  bool _checking = true;
  bool _updateAvailable = false;
  String? _latestVersion;
  String _currentVersion = '';
  String _changelog = '';
  String? _apkUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final result = await UpdateService.checkForUpdate();
      final current = await UpdateService.getCurrentVersion();

      if (mounted) {
        setState(() {
          _updateAvailable = result.updateAvailable;
          _latestVersion   = result.info.latestVersion;
          _currentVersion  = current;
          _changelog       = result.info.changelog;
          _apkUrl          = result.info.apkUrl;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not check for updates');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showUpdateDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: _primary),
            const SizedBox(width: 8),
            Text(
              'Update Available',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version $_latestVersion is available (you have $_currentVersion).',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
            if (_changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'What\'s new',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _changelog,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _download();
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _download() async {
    if (_apkUrl == null) return;
    try {
      await UpdateService.launchDownload(_apkUrl!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    return ListTile(
      enabled: _updateAvailable && !_checking,
      leading: _checking
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.system_update_rounded,
              color: _updateAvailable
                  ? _primary
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
      title: Text(
        'Check for Update',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _updateAvailable
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.white38 : Colors.black38),
        ),
      ),
      subtitle: Text(
        _checking
            ? 'Checking…'
            : _error != null
                ? _error!
                : _updateAvailable
                    ? 'Version $_latestVersion is ready to download'
                    : 'You\'re on the latest version ($_currentVersion)',
        style: TextStyle(
          fontSize: 12,
          color: _updateAvailable
              ? _primary
              : (isDark ? Colors.white38 : Colors.black38),
        ),
      ),
      trailing: _updateAvailable && !_checking
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : (!_checking
              ? IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38),
                  onPressed: _check,
                  tooltip: 'Check again',
                )
              : null),
      onTap: _updateAvailable && !_checking
          ? () => _showUpdateDialog(isDark)
          : null,
    );
  }
}