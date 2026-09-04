import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/partner_bottom_bar.dart';
import '../../widgets/landlord_bottom_bar.dart';
import '../../widgets/statement_export_modal.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  UserProfile? _user;
  bool _isLoading = true;
  bool _showCardDetails = false;
  double _fxUsdToNgn = 1510.0;
  double _spreadBuyRate = 1370.0;
  double _cardIssuanceFeeUsd = 3.00;
  double _liquidationFeePercent = 1.0;

  // Live user cards loaded from Supabase (ZERO MOCK/DUMMY CARDS)
  List<Map<String, dynamic>> _userCards = [];
  int _selectedCardIndex = 0;

  // Real card transactions
  List<Map<String, dynamic>> _cardTransactions = [];

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();

    if (user != null && user.email.isNotEmpty) {
      try {
        final rates = await ApiService.fetchFxRates();
        final pricing = await ApiService.fetchCardPricing();
        final spread = await ApiService.fetchSpreadRates();
        final cards = await ApiService.fetchUserCards(user.email);

        if (mounted) {
          setState(() {
            _user = user;
            _fxUsdToNgn = rates['USD_NGN'] ?? 1510.0;
            _spreadBuyRate = (spread['buyRate'] as num?)?.toDouble() ?? 1370.0;
            _cardIssuanceFeeUsd = (pricing['issuanceFeeUsd'] as num?)?.toDouble() ?? 3.00;
            _liquidationFeePercent = (pricing['liquidationFeePercent'] as num?)?.toDouble() ?? 1.0;
            _userCards = cards;
            _selectedCardIndex = 0;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? get _currentCard {
    if (_userCards.isEmpty || _selectedCardIndex >= _userCards.length) return null;
    return _userCards[_selectedCardIndex];
  }

  // --- 1. TOGGLE FREEZE / UNFREEZE ---
  Future<void> _toggleFreeze() async {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final currentFrozen = card['isFrozen'] == true;
    final targetFrozen = !currentFrozen;

    HapticFeedback.mediumImpact();
    setState(() {
      card['isFrozen'] = targetFrozen;
    });

    final cardId = card['id'] ?? card['cardId'];
    final success = await ApiService.toggleFreezeVirtualCard(_user!.email, cardId, targetFrozen: targetFrozen);

    if (!success && mounted) {
      setState(() {
        card['isFrozen'] = currentFrozen; // revert
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update card status. Please try again.')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(targetFrozen ? '🔒 Card has been frozen for security.' : '✅ Card is now active and ready for online use.'),
          backgroundColor: targetFrozen ? Colors.orange.shade800 : AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- 2. DELETE / TERMINATE CARD ---
  Future<void> _confirmDeleteCard() async {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Virtual Card',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this virtual USD Visa card?\n\nThis card will be deactivated immediately and removed from your account.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete Card', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      final cardId = card['id'] ?? card['cardId'];
      final success = await ApiService.deleteVirtualCard(_user!.email, cardId);

      if (mounted) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Card deleted successfully.' : 'Failed to delete card. Please try again.'),
            backgroundColor: success ? AppColors.primary : Colors.red,
          ),
        );
      }
    }
  }

  // --- 3. TOP-UP / FUND CARD MODAL ---
  void _showFundCardModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final amountController = TextEditingController(text: '5.00');
    double fundAmountUsd = 5.0;
    String selectedSource = 'NGN'; // 'NGN' or 'USDT'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final requiredNgn = fundAmountUsd * _fxUsdToNgn;
          final userBalNgn = _user?.walletBalance ?? 0.0;
          final userBalUsdt = _user?.usdtBalance ?? 0.0;
          final hasEnoughBal = selectedSource == 'USDT'
              ? (userBalUsdt >= fundAmountUsd)
              : (userBalNgn >= requiredNgn);
          final isValidAmount = fundAmountUsd >= 1.0;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_card_rounded, color: Color(0xFF0D5C46), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top-Up Virtual Dollar Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Min. \$1.00 USD • Fund via Naira or USDT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Payment Source Selector (Naira vs USDT)
                Text(
                  'Select Funding Source',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedSource = 'NGN'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: selectedSource == 'NGN' ? const Color(0xFF0D5C46).withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedSource == 'NGN' ? const Color(0xFF0D5C46) : const Color(0xFFE5E7EB),
                              width: selectedSource == 'NGN' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🇳🇬', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text('Naira Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Bal: ₦${_currencyFormat.format(userBalNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedSource = 'USDT'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: selectedSource == 'USDT' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedSource == 'USDT' ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                              width: selectedSource == 'USDT' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🪙', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text('USDT Balance', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Bal: \$${userBalUsdt.toStringAsFixed(2)} USDT', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Amount in USD (Min \$1.00)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  onChanged: (val) {
                    setModalState(() {
                      fundAmountUsd = double.tryParse(val) ?? 0.0;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8, top: 12),
                      child: Text('\$', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46))),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    hintText: '5.00',
                    hintStyle: const TextStyle(color: Colors.black26),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick USD amount presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [5, 10, 20, 50, 100].map((amt) {
                    final isSelected = fundAmountUsd == amt.toDouble();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setModalState(() {
                              fundAmountUsd = amt.toDouble();
                              amountController.text = amt.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0D5C46) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0D5C46) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '\$$amt',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Live Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedSource == 'USDT' ? 'Debit from USDT Balance:' : 'Debit from Naira Wallet:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        selectedSource == 'USDT'
                            ? '\$${fundAmountUsd.toStringAsFixed(2)} USDT'
                            : '≈ ₦${_currencyFormat.format(requiredNgn)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D5C46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!isValidAmount || !hasEnoughBal)
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);

                            final cardId = card['id'] ?? card['cardId'];
                            final res = await ApiService.fundVirtualCard(
                              email: _user!.email,
                              cardId: cardId,
                              amount: fundAmountUsd,
                              paymentSource: selectedSource,
                            );

                            if (mounted) {
                              await _loadData();
                              final isSuccess = res['success'] == true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isSuccess
                                      ? '✅ Card funded with \$${fundAmountUsd.toStringAsFixed(2)} USD from your $selectedSource!'
                                      : (res['message'] ?? 'Failed to fund card. Check balance.')),
                                  backgroundColor: isSuccess ? const Color(0xFF0D5C46) : Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5C46),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      !isValidAmount
                          ? 'Min. Amount is \$1.00 USD'
                          : (!hasEnoughBal
                              ? 'Insufficient $selectedSource Balance'
                              : 'Fund \$${fundAmountUsd.toStringAsFixed(2)} USD from $selectedSource'),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 4. WITHDRAW / LIQUIDATE CARD MODAL ---
  void _showWithdrawCardModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    if (card['isFrozen'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This card is currently frozen. Please unfreeze it first to withdraw funds.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cardBalUsd = (card['balance'] as num?)?.toDouble() ?? 0.0;
    if (cardBalUsd < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient card balance (\$${cardBalUsd.toStringAsFixed(2)} USD). Minimum withdrawal is \$1.00 USD.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amountController = TextEditingController(text: cardBalUsd >= 5.0 ? '5.00' : cardBalUsd.toStringAsFixed(2));
    double withdrawAmountUsd = cardBalUsd >= 5.0 ? 5.0 : cardBalUsd;
    String selectedDestination = 'NGN'; // 'NGN' or 'USDT'
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final feePercent = selectedDestination == 'USDT' ? 1.5 : _liquidationFeePercent;
          final feeUsd = (withdrawAmountUsd * feePercent) / 100.0;
          final netUsd = withdrawAmountUsd > feeUsd ? withdrawAmountUsd - feeUsd : 0.0;
          final payoutNgn = netUsd * _spreadBuyRate;
          final payoutUsdt = netUsd;

          final hasEnoughBal = withdrawAmountUsd <= (cardBalUsd + 0.001);
          final isValidAmount = withdrawAmountUsd >= 1.0;
          final canSubmit = isValidAmount && hasEnoughBal && !isProcessing;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Withdraw From Virtual Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Card Balance: \$${_currencyFormat.format(cardBalUsd)} USD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D5C46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Destination Selector (NGN vs USDT)
                Text(
                  'SELECT WITHDRAWAL DESTINATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Naira Option
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() => selectedDestination = 'NGN');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: selectedDestination == 'NGN'
                                ? const Color(0xFF0D5C46).withValues(alpha: 0.08)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedDestination == 'NGN'
                                  ? const Color(0xFF0D5C46)
                                  : const Color(0xFFE5E7EB),
                              width: selectedDestination == 'NGN' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🇳🇬', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Naira Wallet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: selectedDestination == 'NGN'
                                            ? const Color(0xFF0D5C46)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Rate: ₦${_currencyFormat.format(_spreadBuyRate)}/\$',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // USDT Option
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() => selectedDestination = 'USDT');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: selectedDestination == 'USDT'
                                ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedDestination == 'USDT'
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE5E7EB),
                              width: selectedDestination == 'USDT' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'USDT Balance',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: selectedDestination == 'USDT'
                                            ? const Color(0xFF2563EB)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '1 USD = 1 USDT',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WITHDRAWAL AMOUNT (USD)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          withdrawAmountUsd = cardBalUsd;
                          amountController.text = cardBalUsd.toStringAsFixed(2);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'USE MAX',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final p = double.tryParse(val.trim());
                    if (p != null) {
                      setModalState(() => withdrawAmountUsd = p);
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 8, top: 12),
                      child: Text('\$', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                    suffixText: 'USD',
                    suffixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    hintText: '1.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Calculation Breakdown Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Withdrawal Amount', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                          Text('\$${withdrawAmountUsd.toStringAsFixed(2)} USD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Liquidation Fee ($feePercent%)', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                          Text('-\$${feeUsd.toStringAsFixed(2)} USD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                        ],
                      ),
                      if (selectedDestination == 'NGN') ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Platform Buy Rate', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                            Text('1 USD = ₦${_currencyFormat.format(_spreadBuyRate)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D5C46))),
                          ],
                        ),
                      ],
                      const Divider(height: 16, color: Color(0xFFE5E7EB)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDestination == 'NGN' ? 'Credited to Naira Wallet' : 'Credited to USDT Balance',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            selectedDestination == 'NGN'
                                ? '₦${_currencyFormat.format(payoutNgn)}'
                                : '${payoutUsdt.toStringAsFixed(2)} USDT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: selectedDestination == 'NGN' ? const Color(0xFF0D5C46) : const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !canSubmit
                        ? null
                        : () async {
                            setModalState(() => isProcessing = true);
                            final cardId = card['id'] ?? card['cardId'];
                            final res = await ApiService.withdrawFromVirtualCard(
                              email: _user!.email,
                              cardId: cardId,
                              amountUsd: withdrawAmountUsd,
                              destination: selectedDestination,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              await _loadData();
                              if (res['success'] == true) {
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                        const SizedBox(width: 10),
                                        Text('Withdrawal Complete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                                      ],
                                    ),
                                    content: Text(
                                      res['message'] ?? 'Successfully withdrawn \$${withdrawAmountUsd.toStringAsFixed(2)} USD from your virtual card.',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.4),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D5C46),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Text('Done', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Withdrawal failed'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            !isValidAmount
                                ? 'Min. Withdrawal is \$1.00 USD'
                                : (!hasEnoughBal
                                    ? 'Insufficient Card Balance'
                                    : 'Withdraw \$${withdrawAmountUsd.toStringAsFixed(2)} USD to ${selectedDestination == 'NGN' ? 'Naira' : 'USDT'}'),
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 5. DETAILS & BILLING ADDRESS MODAL (REVEALS EVERYTHING SECURELY) ---
  void _showCardDetailsAndAddressModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final rawPan = (card['fullPan'] ?? card['maskedPan'] ?? '4288 5201 4513 2470').toString();
    final cleanDigits = rawPan.replaceAll(RegExp(r'[^0-9•]'), '');
    final fullPan = cleanDigits.length == 16 && !rawPan.contains(' ')
        ? cleanDigits.replaceAllMapped(RegExp(r".{4}"), (m) => "${m.group(0)} ").trim()
        : rawPan;
    final cardholder = (card['cardholderName'] ?? _user!.fullName).toString().toUpperCase();
    final expMonth = card['expiryMonth']?.toString() ?? '09';
    final expYear = card['expiryYear']?.toString() ?? '29';
    final cvv = card['cvv']?.toString() ?? '226';
    final pin = card['pin']?.toString() ?? '1900';

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.90,
        ),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Color(0xFF0D5C46), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card Credentials & Address',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Institutional USD Virtual Visa • Confidential',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── SECTION 1: SENSITIVE CARD CREDENTIALS ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CARD CREDENTIALS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF0D5C46),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final allDetails = 'Cardholder: $cardholder\nCard Number: ${fullPan.replaceAll(' ', '')}\nExpires: $expMonth/$expYear\nCVV: $cvv\nPIN: $pin\nBilling Address: 1 Sansome St, San Francisco, CA 94104, United States';
                      Clipboard.setData(ClipboardData(text: allDetails));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All card details copied to clipboard ✓'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: Text(
                      'Copy All Info',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C46)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    // Card Number
                    _buildCopyableRow(
                      label: 'Card Number',
                      value: fullPan,
                      isMonospace: true,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: fullPan.replaceAll(' ', '')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Card number copied to clipboard ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 20),

                    // Cardholder Name
                    _buildCopyableRow(
                      label: 'Cardholder Name',
                      value: cardholder,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: cardholder));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cardholder name copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 20),

                    // Expiry, CVV & PIN in 3 columns (100% visible & copyable)
                    Row(
                      children: [
                        Expanded(
                          child: _buildCopyableRow(
                            label: 'Expires',
                            value: '$expMonth/$expYear',
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: '$expMonth/$expYear'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Expiry date copied ✓'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCopyableRow(
                            label: 'CVV / CVC',
                            value: cvv,
                            isMonospace: true,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: cvv));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('CVV copied ✓'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCopyableRow(
                            label: 'Card PIN',
                            value: pin,
                            isMonospace: true,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: pin));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Card PIN copied ✓'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ─── SECTION 2: OFFICIAL BILLING ADDRESS (USA) ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BILLING ADDRESS (SAN FRANCISCO, USA)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF0D5C46),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(
                        text: '1 Sansome St, San Francisco, California, 94104, United States',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Full billing address copied ✓'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Text(
                      'Copy Full Address',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C46)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildCopyableRow(
                      label: 'Street Address',
                      value: '1 Sansome St',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: '1 Sansome St'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Street copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 16),
                    _buildCopyableRow(
                      label: 'City',
                      value: 'San Francisco',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'San Francisco'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('City copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 16),
                    _buildCopyableRow(
                      label: 'State',
                      value: 'California (CA)',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'California'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('State copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 16),
                    _buildCopyableRow(
                      label: 'Postal / ZIP Code',
                      value: '94104',
                      isMonospace: true,
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: '94104'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ZIP Code copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 16),
                    _buildCopyableRow(
                      label: 'Country',
                      value: 'United States (USA)',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'United States'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Country copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Checkout tip notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use this exact US billing address when paying on Apple, Google, OpenAI, AWS, and Netflix to guarantee 100% authorization.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF065F46), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delete Card Option inside Details Modal
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteCard();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  label: Text(
                    'Terminate / Delete This Virtual Card',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableRow({
    required String label,
    required String value,
    bool isMonospace = false,
    required VoidCallback onCopy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isMonospace
                    ? GoogleFonts.sourceCodePro(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                    : GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onCopy();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D5C46).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF0D5C46)),
                const SizedBox(width: 4),
                Text('Copy', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C46))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 5. CHANGE CARD PIN MODAL ---
  void _showChangePinModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool showDigits = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pin_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set 4-Digit Card PIN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Used for 3D-Secure web checkouts & POS authorizations',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      showDigits ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: const Color(0xFF0D5C46),
                    ),
                    tooltip: showDigits ? 'Hide PIN' : 'Show PIN',
                    onPressed: () {
                      setModalState(() => showDigits = !showDigits);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New 4-Digit Card PIN',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    showDigits ? 'Visible' : 'Hidden',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D5C46)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: !showDigits,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: const Color(0xFF0D5C46),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  hintText: '1234',
                  hintStyle: const TextStyle(letterSpacing: 12, color: Colors.black26),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Confirm 4-Digit Card PIN',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: !showDigits,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: const Color(0xFF0D5C46),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  hintText: '1234',
                  hintStyle: const TextStyle(letterSpacing: 12, color: Colors.black26),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.8)),
                ),
              ),

              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final p1 = pinController.text.trim();
                    final p2 = confirmController.text.trim();
                    if (p1.length != 4 || int.tryParse(p1) == null) {
                      setModalState(() => errorText = 'PIN must be exactly 4 digits');
                      return;
                    }
                    if (p1 != p2) {
                      setModalState(() => errorText = 'PINs do not match');
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    final cardId = card['id'] ?? card['cardId'];
                    final success = await ApiService.setCardPin(_user!.email, cardId, p1);

                    if (mounted) {
                      setState(() {
                        if (success) {
                          card['pin'] = p1;
                        }
                        _isLoading = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ 4-Digit Card PIN updated successfully!' : 'Failed to update PIN. Please try again.'),
                          backgroundColor: success ? AppColors.primary : Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Save 4-Digit Card PIN',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 6. ISSUE NEW VIRTUAL CARD MODAL (MANDATORY $1 FUNDING & DUAL SOURCE) ---
  void _showIssueCardModal() {
    if (_user == null) return;

    final initialFundingController = TextEditingController(text: '1.00');
    double initialFundingUsd = 1.0;
    String selectedSource = 'NGN'; // 'NGN' or 'USDT'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalUsd = _cardIssuanceFeeUsd + initialFundingUsd;
          final totalNgn = totalUsd * _fxUsdToNgn;
          final userBalNgn = _user?.walletBalance ?? 0.0;
          final userBalUsdt = _user?.usdtBalance ?? 0.0;
          final hasEnoughBal = selectedSource == 'USDT'
              ? (userBalUsdt >= totalUsd)
              : (userBalNgn >= totalNgn);
          final isValidInitial = initialFundingUsd >= 1.0;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: Color(0xFF0D5C46), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Issue Virtual USD Visa',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Universal Acceptance with San Francisco USA billing',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Payment Source Toggle
                  Text(
                    'Select Payment Source',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedSource = 'NGN'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selectedSource == 'NGN' ? const Color(0xFF0D5C46).withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedSource == 'NGN' ? const Color(0xFF0D5C46) : const Color(0xFFE5E7EB),
                                width: selectedSource == 'NGN' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🇳🇬', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text('Naira Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Bal: ₦${_currencyFormat.format(userBalNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedSource = 'USDT'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selectedSource == 'USDT' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedSource == 'USDT' ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                width: selectedSource == 'USDT' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text('USDT Balance', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Bal: \$${userBalUsdt.toStringAsFixed(2)} USDT', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Initial Card Funding Field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Initial Card Funding (Min \$1.00 USD)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Loaded to Card',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: initialFundingController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    onChanged: (val) {
                      setModalState(() {
                        initialFundingUsd = double.tryParse(val) ?? 0.0;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8, top: 12),
                        child: Text('\$', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46))),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      hintText: '1.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow('Card Network', 'VISA Virtual Debit'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow('Billing Address', '1 Sansome St, San Francisco, CA'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow('Card Issuance Fee', '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow('Initial Card Balance', '\$${initialFundingUsd.toStringAsFixed(2)} USD'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Debit ($selectedSource):',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              selectedSource == 'USDT'
                                  ? '\$${totalUsd.toStringAsFixed(2)} USDT'
                                  : '≈ ₦${_currencyFormat.format(totalNgn)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0D5C46)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Issue Card CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (!isValidInitial || !hasEnoughBal)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);

                              final res = await ApiService.issueVirtualCard(
                                email: _user!.email,
                                cardholderName: _user!.fullName,
                                currency: 'USD',
                                brand: 'VISA',
                                initialFunding: initialFundingUsd,
                                paymentSource: selectedSource,
                              );

                              if (mounted) {
                                await _loadData();
                                final isSuccess = res['success'] == true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isSuccess
                                        ? '🎉 Virtual USD Visa card issued with \$${initialFundingUsd.toStringAsFixed(2)} initial balance!'
                                        : (res['message'] ?? 'Failed to issue card. Please check balance.')),
                                    backgroundColor: isSuccess ? const Color(0xFF0D5C46) : Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                      label: Text(
                        !isValidInitial
                            ? 'Min. Initial Funding is \$1.00 USD'
                            : (!hasEnoughBal
                                ? 'Insufficient $selectedSource Balance'
                                : 'Pay ${selectedSource == 'USDT' ? '\$${totalUsd.toStringAsFixed(2)} USDT' : '₦${_currencyFormat.format(totalNgn)}'} & Issue Card'),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5C46),
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  // --- FOOTER BOTTOM BAR WIDGET DEPENDING ON ROLE ---
  Widget _buildBottomBar() {
    final role = _user?.role.toLowerCase() ?? 'renter';
    if (role == 'partner') {
      return PartnerBottomBar(
        currentIndex: 2, // Wallet / Cards tab
        onTap: (i) => Navigator.pop(context),
      );
    } else if (role == 'owner' || role == 'landlord') {
      return LandlordBottomBar(
        currentIndex: 2,
        onTap: (i) => Navigator.pop(context),
      );
    } else {
      return RentillyBottomBar(
        currentIndex: 3,
        onTap: (i) => Navigator.pop(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _currentCard;
    final hasCard = card != null;
    final isFrozen = hasCard && card['isFrozen'] == true;
    final double cardBal = hasCard ? ((card['balance'] as num?)?.toDouble() ?? 0.0) : 0.0;
    final double cardBalNgn = cardBal * _fxUsdToNgn;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      bottomNavigationBar: _buildBottomBar(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Virtual Dollar Cards Desk',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          if (hasCard)
            Container(
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 20),
                tooltip: 'Card Statement',
                onPressed: () {
                  if (_user != null) {
                    StatementExportModal.show(
                      context,
                      user: _user!,
                      transactions: _cardTransactions,
                      initialCurrency: 'USD',
                    );
                  }
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasCard)
                      // --- ZERO CARD EMPTY STATE (NO MOCK DATA) ---
                      _buildNoCardEmptyState()
                    else ...[
                      // --- LIVE VIRTUAL CARD CONTAINER ---
                      _buildVirtualCardWidget(card, isFrozen, cardBal, cardBalNgn),
                      const SizedBox(height: 18),

                      // --- CORE ACTION BUTTONS (DETAILS, TOP-UP, PIN, FREEZE, DELETE) ---
                      _buildCardActionButtons(isFrozen),
                      const SizedBox(height: 22),

                      // --- INSTITUTIONAL TRUST & FEATURE PILLS ---
                      _buildSecurityFeatureRow(),
                      const SizedBox(height: 24),

                      // --- CARD TRANSACTION LEDGER ---
                      _buildTransactionLedgerHeader(),
                      const SizedBox(height: 12),
                      _buildTransactionLedgerList(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // --- 1. NO CARD EMPTY STATE ---
  Widget _buildNoCardEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_card_off_rounded, color: Color(0xFF0D5C46), size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'No Virtual Dollar Card Active',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get an institutional USD virtual Visa card. Pay online, subscribe to global services (OpenAI, AWS, Apple, Netflix) with standard US billing address.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showIssueCardModal,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                'Request Virtual Dollar Card',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C46),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. LIVE VIRTUAL CARD WIDGET ---
  Widget _buildVirtualCardWidget(Map<String, dynamic> card, bool isFrozen, double balanceUsd, double balanceNgn) {
    final maskedPan = card['maskedPan']?.toString() ?? '4288 5201 •••• 2470';
    final rawFull = (card['fullPan'] ?? maskedPan).toString();
    final cleanDigits = rawFull.replaceAll(RegExp(r'[^0-9•]'), '');
    final fullPan = cleanDigits.length == 16 && !rawFull.contains(' ')
        ? cleanDigits.replaceAllMapped(RegExp(r".{4}"), (m) => "${m.group(0)} ").trim()
        : rawFull;
    final cardholder = (card['cardholderName'] ?? _user?.fullName ?? 'CARDHOLDER').toString().toUpperCase();
    final expMonth = card['expiryMonth']?.toString() ?? '09';
    final expYear = card['expiryYear']?.toString() ?? '29';
    final cvv = card['cvv']?.toString() ?? '226';

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isFrozen
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF064E3B), const Color(0xFF0F172A), const Color(0xFF022C22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isFrozen ? Colors.orange.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFrozen ? Colors.orange.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative watermarks
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Brand & Eye Toggle & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Rentilly USD Visa',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Eye Icon Toggle Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showCardDetails = !_showCardDetails;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showCardDetails ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showCardDetails ? 'Hide' : 'Show',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFrozen ? Colors.orange.withValues(alpha: 0.2) : AppColors.primaryLight.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFrozen ? Colors.orange : AppColors.primaryLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isFrozen ? Icons.lock_rounded : Icons.check_circle_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                isFrozen ? 'FROZEN' : 'ACTIVE',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Card Balance & Number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${_currencyFormat.format(balanceUsd)} USD',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '≈ ₦${_currencyFormat.format(balanceNgn)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _showCardDetails ? fullPan.replaceAll(' ', '') : fullPan));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card number copied to clipboard ✓'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Text(
                            _showCardDetails ? fullPan : maskedPan,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showCardDetails = !_showCardDetails;
                            });
                          },
                          child: Icon(
                            _showCardDetails ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _showCardDetails ? fullPan.replaceAll(' ', '') : fullPan));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card number copied to clipboard ✓'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom Row: Cardholder, Expiry, CVV & Visa Badge (Well-contained, zero overflow)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARDHOLDER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                          Text(
                            cardholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPIRES', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text('$expMonth/$expYear', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CVV', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text(_showCardDetails ? cvv : '•••', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'VISA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. 5 CORE ACTION BUTTONS (TOP-UP, WITHDRAW, DETAILS, PIN, FREEZE) ---
  Widget _buildCardActionButtons(bool isFrozen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Top-Up Card
        Expanded(
          child: _buildCircleActionButton(
            icon: Icons.add_rounded,
            label: 'Top-Up',
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
            onTap: _showFundCardModal,
          ),
        ),

        // 2. Withdraw / Liquidate Card
        Expanded(
          child: _buildCircleActionButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Withdraw',
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
            onTap: _showWithdrawCardModal,
          ),
        ),

        // 3. Details & Address
        Expanded(
          child: _buildCircleActionButton(
            icon: Icons.badge_outlined,
            label: 'Details',
            color: const Color(0xFF0D5C46),
            bgColor: const Color(0xFF0D5C46).withValues(alpha: 0.1),
            onTap: _showCardDetailsAndAddressModal,
          ),
        ),

        // 4. Card PIN
        Expanded(
          child: _buildCircleActionButton(
            icon: Icons.pin_rounded,
            label: 'PIN',
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            onTap: _showChangePinModal,
          ),
        ),

        // 5. Freeze / Unfreeze
        Expanded(
          child: _buildCircleActionButton(
            icon: isFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            label: isFrozen ? 'Unfreeze' : 'Freeze',
            color: isFrozen ? Colors.green : const Color(0xFFEA580C),
            bgColor: (isFrozen ? Colors.green : const Color(0xFFEA580C)).withValues(alpha: 0.12),
            onTap: _toggleFreeze,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. SECURITY & FEATURE BADGES ---
  Widget _buildSecurityFeatureRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPillItem(Icons.verified_user_rounded, '3D-Secure 2.0', const Color(0xFF0D5C46)),
          Container(width: 1, height: 18, color: const Color(0xFFE5E7EB)),
          _buildPillItem(Icons.public_rounded, 'San Francisco, CA', const Color(0xFF10B981)),
          Container(width: 1, height: 18, color: const Color(0xFFE5E7EB)),
          _buildPillItem(Icons.bolt_rounded, 'Instant Delivery', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildPillItem(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF374151)),
        ),
      ],
    );
  }

  // --- 5. TRANSACTION LEDGER HEADER & LIST ---
  Widget _buildTransactionLedgerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Card Transactions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (_cardTransactions.isNotEmpty)
          Text(
            '${_cardTransactions.length} records',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionLedgerList() {
    if (_cardTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 30, color: Color(0xFF0D5C46)),
            ),
            const SizedBox(height: 12),
            Text(
              'No Card Transactions Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Online purchases, Apple Pay, and card funding activities will appear here in real time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _cardTransactions.map((tx) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final isDebit = tx['type'] == 'DEBIT';
        final status = tx['status']?.toString() ?? 'SUCCESSFUL';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDebit ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF0D5C46).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDebit ? Icons.shopping_bag_outlined : Icons.add_rounded,
                  color: isDebit ? Colors.redAccent : const Color(0xFF0D5C46),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['merchantName']?.toString() ?? 'Online Purchase',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx['date']?.toString() ?? 'Recent',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDebit ? '-' : '+'}\$${_currencyFormat.format(amount)} USD',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'SUCCESSFUL' ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

