import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';

class PartnerUpgradeVaultModal extends StatefulWidget {
  final UserProfile user;
  final Function(UserProfile updatedUser)? onUpgradeSuccess;

  const PartnerUpgradeVaultModal({
    super.key,
    required this.user,
    this.onUpgradeSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    Function(UserProfile updatedUser)? onUpgradeSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: PartnerUpgradeVaultModal(
          user: user,
          onUpgradeSuccess: onUpgradeSuccess,
        ),
      ),
    );
  }

  @override
  State<PartnerUpgradeVaultModal> createState() => _PartnerUpgradeVaultModalState();
}

class _PartnerUpgradeVaultModalState extends State<PartnerUpgradeVaultModal> {
  final _formKey = GlobalKey<FormState>();
  final _bvnController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.user.bvn != null && widget.user.bvn!.isNotEmpty) {
      _bvnController.text = widget.user.bvn!;
    }
  }

  @override
  void dispose() {
    _bvnController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _handleUpgrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await VerificationService.upgradePartnerVault(
        bvn: _bvnController.text.trim(),
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final currentUser = await AuthService.getCurrentUser();
        final updatedUser = (currentUser ?? widget.user).copyWith(
          accountNumber: res['accountNumber']?.toString(),
          bankName: res['bankName']?.toString() ?? 'Wema Bank',
          bvn: _bvnController.text.trim(),
          bvnVerified: true,
          isVerified: true,
        );

        await AuthService.updateUser(updatedUser);
        widget.onUpgradeSuccess?.call(updatedUser);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgraded to Institutional Fincra Wema Vault (₦100M+ Limit)!',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF065F46),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] ?? 'Failed to upgrade limit. Please verify your Director BVN.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF047857), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Institutional Vault',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock ₦100,000,000+ limits with ₦300 flat collection fee',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comparison Matrix Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT TIER (STANDARD)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₦25,000,000 Limit',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Wema Bank Rail',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INSTITUTIONAL TIER (FINCRA)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₦100,000,000+ Limit',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                              ),
                            ),
                            Text(
                              '₦300 Flat Fee • FIN Vault',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Input: Director BVN
            Text(
              'Corporate Director BVN (11 digits)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _bvnController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: GoogleFonts.firaCode(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter 11-digit BVN',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.fingerprint_rounded, size: 20, color: Color(0xFF047857)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length != 11) {
                  return 'Please enter a valid 11-digit BVN';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Optional DOB input
            Text(
              'Date of Birth (Optional - YYYY-MM-DD)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _dobController,
              keyboardType: TextInputType.datetime,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 1985-06-20',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Bank-grade CBN 256-bit encryption. Your BVN is verified against NIBSS records solely to issue your corporate institutional vault.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Verify & Upgrade Vault 🚀',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
