import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_endpoints.dart';

/// In-App Update Service
/// ─────────────────────────────────────────────────────────────────
/// Checks the production backend for the latest app version and
/// shows an update dialog if a newer build is available.
///
/// Usage (called once during app startup from main.dart):
///   await UpdateService.checkForUpdate(context);
///
/// • Uses buildNumber as the primary comparison key.
/// • API failure is silently swallowed — the app continues normally.
/// • A single-launch guard prevents duplicate dialogs.
/// ─────────────────────────────────────────────────────────────────
class UpdateService {
  UpdateService._(); // static-only class

  static bool _dialogShown = false;

  /// Call this once at startup (inside the splash screen / auth check).
  /// [context] must be a mounted BuildContext.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (_dialogShown) return; // never show twice per launch

    try {
      // 1. Read the installed build number
      final info = await PackageInfo.fromPlatform();
      final installedBuild = int.tryParse(info.buildNumber) ?? 0;

      // 2. Fetch latest version from backend (5-second timeout)
      // Use a plain Dio instance — /app/version is a public endpoint
      // that does not require authentication.
      final dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(ApiEndpoints.appVersion);

      if (response.data == null || response.data['success'] != true) return;

      final data = response.data['data'];
      if (data == null) return;

      final serverBuild  = (data['buildNumber'] as num?)?.toInt() ?? 0;
      final serverVer    = (data['version']     as String?) ?? '';
      final downloadUrl  = (data['downloadUrl'] as String?) ?? '';
      final forceUpdate  = (data['forceUpdate'] as bool?)   ?? false;
      final updateMsg    = (data['updateMessage'] as String?)
          ?? 'A new version of MatchUp is available.';

      // 3. Compare build numbers
      if (serverBuild <= installedBuild) return; // already up-to-date
      if (downloadUrl.isEmpty) return;           // nothing to download

      // 4. Show the update dialog
      if (context.mounted) {
        _dialogShown = true;
        await _showUpdateDialog(
          context,
          serverVersion: serverVer,
          downloadUrl: downloadUrl,
          forceUpdate: forceUpdate,
          updateMessage: updateMsg,
        );
      }
    } on DioException catch (e) {
      // Network / timeout errors → silently continue
      debugPrint('[UpdateService] Version check failed: ${e.message}');
    } catch (e) {
      debugPrint('[UpdateService] Unexpected error: $e');
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String serverVersion,
    required String downloadUrl,
    required bool forceUpdate,
    required String updateMessage,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // always block dismiss via tap-outside
      builder: (ctx) => WillPopScope(
        // Back-button behaviour: only dismissible for optional updates
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded,
                  color: Color(0xFFEC407A), size: 26),
              const SizedBox(width: 10),
              Text(
                forceUpdate ? 'Update Required' : 'New Update Available',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                updateMessage,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC407A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFEC407A).withOpacity(0.3)),
                ),
                child: Text(
                  'Version $serverVersion',
                  style: const TextStyle(
                    color: Color(0xFFEC407A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You must update to continue using MatchUp.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // "Later" only shown for optional (non-force) updates
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later',
                    style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton.icon(
              onPressed: () => _openDownload(downloadUrl),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Update Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC407A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[UpdateService] Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('[UpdateService] URL launch error: $e');
    }
  }
}
