import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
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

  void _processDirectFunding() async {
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a minimum funding amount of ₦100', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 900));

    final newBalance = widget.user.walletBalance + amount;
    final updatedUser = widget.user.copyWith(walletBalance: newBalance);
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
                  'Wallet successfully funded with ₦${amount.toStringAsFixed(2)}! 🚀',
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
      height: MediaQuery.of(context).size.height * 0.88,
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
                    child: const Icon(Icons.add_card_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fund Living Wallet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Zero Transaction Fees • Instant Automated Credit',
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

          // Method Selector Tabs (Bank Transfer vs Instant Card/Monnify)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMethodIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMethodIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedMethodIndex == 0
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Dedicated Bank Transfer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedMethodIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMethodIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMethodIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedMethodIndex == 1
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Instant Debit Card / Monnify',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedMethodIndex == 1 ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                if (_selectedMethodIndex == 0) ...[
                  // Bank Details Container
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
                          label: 'ACCOUNT NUMBER',
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
                  const SizedBox(height: 16),

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
                      onPressed: _isProcessing ? null : _processDirectFunding,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                      label: Text(
                        'I Have Transferred (Confirm Credit)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF16A34A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Direct Debit Card / Monnify / Paystack Instant Funding
                  Text(
                    'ENTER AMOUNT TO FUND',
                    style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Amount Chips
                  Row(
                    children: [
                      _buildQuickAmountChip('1,000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountChip('2,000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountChip('5,000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountChip('10,000'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mastercard / Visa / Verve & USSD', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              Text('Secured by 256-Bit Escrow Gateway • 0% Fee', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processDirectFunding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              'Fund Wallet Now 🚀',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                    ),
                  ),
                ],
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
