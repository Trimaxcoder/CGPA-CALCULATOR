// lib/models/app_version_info.dart

class AppVersionInfo {
  final String? latestVersion;
  final int latestBuildNumber;
  final String? apkUrl;
  final String changelog;
  final bool forceUpdate;

  const AppVersionInfo({
    this.latestVersion,
    required this.latestBuildNumber,
    this.apkUrl,
    this.changelog = '',
    this.forceUpdate = false,
  });

  factory AppVersionInfo.fromMap(Map<String, dynamic> m) => AppVersionInfo(
        latestVersion:     m['latestVersion'] as String?,
        latestBuildNumber: m['latestBuildNumber'] as int? ?? 0,
        apkUrl:            m['apkUrl'] as String?,
        changelog:         m['changelog'] as String? ?? '',
        forceUpdate:       m['forceUpdate'] as bool? ?? false,
      );
}