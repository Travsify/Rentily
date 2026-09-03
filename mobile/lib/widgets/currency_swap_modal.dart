import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/payment_security_service.dart';

class CurrencySwapModal extends StatefulWidget {
  final UserProfile user;
  final Function(double newNgnBalance, double newUsdtBalance) onSwapSuccess;

  const CurrencySwapModal({
    super.key,
    required this.user,
    required this.onSwapSuccess,
  });

  static void show(
    BuildContext context, {
    required UserProfile user,
    required Function(double newNgnBalance, double newUsdtBalance) onSwapSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CurrencySwapModal(user: user, onSwapSuccess: onSwapSuccess),
    );
  }

  @override
  State<CurrencySwapModal> createState() => _CurrencySwapModalState();
}

class _CurrencySwapModalState extends State<CurrencySwapModal> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // Swap Direction: 'USDT_TO_NGN' or 'NGN_TO_USDT'
  String _swapDirection = 'USDT_TO_NGN';

  double _buyRate = 1400.00;  // When user sells USDT -> gets NGN
  double _sellRate = 1460.00; // When user sells NGN -> gets USDT
  bool _isSwapping = false;

  double _calculatedReceiveAmount = 0.0;
  late AnimationController _flipAnimController;

  @override
  void initState() {
    super.initState();
    _flipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _amountController.addListener(_onAmountChanged);
    _fetchLiveRates();
  }

  @override
  void dispose() {
    _flipAnimController.dispose();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRates() async {
    final rates = await ApiService.fetchSpreadRates();
    if (mounted) {
      setState(() {
        _buyRate = (rates['buyRate'] as num?)?.toDouble() ?? 1400.00;
        _sellRate = (rates['sellRate'] as num?)?.toDouble() ?? 1460.00;
      });
      _recalculate();
    }
  }

  void _onAmountChanged() {
    _recalculate();
  }

  void _recalculate() {
    final input = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    setState(() {
      if (_swapDirection == 'USDT_TO_NGN') {
        _calculatedReceiveAmount = input * _buyRate;
      } else {
        _calculatedReceiveAmount = _sellRate > 0 ? (input / _sellRate) : 0.0;
      }
    });
  }

  void _toggleDirection() {
    HapticFeedback.mediumImpact();
    _flipAnimController.forward(from: 0.0);
    setState(() {
      _swapDirection = _swapDirection == 'USDT_TO_NGN' ? 'NGN_TO_USDT' : 'USDT_TO_NGN';
      _amountController.clear();
      _calculatedReceiveAmount = 0.0;
    });
  }

  void _applyPercentage(double fraction) {
    HapticFeedback.selectionClick();
    final isUsdtToNgn = _swapDirection == 'USDT_TO_NGN';
    final double maxAvailable = isUsdtToNgn
        ? widget.user.usdtBalance
        : widget.user.walletBalance;

    if (maxAvailable <= 0) {
      _amountController.text = '0';
      return;
    }

    final target = (maxAvailable * fraction);
    if (isUsdtToNgn) {
      _amountController.text = target.toStringAsFixed(2);
    } else {
      _amountController.text = target.toStringAsFixed(0);
    }
  }

  Future<void> _handleSwap() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount to swap')),
      );
      return;
    }

    final isUsdtToNgn = _swapDirection == 'USDT_TO_NGN';
    final fromCurrency = isUsdtToNgn ? 'USDT' : 'NGN';
    final toCurrency = isUsdtToNgn ? 'NGN' : 'USDT';

    // STRICT ANTI-CHEAT BALANCE GUARDS:
    if (isUsdtToNgn) {
      if (widget.user.usdtBalance <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient USDT balance. Available: \$0.00 USDT. You cannot convert USDT you do not have.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (amount > widget.user.usdtBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient USDT balance. Available: \$${widget.user.usdtBalance.toStringAsFixed(2)} USDT'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else {
      if (widget.user.walletBalance <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient Naira balance. Available: ₦0.00. You cannot swap Naira you do not have.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (amount > widget.user.walletBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient Naira balance. Available: ₦${_currencyFormat.format(widget.user.walletBalance)}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Biometric / PIN Security Check
    if (!mounted) return;
    final authSuccess = await PaymentSecurityService.authorizeTransaction(
      context,
      title: isUsdtToNgn
          ? 'Convert \$${amount.toStringAsFixed(2)} USDT to ₦${_currencyFormat.format(_calculatedReceiveAmount)}'
          : 'Swap ₦${_currencyFormat.format(amount)} to \$${_calculatedReceiveAmount.toStringAsFixed(2)} USDT',
      amount: isUsdtToNgn ? _calculatedReceiveAmount : amount,
      recipient: isUsdtToNgn ? 'Rentilly NGN Wallet' : 'Rentilly USDT Vault',
    );

    if (!authSuccess) return;

    setState(() => _isSwapping = true);

    final res = await ApiService.executeCurrencySwap(
      email: widget.user.email,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _isSwapping = false);

    if (res['success'] == true) {
      final double newNgnBal = (res['newWalletBalance'] as num?)?.toDouble() ?? widget.user.walletBalance;
      final double newUsdtBal = (res['newUsdtBalance'] as num?)?.toDouble() ?? widget.user.usdtBalance;
      widget.onSwapSuccess(newNgnBal, newUsdtBal);
      Navigator.pop(context);

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res['message'] ?? 'Swap executed successfully!',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Swap execution failed', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUsdtToNgn = _swapDirection == 'USDT_TO_NGN';
    final activeRate = isUsdtToNgn ? _buyRate : _sellRate;

    final maxBalDisplay = isUsdtToNgn
        ? '\$${widget.user.usdtBalance.toStringAsFixed(2)} USDT'
        : '₦${_currencyFormat.format(widget.user.walletBalance)}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swap & Convert',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Instant settlement at institutional exchange rates',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF16A34A)),
                      const SizedBox(width: 2),
                      Text(
                        'ZERO FEE',
                        style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (isUsdtToNgn && widget.user.usdtBalance <= 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your USDT balance is \$0.00. You cannot convert USDT you do not have. Swap NGN to USDT or deposit to your TRON address.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),

            if (!isUsdtToNgn && widget.user.walletBalance <= 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Naira balance is ₦0.00. Fund your Naira bank account before swapping to USDT.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // FROM CARD (YOU PAY)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOU PAY',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Available: $maxBalDisplay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUsdtToNgn ? const Color(0xFF0F3B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isUsdtToNgn ? const Color(0xFF00E676) : AppColors.borderDark),
                        ),
                        child: Row(
                          children: [
                            Text(
                              isUsdtToNgn ? '⚡ USDT' : '🇳🇬 NGN',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isUsdtToNgn ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Percentage Chips
                  Row(
                    children: [
                      _buildPercentChip('25%', () => _applyPercentage(0.25)),
                      const SizedBox(width: 6),
                      _buildPercentChip('50%', () => _applyPercentage(0.50)),
                      const SizedBox(width: 6),
                      _buildPercentChip('75%', () => _applyPercentage(0.75)),
                      const SizedBox(width: 6),
                      _buildPercentChip('MAX', () => _applyPercentage(1.0)),
                    ],
                  ),
                ],
              ),
            ),

            // CENTER FLIP BUTTON & RATE BADGE
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _toggleDirection,
                          child: RotationTransition(
                            turns: Tween(begin: 0.0, end: 0.5).animate(_flipAnimController),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Text(
                            '1 USDT = ₦${_currencyFormat.format(activeRate)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // TO CARD (YOU RECEIVE)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOU RECEIVE (ESTIMATED)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: !isUsdtToNgn ? const Color(0xFF0F3B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: !isUsdtToNgn ? const Color(0xFF00E676) : AppColors.borderDark),
                        ),
                        child: Text(
                          !isUsdtToNgn ? '⚡ USDT' : '🇳🇬 NGN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: !isUsdtToNgn ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isUsdtToNgn
                              ? '₦${_currencyFormat.format(_calculatedReceiveAmount)}'
                              : '\$${_calculatedReceiveAmount.toStringAsFixed(2)} USDT',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F5B46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // SPREAD & SUMMARY DETAILS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Direction',
                    isUsdtToNgn ? 'USDT (TRC20) ➔ Naira Bank' : 'Naira Bank ➔ USDT (TRC20)',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Rate Applied',
                    isUsdtToNgn ? '₦${_currencyFormat.format(_buyRate)} / USDT (Cashout)' : '₦${_currencyFormat.format(_sellRate)} / USDT (Buy)',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Conversion Fee', '₦0.00 (Zero Fee)'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Settlement', 'Instant to Wallet'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SWAP ACTION BUTTON
            Builder(
              builder: (context) {
                final hasZeroSourceBalance = isUsdtToNgn
                    ? (widget.user.usdtBalance <= 0)
                    : (widget.user.walletBalance <= 0);

                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSwapping
                        ? null
                        : (hasZeroSourceBalance
                            ? () {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isUsdtToNgn
                                          ? 'You have \$0.00 USDT. You cannot convert USDT you do not have.'
                                          : 'You have ₦0.00. Fund your Naira bank account before swapping.',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            : _handleSwap),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasZeroSourceBalance ? Colors.grey.shade400 : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSwapping
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(hasZeroSourceBalance ? Icons.lock_outline_rounded : Icons.currency_exchange_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                hasZeroSourceBalance
                                    ? (isUsdtToNgn ? 'Zero USDT Balance' : 'Zero Naira Balance')
                                    : 'Confirm & Swap Now',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentChip(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
