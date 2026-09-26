import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../services/api_service.dart';

class UpdatePromptModal extends StatelessWidget {
  final FeatureFlags flags;
  final bool isForced;

  const UpdatePromptModal({
    super.key,
    required this.flags,
    required this.isForced,
  });

  /// Check whether an update is available and show the modal if so.
  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final flags = await ApiService.fetchFeatureFlags();
      final int current = AppConstants.currentVersionCode;
      final int latest = flags.latestVersionCode;
      final bool forced = flags.forceUpdate || current < flags.minRequiredVersionCode;

      if (current < latest && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: !forced,
          builder: (dialogCtx) => PopScope(
            canPop: !forced,
            child: UpdatePromptModal(flags: flags, isForced: forced),
          ),
        );
      }
    } catch (e) {
      debugPrint('[UpdatePromptModal] Check error: $e');
    }
  }

  Future<void> _launchUpdateUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlString')),
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdatePromptModal] Launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Badge
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title
            Text(
              flags.updateTitle.isNotEmpty ? flags.updateTitle : '⚡ Rentilly Update Available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Version tags
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Installed: v${AppConstants.currentVersionName} (${AppConstants.currentVersionCode})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Latest: v${flags.latestVersionName} (${flags.latestVersionCode})',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release description
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                flags.updateMessage.isNotEmpty
                    ? flags.updateMessage
                    : 'A new version of Rentilly is available with new Utility Bills (Electricity, Airtime VTU, Cable TV), Co-Living flatmate search, and security fixes.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),

            // Primary CTA: Direct APK Download
            ElevatedButton(
              onPressed: () {
                _launchUpdateUrl(context, flags.apkDownloadUrl.isNotEmpty ? flags.apkDownloadUrl : AppConstants.defaultApkUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Instant Update (Direct APK)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Secondary CTA: Google Play Store
            OutlinedButton(
              onPressed: () {
                _launchUpdateUrl(context, flags.playStoreUrl.isNotEmpty ? flags.playStoreUrl : AppConstants.defaultPlayStoreUrl);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderDark),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shop_two_rounded, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Google Play Store',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // If not forced, show "Later" button
            if (!isForced) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Remind Me Later',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
