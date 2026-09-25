import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/credit_loan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class CreditRepayModal extends StatefulWidget {
  final UserProfile user;
  final CreditLoan loan;
  final VoidCallback onRepaid;

  const CreditRepayModal({
    super.key,
    required this.user,
    required this.loan,
    required this.onRepaid,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    required CreditLoan loan,
    required VoidCallback onRepaid,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => CreditRepayModal(
        user: user,
        loan: loan,
        onRepaid: onRepaid,
      ),
    );
  }

  @override
  State<CreditRepayModal> createState() => _CreditRepayModalState();
}

class _CreditRepayModalState extends State<CreditRepayModal> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  final TextEditingController _amountController = TextEditingController();

  double _repayAmount = 0;
  bool _isFullRepayment = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repayAmount = widget.loan.outstandingBalance;
    _amountController.text = _currencyFormat.format(_repayAmount);
  }

  bool get _hasSufficientBalance => widget.user.walletBalance >= _repayAmount;
  double get _shortfall => _repayAmount - widget.user.walletBalance;

  void _onAmountChanged(String text) {
    final raw = double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
    setState(() {
      _repayAmount = raw.clamp(0.0, widget.loan.outstandingBalance);
      _isFullRepayment = (_repayAmount == widget.loan.outstandingBalance);
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleRepayment() async {
    if (_repayAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid repayment amount.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_hasSufficientBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance. Please transfer ₦${_currencyFormat.format(_shortfall)} to your Rentilly Virtual Account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.repayCreditLoan(
      userId: widget.user.id,
      email: widget.user.email,
      loanId: widget.loan.id,
      amount: _repayAmount,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == true || res['success'] == true) {
      Navigator.of(context).pop();
      widget.onRepaid();

      final released = res['collateralReleased'] ?? 0;
      final isFull = (res['remainingBalance'] ?? 0) <= 0;

      NotificationService.addNotification(
        title: isFull ? '🎉 Credit Advance Fully Settled!' : 'Credit Repayment Received 💳',
        message: isFull
          ? 'Your loan has been fully settled and ₦${_currencyFormat.format(released)} in savings collateral is unlocked.'
          : '₦${_currencyFormat.format(_repayAmount)} repaid. Remaining: ₦${_currencyFormat.format(res['remainingBalance'] ?? 0)}.',
        category: 'credit',
      );

      // Show Success Dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                isFull ? 'Loan Fully Settled! 🚀' : 'Payment Successful! 💳',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                isFull
                    ? 'Your loan is completely settled. ₦${_currencyFormat.format(widget.loan.collateralLocked)} in locked savings collateral has been released back to your vault!'
                    : '₦${_currencyFormat.format(_repayAmount)} has been deducted from your wallet. Remaining balance: ₦${_currencyFormat.format(res['remainingBalance'] ?? 0)}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Done', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? res['message'] ?? 'Failed to process repayment.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repay Credit Advance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Wallet balance deduction only (No card rails)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active Loan Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('OUTSTANDING BALANCE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.loan.isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.loan.isOverdue ? 'OVERDUE' : '${widget.loan.daysRemaining} DAYS LEFT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: widget.loan.isOverdue ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₦${_currencyFormat.format(widget.loan.outstandingBalance)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Due: ${DateFormat('dd MMM yyyy').format(widget.loan.dueDate)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRINCIPAL', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(widget.loan.principalAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('INTEREST', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(widget.loan.interestAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('LOCKED', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            const SizedBox(height: 2),
                            Text('₦${_currencyFormat.format(widget.loan.collateralLocked)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Repayment Amount Mode Selection
            Text('REPAYMENT OPTION', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFullRepayment = true;
                        _repayAmount = widget.loan.outstandingBalance;
                        _amountController.text = _currencyFormat.format(_repayAmount);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isFullRepayment ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isFullRepayment ? AppColors.primary : AppColors.borderDark, width: _isFullRepayment ? 1.8 : 1.0),
                      ),
                      child: Center(
                        child: Text(
                          'Full Settlement (100%)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _isFullRepayment ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFullRepayment = false;
                        _repayAmount = (widget.loan.outstandingBalance / 2).roundToDouble();
                        _amountController.text = _currencyFormat.format(_repayAmount);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isFullRepayment ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: !_isFullRepayment ? AppColors.primary : AppColors.borderDark, width: !_isFullRepayment ? 1.8 : 1.0),
                      ),
                      child: Center(
                        child: Text(
                          'Custom Amount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: !_isFullRepayment ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Text('₦', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      enabled: !_isFullRepayment,
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      decoration: const InputDecoration(border: InputBorder.none),
                      onChanged: _onAmountChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Wallet Balance Status Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasSufficientBalance ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _hasSufficientBalance ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _hasSufficientBalance ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _hasSufficientBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rentilly Wallet Balance:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₦${_currencyFormat.format(widget.user.walletBalance)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _hasSufficientBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // If Insufficient Wallet Balance -> Show Dedicated Virtual Account Transfer Box
            if (!_hasSufficientBalance) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Card repayments disabled. Fund via Bank Transfer:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bank Name', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(widget.user.bankName ?? 'Wema Bank / Rentilly MFB', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Account Number', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Row(
                                children: [
                                  Text(widget.user.accountNumber ?? '0123456789', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _copyToClipboard(widget.user.accountNumber ?? '0123456789', 'Account number'),
                                    child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Account Name', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(widget.user.fullName, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transfer ₦${_currencyFormat.format(_shortfall)} to the account above. Your wallet balance will credit immediately, then tap Repay.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF92400E), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Repay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || !_hasSufficientBalance || _repayAmount <= 0 ? null : _handleRepayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _hasSufficientBalance
                            ? 'Repay ₦${_currencyFormat.format(_repayAmount)} from Wallet 🔒'
                            : 'Fund Wallet to Repay (Shortfall: ₦${_currencyFormat.format(_shortfall)})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
