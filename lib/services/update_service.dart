// lib/services/update_service.dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart'; 
import '../models/app_version_info.dart';

class UpdateService {
  static final _client = ApiClient();

  /// Backend origin WITHOUT the trailing /api — e.g.
  /// 'https://gradexbackend.onrender.com'
  /// Used for static file routes like /downloads/gradex.apk which live
  /// outside the /api prefix.
  static String get _backendOrigin {
    const apiBase = ApiConfig.baseUrl; // 'https://.../api'
    if (apiBase.endsWith('/api')) {
      return apiBase.substring(0, apiBase.length - '/api'.length);
    }
    return apiBase;
  }

  /// GET /api/app-version — public, no auth required.
  static Future<AppVersionInfo> fetchLatestVersion() async {
    final data = await _client.get('/app-version');
    return AppVersionInfo.fromMap(data);
  }

  /// Installed app's build number, e.g. 14 from version "1.4.1+14"
  static Future<int> getCurrentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Installed app's version string, e.g. "1.4.1"
  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Compares installed build number against the server's latest.
  static Future<({bool updateAvailable, AppVersionInfo info, int currentBuild})>
      checkForUpdate() async {
    final info = await fetchLatestVersion();
    final currentBuild = await getCurrentBuildNumber();

    final updateAvailable = info.latestBuildNumber > currentBuild;

    return (
      updateAvailable: updateAvailable,
      info: info,
      currentBuild: currentBuild,
    );
  }

  /// Builds the full download URL.
  /// apkUrl from the backend looks like '/downloads/gradex.apk' (relative,
  /// no /api prefix since it's served by express.static directly).
  static String buildDownloadUrl(String apkUrl) {
    if (apkUrl.startsWith('http')) return apkUrl; // already absolute
    return '$_backendOrigin$apkUrl';
  }

  /// Opens the APK download URL in the device/browser, triggering download.
  static Future<void> launchDownload(String apkUrl) async {
    final fullUrl = buildDownloadUrl(apkUrl);
    final uri = Uri.parse(fullUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open download link');
    }
  }
}