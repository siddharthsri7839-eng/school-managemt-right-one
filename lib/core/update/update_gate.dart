import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_providers.dart';
import '../config/app_colors.dart';

/// Invisible widget (App Distribution Phase 4) that checks the backend once
/// per app run for a newer release and shows an "Update available" dialog.
/// Totally silent on any failure — an update prompt is never worth an error.
class UpdateGate extends ConsumerStatefulWidget {
  /// App key as registered in the backend's config/app_distribution.php.
  final String appKey;

  const UpdateGate({super.key, this.appKey = 'staff'});

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  /// One check per app run — navigating around must not re-trigger it.
  static bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();

      final response = await ref.read(apiClientProvider).dio.get(
        '/app-info',
        queryParameters: {
          'app': widget.appKey,
          'platform': 'android_apk',
          'current': info.version,
        },
      );

      final data = response.data;
      if (data is! Map || data['update_available'] != true) return;

      final latest = (data['latest_version'] ?? '').toString();
      final notes = (data['release_notes'] ?? '').toString();
      final playUrl = (data['play_url'] ?? '').toString();
      final downloadUrl = (data['download_url'] ?? '').toString();
      final url = playUrl.isNotEmpty ? playUrl : downloadUrl;
      if (latest.isEmpty || url.isEmpty) return;

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => UpdateDialog(
          currentVersion: info.version,
          latestVersion: latest,
          releaseNotes: notes,
          url: url,
          viaStore: playUrl.isNotEmpty,
        ),
      );
    } catch (_) {
      // Offline, server old, endpoint missing — all fine, just no prompt.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The "Update available" dialog, themed with the (possibly branded) colors.
class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String url;
  final bool viaStore;

  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.url,
    required this.viaStore,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update_rounded,
                      color: AppColors.primary, size: 38),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Update available',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withAlpha(90)),
                  ),
                  child: Text(
                    'v$currentVersion  →  v$latestVersion',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    releaseNotes,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: Icon(
                        viaStore
                            ? Icons.shop_rounded
                            : Icons.download_rounded,
                        size: 19),
                    label: Text(
                      viaStore ? 'Update on Google Play' : 'Download update',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Later',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
