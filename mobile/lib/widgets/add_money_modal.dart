import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'verification_modal.dart';

class AddMoneyModal extends StatefulWidget {
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
    if (!user.isVerified || user.accountNumber == null || user.accountNumber!.isEmpty) {
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

  @override
  State<AddMoneyModal> createState() => _AddMoneyModalState();
}

class _AddMoneyModalState extends State<AddMoneyModal> {
  final _amountController = TextEditingController(text: '2000');
  int _selectedMethodIndex = 0; // 0 = Bank Transfer, 1 = Debit Card / Monnify / Paystack
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
    final bank = widget.user.bankName ?? 'Flutterwave MFB';
    final accNum = widget.user.accountNumber ?? '9823481234';
    final isPartner = widget.user.role == 'partner';
    final name = isPartner
        ? (widget.user.businessName != null && widget.user.businessName!.trim().isNotEmpty
            ? widget.user.businessName!.trim()
            : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Corporate Partner'))
        : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Property Owner');

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

  void _checkForInboundTransfer() async {
    setState(() => _isProcessing = true);

    try {
      final cleanEmail = widget.user.email.toLowerCase().trim();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/wallet/balance?email=$cleanEmail');
      final res = await http.get(url).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == true && data['walletBalance'] != null) {
          final double serverBalance = (data['walletBalance'] as num).toDouble();

          if (serverBalance > widget.user.walletBalance) {
            final difference = serverBalance - widget.user.walletBalance;
            final updatedUser = widget.user.copyWith(walletBalance: serverBalance);
            await AuthService.updateUser(updatedUser);

            if (widget.onAccountUpdated != null) {
              widget.onAccountUpdated!(updatedUser);
            }

            if (mounted) {
              setState(() => _isProcessing = false);
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Transfer confirmed! +₦${difference.toStringAsFixed(2)} credited to your wallet.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No new inbound transfer detected yet. Bank transfers usually reflect within 10-60 seconds. Your wallet will update automatically once received.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankName = widget.user.bankName ?? 'Flutterwave MFB';
    final accountNumber = widget.user.accountNumber ?? '9823481234';
    final isPartner = widget.user.role == 'partner';
    final name = isPartner
        ? (widget.user.businessName != null && widget.user.businessName!.trim().isNotEmpty
            ? widget.user.businessName!.trim()
            : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Corporate Partner'))
        : (widget.user.fullName.trim().isNotEmpty ? widget.user.fullName.trim() : 'Property Owner');

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dedicated Bank Transfer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Flutterwave MFB • Zero Fees • Instant Credit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                // Bank Details Container (Clean & Contained)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCopyItem(
                        context: context,
                        label: 'BANK NAME',
                        value: bankName,
                        icon: Icons.account_balance_rounded,
                        onCopy: () => _copyToClipboard(context, bankName, 'Bank Name'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.borderDark),
                      ),
                      _buildCopyItem(
                        context: context,
                        label: 'DEDICATED ACCOUNT NUMBER',
                        value: accountNumber,
                        icon: Icons.tag_rounded,
                        isHighlighted: true,
                        onCopy: () => _copyToClipboard(context, accountNumber, 'Account Number'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.borderDark),
                      ),
                      _buildCopyItem(
                        context: context,
                        label: 'BENEFICIARY NAME',
                        value: '$name / Rentilly Escrow',
                        icon: Icons.person_rounded,
                        onCopy: () => _copyToClipboard(context, '$name / Rentilly Escrow', 'Beneficiary Name'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Automated Credit Badge
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
                          'Automated Interbank Credit: Transfers made from any Nigerian banking app reflect in your Rentilly balance immediately.',
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
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _checkForInboundTransfer,
                    icon: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                        : const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF16A34A)),
                    label: Text(
                      _isProcessing ? 'Verifying with Central Switch...' : 'I Have Sent The Transfer (Check Inflow)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountChip(String amountStr) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _amountController.text = amountStr.replaceAll(',', '');
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: const BorderSide(color: AppColors.borderDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text('₦$amountStr', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
