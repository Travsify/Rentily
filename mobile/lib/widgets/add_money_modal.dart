import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import 'verification_modal.dart';

class AddMoneyModal extends StatelessWidget {
  final UserProfile user;
  final Function(UserProfile)? onAccountUpdated;

  const AddMoneyModal({
    super.key,
    required this.user,
    this.onAccountUpdated,
  });

  static void show(
    BuildContext context, {
    required UserProfile user,
    Function(UserProfile)? onAccountUpdated,
  }) {
    if (user.accountNumber == null || user.accountNumber!.isEmpty) {
      VerificationModal.show(context, onSuccess: (updated) {
        if (onAccountUpdated != null) onAccountUpdated(updated);
        show(context, user: updated, onAccountUpdated: onAccountUpdated);
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => AddMoneyModal(user: user, onAccountUpdated: onAccountUpdated),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label Copied: $text',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyAllDetails(BuildContext context) {
    final bank = user.bankName ?? 'Flutterwave MFB';
    final accNum = user.accountNumber ?? '9955394366';
    final name = user.fullName.isNotEmpty ? user.fullName : 'Patrick Achua';

    final text = 'Bank: $bank\nAccount Number: $accNum\nBeneficiary: $name / Rentilly Escrow';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All Bank Account Details Copied to Clipboard!',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankName = user.bankName ?? 'Flutterwave MFB';
    final accountNumber = user.accountNumber ?? '9955394366';
    final beneficiaryName = user.fullName.isNotEmpty ? user.fullName : 'Patrick Achua';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        MediaQuery.of(context).viewInsets.bottom + 26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add Money to Wallet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Transfer funds from any Nigerian bank mobile app, internet banking, or USSD directly to your dedicated virtual account.',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),

          // Dedicated Account Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Bank Name Row
                _buildCopyItem(
                  context: context,
                  label: 'BANK NAME',
                  value: bankName,
                  icon: Icons.account_balance_outlined,
                  onCopy: () => _copyToClipboard(context, bankName, 'Bank Name'),
                ),
                const Divider(height: 18),

                // 2. Account Number Row (Highlighted)
                _buildCopyItem(
                  context: context,
                  label: 'DEDICATED ACCOUNT NUMBER',
                  value: accountNumber,
                  icon: Icons.numbers_rounded,
                  isHighlighted: true,
                  onCopy: () => _copyToClipboard(context, accountNumber, 'Account Number'),
                ),
                const Divider(height: 18),

                // 3. Beneficiary Name Row
                _buildCopyItem(
                  context: context,
                  label: 'ACCOUNT BENEFICIARY NAME',
                  value: beneficiaryName,
                  icon: Icons.person_outline_rounded,
                  onCopy: () => _copyToClipboard(context, beneficiaryName, 'Account Name'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Instant Settlement Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant Automated Credit: Transfers to this account reflect in your Living Wallet in less than 30 seconds with 0% deposit charges.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // One-Tap Copy All Details Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _copyAllDetails(context),
              icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.white),
              label: Text(
                'Copy All Bank Details',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onCopy,
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(icon, size: 15, color: isHighlighted ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isHighlighted ? 16 : 12.5,
                        fontWeight: FontWeight.bold,
                        color: isHighlighted ? AppColors.primary : AppColors.textPrimary,
                        letterSpacing: isHighlighted ? 1.0 : 0.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onCopy,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isHighlighted ? AppColors.accentOrange : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHighlighted ? AppColors.accentOrange : AppColors.borderDark,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_rounded,
                  size: 11,
                  color: isHighlighted ? Colors.white : AppColors.textPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Copy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
