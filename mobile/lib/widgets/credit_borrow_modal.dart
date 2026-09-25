import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/credit_loan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class CreditBorrowModal extends StatefulWidget {
  final UserProfile user;
  final double totalSavingsBalance;
  final VoidCallback onCreditDisbursed;

  const CreditBorrowModal({
    super.key,
    required this.user,
    required this.totalSavingsBalance,
    required this.onCreditDisbursed,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    required double totalSavingsBalance,
    required VoidCallback onCreditDisbursed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => CreditBorrowModal(
        user: user,
        totalSavingsBalance: totalSavingsBalance,
        onCreditDisbursed: onCreditDisbursed,
      ),
    );
  }

  @override
  State<CreditBorrowModal> createState() => _CreditBorrowModalState();
}

class _CreditBorrowModalState extends State<CreditBorrowModal> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');
  final TextEditingController _amountController = TextEditingController();

  double _borrowAmount = 0;
  int _selectedTenureDays = 30; // 30, 60, or 90 days
  bool _isLoading = false;
  bool _isEligible = false;
  String? _eligibilityReason;
  CreditEligibility? _eligibilityData;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchCreditEligibility(
      userId: widget.user.id,
      email: widget.user.email,
      savingsBalance: widget.totalSavingsBalance,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _eligibilityData = data;
        _isEligible = data?.isEligible ?? (widget.totalSavingsBalance >= 20000);
        _eligibilityReason = data?.reason;

        // Default borrow amount to 50% of maximum allowed
        final maxAllowed = (widget.totalSavingsBalance * 0.80);
        if (_isEligible && maxAllowed >= 5000) {
          _borrowAmount = (maxAllowed * 0.50).roundToDouble();
          _amountController.text = _currencyFormat.format(_borrowAmount);
        }
      });
    }
  }

  double get _maxBorrowable => widget.totalSavingsBalance * 0.80;

  double get _interestRate {
    // 2.5% monthly flat rate: 30d = 2.5%, 60d = 5.0%, 90d = 7.5%
    return (_selectedTenureDays / 30) * 0.025;
  }

  double get _interestAmount => (_borrowAmount * _interestRate).roundToDouble();
  double get _totalRepaymentDue => _borrowAmount + _interestAmount;
  double get _requiredCollateral => (_borrowAmount / 0.80).roundToDouble();

  DateTime get _dueDate => DateTime.now().add(Duration(days: _selectedTenureDays));

  void _onSliderChanged(double value) {
    setState(() {
      _borrowAmount = (value / 1000).round() * 1000.0;
      _amountController.text = _currencyFormat.format(_borrowAmount);
    });
  }

  void _onAmountTextChanged(String text) {
    final raw = double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
    if (raw <= _maxBorrowable) {
      setState(() {
        _borrowAmount = raw;
      });
    }
  }

  Future<void> _handleApply() async {
    if (_borrowAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a valid borrow amount.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_borrowAmount > _maxBorrowable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount exceeds your 80% limit of ₦${_currencyFormat.format(_maxBorrowable)}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.applyForCredit(
      userId: widget.user.id,
      email: widget.user.email,
      amount: _borrowAmount,
      tenureDays: _selectedTenureDays,
      savingsBalance: widget.totalSavingsBalance,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == true || res['success'] == true) {
      Navigator.of(context).pop();
      widget.onCreditDisbursed();

      NotificationService.addNotification(
        title: '₦${_currencyFormat.format(_borrowAmount)} Credit Disbursed! 🚀',
        message: 'Your 80% savings-backed advance is credited to your Rentilly Wallet. Due on ${DateFormat('dd MMM yyyy').format(_dueDate)}.',
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
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Credit Advance Credited! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '₦${_currencyFormat.format(_borrowAmount)} has been credited instantly to your Rentilly Wallet. You can transfer, spend, or withdraw freely.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Repayment Due', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    Text('₦${_currencyFormat.format(_totalRepaymentDue)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
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
        SnackBar(content: Text(res['error'] ?? res['message'] ?? 'Failed to apply for credit advance.'), backgroundColor: AppColors.error),
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
                        child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Savings-Backed Credit Advance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Borrow up to 80% of savings @ 2.5%/mo',
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

            // Qualification & Limit Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F392B), Color(0xFF0A261D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AVAILABLE SAVINGS', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text('₦${_currencyFormat.format(widget.totalSavingsBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('MAX BORROWABLE (80%)', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF86EFAC), letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text('₦${_currencyFormat.format(_maxBorrowable)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_isEligible) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _eligibilityReason ?? 'You need at least ₦20,000 locked in savings to unlock instant credit advances.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF991B1B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Amount Slider & Input
              Text('HOW MUCH WOULD YOU LIKE TO BORROW?', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 8),

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
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                        ),
                        onChanged: _onAmountTextChanged,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _borrowAmount = _maxBorrowable;
                          _amountController.text = _currencyFormat.format(_maxBorrowable);
                        });
                      },
                      child: Text('MAX (80%)', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _borrowAmount.clamp(0.0, _maxBorrowable > 0 ? _maxBorrowable : 1.0),
                  min: 0.0,
                  max: _maxBorrowable > 0 ? _maxBorrowable : 1.0,
                  onChanged: _onSliderChanged,
                ),
              ),
              const SizedBox(height: 12),

              // Tenure Selector (30, 60, 90 Days)
              Text('SELECT TENURE (MONTHLY INTEREST: 2.5%)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildTenureChip(30, '30 Days', '2.5% Flat'),
                  const SizedBox(width: 8),
                  _buildTenureChip(60, '60 Days', '5.0% Flat'),
                  const SizedBox(width: 8),
                  _buildTenureChip(90, '90 Days', '7.5% Flat'),
                ],
              ),
              const SizedBox(height: 16),

              // Live Loan Calculation Breakdown Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    _buildCalcRow('Borrowed Principal', '₦${_currencyFormat.format(_borrowAmount)}', isBold: true),
                    const SizedBox(height: 8),
                    _buildCalcRow('Interest Rate (${_selectedTenureDays} days)', '${(_interestRate * 100).toStringAsFixed(1)}% (2.5%/mo)'),
                    const SizedBox(height: 8),
                    _buildCalcRow('Interest Amount', '₦${_currencyFormat.format(_interestAmount)}'),
                    const SizedBox(height: 8),
                    _buildCalcRow('Required Savings Collateral (125%)', '₦${_currencyFormat.format(_requiredCollateral)}'),
                    const SizedBox(height: 8),
                    _buildCalcRow('Due Date', DateFormat('dd MMMM yyyy').format(_dueDate)),
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    _buildCalcRow(
                      'Total Repayment Due',
                      '₦${_currencyFormat.format(_totalRepaymentDue)}',
                      isBold: true,
                      highlightColor: AppColors.primary,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Feature Security & Yield Guarantee Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your locked savings continues earning 2.5% p.a. yield uninterrupted! Repay anytime from your Rentilly Wallet to release collateral.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF065F46), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || _borrowAmount <= 0 ? null : _handleApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Disburse ₦${_currencyFormat.format(_borrowAmount)} to Wallet ⚡',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTenureChip(int days, String title, String rate) {
    final isSelected = _selectedTenureDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTenureDays = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderDark,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rate,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool isBold = false, Color? highlightColor, double fontSize = 11.5}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: highlightColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
