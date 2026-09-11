import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_endpoints.dart';

/// In-App Update Service
/// ─────────────────────────────────────────────────────────────────
/// Checks the backend for the latest app version and
/// shows a clean MatchUp update dialog if a newer version is available.
///
/// Features:
/// • Semantic numeric version comparison (e.g. 1.10.0 > 1.9.0)
/// • Build number fallback comparison
/// • Minimum supported version detection with mandatory force update
/// • Optional vs forced update flows (blocking dismissal when forced)
/// • Trusted official distribution URL launching
/// • Network error resilience
/// ─────────────────────────────────────────────────────────────────
class UpdateService {
  UpdateService._();

  static bool _dialogShown = false;

  /// Compares semantic versions v1 and v2 numerically.
  /// Returns:
  ///   < 0 if v1 < v2 (v1 is older)
  ///   0   if v1 == v2
  ///   > 0 if v1 > v2 (v1 is newer)
  static int compareSemVer(String v1, String v2) {
    if (v1.isEmpty && v2.isEmpty) return 0;
    if (v1.isEmpty) return -1;
    if (v2.isEmpty) return 1;

    final clean1 = v1.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final clean2 = v2.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

    final parts1 = clean1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  /// Call this at startup or login.
  /// [context] must be a mounted BuildContext.
  static Future<void> checkForUpdate(BuildContext context, {bool forceCheck = false}) async {
    if (_dialogShown && !forceCheck) return;

    try {
      // 1. Read installed version information from package_info_plus
      final info = await PackageInfo.fromPlatform();
      final installedVersion = info.version;
      final installedBuild = int.tryParse(info.buildNumber) ?? 0;

      // 2. Fetch server version info (public endpoint)
      final dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(ApiEndpoints.appVersion);

      if (response.data == null || response.data['success'] != true) return;

      final data = response.data['data'];
      if (data == null || data is! Map) return;

      final serverLatestVer = (data['latestVersion'] ?? data['version'] ?? '').toString();
      final serverMinVer = (data['minimumVersion'] ?? data['minimumSupportedVersion'] ?? '').toString();
      final serverBuild = (data['buildNumber'] as num?)?.toInt() ?? 0;
      final downloadUrl = (data['updateUrl'] ?? data['downloadUrl'] ?? '').toString();
      final serverForceUpdate = data['forceUpdate'] == true;
      final updateMsg = (data['message'] ?? data['updateMessage'] ?? 'A new version of MatchUp is available with improvements and bug fixes.').toString();

      if (downloadUrl.isEmpty) return;

      // 3. Semantic version comparison
      bool isOutdated = false;
      bool mustForce = serverForceUpdate;

      // Check against minimum supported version
      if (serverMinVer.isNotEmpty && compareSemVer(installedVersion, serverMinVer) < 0) {
        isOutdated = true;
        mustForce = true;
      }

      // Check against latest available version
      if (serverLatestVer.isNotEmpty) {
        final semVerDiff = compareSemVer(installedVersion, serverLatestVer);
        if (semVerDiff < 0) {
          isOutdated = true;
        } else if (semVerDiff == 0 && serverBuild > installedBuild) {
          // Build number fallback if semver is identical
          isOutdated = true;
        }
      } else if (serverBuild > installedBuild) {
        isOutdated = true;
      }

      if (!isOutdated) return;

      // 4. Present update dialog
      if (context.mounted) {
        _dialogShown = true;
        await _showUpdateDialog(
          context,
          serverVersion: serverLatestVer.isNotEmpty ? serverLatestVer : 'Latest',
          installedVersion: installedVersion,
          downloadUrl: downloadUrl,
          forceUpdate: mustForce,
          updateMessage: updateMsg,
        );
      }
    } on DioException catch (e) {
      debugPrint('[UpdateService] Version check network issue: ${e.message}');
    } catch (e) {
      debugPrint('[UpdateService] Version check error: $e');
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String serverVersion,
    required String installedVersion,
    required String downloadUrl,
    required bool forceUpdate,
    required String updateMessage,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded,
                  color: Color(0xFFEC407A), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  forceUpdate ? 'Update Required' : 'New Update Available',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Installed: v$installedVersion',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC407A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFEC407A).withOpacity(0.3)),
                    ),
                    child: Text(
                      'Latest: v$serverVersion',
                      style: const TextStyle(
                        color: Color(0xFFEC407A),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
            if (!forceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
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
