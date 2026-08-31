import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/biometric_service.dart';

class BiometricPromptModal extends StatelessWidget {
  const BiometricPromptModal({super.key});

  static Future<void> checkAndPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool('biometrics_prompted') ?? false;
    final isEnabled = prefs.getBool('biometrics_enabled') ?? false;

    if (alreadyAsked || isEnabled) return;

    final canAuth = await BiometricService.isBiometricsAvailable();
    if (!canAuth) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const BiometricPromptModal(),
    );
  }

  void _enableBiometrics(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_prompted', true);

    final authenticated = await BiometricService.authenticate(
      reason: 'Scan your fingerprint or face to enable biometric unlock',
    );

    if (authenticated) {
      await prefs.setBool('biometrics_enabled', true);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric unlock enabled successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric setup cancelled.', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  void _dismiss(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_prompted', true);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fingerprint_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Enable Biometric Login 🔒',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Unlock Rentilly instantly and authorize withdrawals securely using your fingerprint or Face ID.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _enableBiometrics(context),
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: Text('Enable Biometrics Now', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _dismiss(context),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
