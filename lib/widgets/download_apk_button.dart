// lib/widgets/download_apk_button.dart
//
// Use this on your web landing page (or anywhere on web) to let visitors
// download the APK directly from the backend, since web and backend are
// on different domains.
//
// Usage:
//   const DownloadApkButton()
//
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../models/app_version_info.dart';

class DownloadApkButton extends StatefulWidget {
  const DownloadApkButton({super.key});

  @override
  State<DownloadApkButton> createState() => _DownloadApkButtonState();
}

class _DownloadApkButtonState extends State<DownloadApkButton> {
  static const Color _primary = Color(0xFF1565C0);

  AppVersionInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await UpdateService.fetchLatestVersion();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load download info');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_info?.apkUrl == null) return;
    try {
      await UpdateService.launchDownload(_info!.apkUrl!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 48,
        width: 48,
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null || _info?.apkUrl == null) {
      return const SizedBox.shrink(); // no APK uploaded yet — hide silently
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _download,
          icon: const Icon(Icons.android_rounded),
          label: Text(
            _info!.latestVersion != null
                ? 'Download for Android (v${_info!.latestVersion})'
                : 'Download for Android',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        if (_info!.changelog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _info!.changelog,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}