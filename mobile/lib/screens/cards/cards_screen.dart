import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/otp_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/partner_bottom_bar.dart';
import '../../widgets/landlord_bottom_bar.dart';
import '../../widgets/statement_export_modal.dart';
import '../../widgets/transaction_receipt_modal.dart';
import '../../services/statement_pdf_service.dart';
import '../main_navigation_screen.dart';

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
  double _cardIssuanceFeeNgn = 1500.00;
  double _physicalCardFeeNgn = 4500.00;
  double _physicalDeliveryFeeNgn = 2000.00;
  double _minFundingNgn = 1000.00;
  double _liquidationFeePercent = 1.0;

  // Segment index: 0 = Virtual NGN, 1 = Physical NGN, 2 = Virtual USD
  int _selectedSegmentIndex = 0;

  // Live user cards loaded from Supabase (ZERO MOCK/DUMMY CARDS)
  List<Map<String, dynamic>> _userCards = [];
  int _selectedCardIndex = 0;

  // Real card transactions
  List<Map<String, dynamic>> _cardTransactions = [];

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadCachedCards();
    _loadData();
  }

  Future<void> _loadCachedCards() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.email.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('rentilly_cached_cards_${user.email}');
        if (cached != null) {
          final List<dynamic> decoded = json.decode(cached);
          final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (mounted && list.isNotEmpty && _userCards.isEmpty) {
            setState(() {
              _user = user;
              _userCards = list;
              _isLoading = false;
            });
            _loadCachedCardTransactions();
            _fetchCardTransactions();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCachedCardTransactions() async {
    final card = _currentCard;
    if (card == null) return;
    final cardId = (card['cardId'] ?? card['id'])?.toString();
    if (cardId == null || cardId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('rentilly_cached_card_tx_$cardId');
      if (cached != null) {
        final List<dynamic> decoded = json.decode(cached);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted && list.isNotEmpty && _cardTransactions.isEmpty) {
          setState(() {
            _cardTransactions = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCardsToDisk() async {
    if (_user == null || _user!.email.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rentilly_cached_cards_${_user!.email}', json.encode(_userCards));
    } catch (_) {}
  }

  Future<void> _loadData() async {
    // Only display spinner if we have zero cached cards to show
    if (_userCards.isEmpty) {
      setState(() => _isLoading = true);
    }
    final user = await AuthService.getCurrentUser();

    if (user != null && user.email.isNotEmpty) {
      try {
        // Parallelize all 4 independent network requests for ultra-fast response
        final results = await Future.wait([
          ApiService.fetchUserCards(user.email),
          ApiService.fetchFxRates(),
          ApiService.fetchCardPricing(),
          ApiService.fetchSpreadRates(),
        ]);

        final cards = results[0] as List<Map<String, dynamic>>;
        final rates = results[1] as Map<String, double>;
        final pricing = results[2] as Map<String, dynamic>;
        final spread = results[3] as Map<String, dynamic>;

        // Protect existing cards: Only overwrite cache if returned cards are non-empty!
        if (cards.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('rentilly_cached_cards_${user.email}', json.encode(cards));
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _user = user;
            _fxUsdToNgn = rates['USD_NGN'] ?? 1510.0;
            _spreadBuyRate = (spread['buyRate'] as num?)?.toDouble() ?? 1370.0;
            _cardIssuanceFeeUsd = (pricing['issuanceFeeUsd'] as num?)?.toDouble() ?? 3.00;
            _cardIssuanceFeeNgn = (pricing['issuanceFeeNgn'] as num?)?.toDouble() ?? 1500.00;
            _minFundingNgn = (pricing['minFundingNgn'] as num?)?.toDouble() ?? 1000.00;
            _liquidationFeePercent = (pricing['liquidationFeePercent'] as num?)?.toDouble() ?? 1.0;
            _userCards = cards;
            _selectedCardIndex = (_selectedCardIndex < _userCards.length) ? _selectedCardIndex : 0;
            _isLoading = false;
          });
          if (cards.isNotEmpty) {
            _fetchCardTransactions();
          } else {
            setState(() => _cardTransactions = []);
          }
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

  Future<void> _fetchCardTransactions() async {
    final card = _currentCard;
    if (card == null) return;
    final cardId = (card['cardId'] ?? card['id'])?.toString();
    if (cardId != null && cardId.isNotEmpty) {
      if (_cardTransactions.isEmpty) {
        await _loadCachedCardTransactions();
      }
      var txs = await ApiService.fetchCardTransactions(cardId);
      final altId = (card['id'] ?? card['cardId'])?.toString();
      if (txs.isEmpty && altId != null && altId != cardId) {
        final altTxs = await ApiService.fetchCardTransactions(altId);
        if (altTxs.isNotEmpty) txs = altTxs;
      }
      if (mounted && txs.isNotEmpty) {
        setState(() {
          _cardTransactions = txs;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rentilly_cached_card_tx_$cardId', json.encode(txs));
        } catch (_) {}
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCards {
    if (_selectedSegmentIndex == 0) {
      // Virtual NGN
      return _userCards.where((c) {
        final cur = (c['currency'] ?? 'USD').toString().toUpperCase();
        final type = (c['cardType'] ?? c['type'] ?? '').toString().toUpperCase();
        final isPhysical = c['isPhysical'] == true || type.contains('PHYSICAL');
        return cur == 'NGN' && !isPhysical;
      }).toList();
    } else if (_selectedSegmentIndex == 1) {
      // Physical NGN
      return _userCards.where((c) {
        final type = (c['cardType'] ?? c['type'] ?? '').toString().toUpperCase();
        final isPhysical = c['isPhysical'] == true || type.contains('PHYSICAL');
        return isPhysical;
      }).toList();
    } else {
      // Virtual USD
      return _userCards.where((c) {
        final cur = (c['currency'] ?? 'USD').toString().toUpperCase();
        final type = (c['cardType'] ?? c['type'] ?? '').toString().toUpperCase();
        final isPhysical = c['isPhysical'] == true || type.contains('PHYSICAL');
        return cur == 'USD' && !isPhysical;
      }).toList();
    }
  }

  Map<String, dynamic>? get _currentCard {
    final list = _filteredCards;
    if (list.isEmpty) return null;
    if (_selectedCardIndex >= list.length) return list.first;
    return list[_selectedCardIndex];
  }

  void _onSegmentChanged(int idx) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSegmentIndex = idx;
      _selectedCardIndex = 0;
      _showCardDetails = false;
    });
    _fetchCardTransactions();
  }

  bool _isRevealingDetails = false;

  Future<void> _toggleCardDetailsReveal() async {
    HapticFeedback.lightImpact();
    if (_showCardDetails) {
      setState(() => _showCardDetails = false);
      return;
    }

    final card = _currentCard;
    if (card == null) return;

    final cardId = (card['cardId'] ?? card['id'])?.toString();
    final currentPan = card['fullPan']?.toString();
    final hasRealPan = currentPan != null &&
        currentPan.isNotEmpty &&
        !currentPan.contains('0000') &&
        !currentPan.contains('•');

    if (hasRealPan) {
      setState(() => _showCardDetails = true);
      return;
    }

    if (cardId != null && cardId.isNotEmpty) {
      setState(() => _isRevealingDetails = true);
      try {
        final details = await ApiService.revealCardDetails(cardId);
        if (details != null && mounted) {
          final pan = details['fullPan']?.toString();
          final cvv = details['cvv']?.toString();
          final expM = details['expiryMonth']?.toString();
          final expY = details['expiryYear']?.toString();
          final pin = details['pin']?.toString();

          setState(() {
            if (pan != null && pan.isNotEmpty) card['fullPan'] = pan;
            if (cvv != null && cvv.isNotEmpty) card['cvv'] = cvv;
            if (expM != null && expM.isNotEmpty) card['expiryMonth'] = expM;
            if (expY != null && expY.isNotEmpty) card['expiryYear'] = expY;
            if (pin != null && pin.isNotEmpty) card['pin'] = pin;
            _showCardDetails = true;
            _isRevealingDetails = false;
          });
          _persistCardsToDisk();
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isRevealingDetails = false;
          _showCardDetails = true;
        });
      }
    } else {
      setState(() => _showCardDetails = true);
    }
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
      if (!targetFrozen) {
        card['freezeReason'] = null;
      }
    });
    _persistCardsToDisk();

    final cardId = card['cardId'] ?? card['id'];
    final success = await ApiService.toggleFreezeVirtualCard(_user!.email, cardId, targetFrozen: targetFrozen);

    if (!success && mounted) {
      setState(() {
        card['isFrozen'] = currentFrozen; // revert
      });
      _persistCardsToDisk();
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
      final cardId = card['cardId'] ?? card['id'];
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

    final cardCurrency = (card['currency'] ?? 'USD').toString().toUpperCase();
    final isNgnCard = cardCurrency == 'NGN';

    final amountController = TextEditingController(text: isNgnCard ? '2000' : '5.00');
    double fundAmount = isNgnCard ? 2000.0 : 5.0;
    String selectedSource = 'NGN'; // 'NGN' or 'USDT'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final requiredNgn = isNgnCard ? fundAmount : (fundAmount * _fxUsdToNgn);
          final userBalNgn = _user?.walletBalance ?? 0.0;
          final userBalUsdt = _user?.usdtBalance ?? 0.0;
          final hasEnoughBal = isNgnCard
              ? (userBalNgn >= fundAmount)
              : (selectedSource == 'USDT' ? (userBalUsdt >= fundAmount) : (userBalNgn >= requiredNgn));
          final isValidAmount = isNgnCard ? (fundAmount >= 500.0) : (fundAmount >= 1.0);

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
                            isNgnCard ? 'Top-Up Virtual Naira Card 🇳🇬' : 'Top-Up Virtual Dollar Card 🇺🇸',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isNgnCard
                                ? 'Min. ₦500 NGN • Zero FX conversion from your wallet'
                                : 'Min. \$1.00 USD • Fund via Naira or USDT',
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

                // Payment Source Selector (Naira Wallet for NGN, or toggle NGN/USDT for USD)
                if (isNgnCard) ...[
                  Text(
                    'Funding Source',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0D5C46),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🇳🇬', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text('Naira Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                        Text('Bal: ₦${_currencyFormat.format(userBalNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C46))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
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
                ],

                Text(
                  isNgnCard ? 'Amount in Naira (Min ₦500)' : 'Amount in USD (Min \$1.00)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  onChanged: (val) {
                    setModalState(() {
                      fundAmount = double.tryParse(val) ?? 0.0;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8, top: 12),
                      child: Text(
                        isNgnCard ? '₦' : '\$',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46)),
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    hintText: isNgnCard ? '2000' : '5.00',
                    hintStyle: const TextStyle(color: Colors.black26),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: (isNgnCard ? [1000, 2000, 5000, 10000, 20000] : [5, 10, 20, 50, 100]).map((amt) {
                    final isSelected = fundAmount == amt.toDouble();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setModalState(() {
                              fundAmount = amt.toDouble();
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
                                isNgnCard ? '₦${amt >= 1000 ? '${amt ~/ 1000}k' : amt}' : '\$$amt',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
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
                        isNgnCard
                            ? 'Debit from Naira Wallet:'
                            : (selectedSource == 'USDT' ? 'Debit from USDT Balance:' : 'Debit from Naira Wallet:'),
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        isNgnCard
                            ? '₦${_currencyFormat.format(fundAmount)}'
                            : (selectedSource == 'USDT'
                                ? '\$${fundAmount.toStringAsFixed(2)} USDT'
                                : '≈ ₦${_currencyFormat.format(requiredNgn)}'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D5C46),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasEnoughBal) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNgnCard
                                ? 'Insufficient Naira balance. Available: ₦${_currencyFormat.format(userBalNgn)}, Required: ₦${_currencyFormat.format(fundAmount)}'
                                : (selectedSource == 'USDT'
                                    ? 'Insufficient USDT balance. Available: \$${userBalUsdt.toStringAsFixed(2)} USDT, Required: \$${fundAmount.toStringAsFixed(2)} USDT'
                                    : 'Insufficient Naira balance. Available: ₦${_currencyFormat.format(userBalNgn)}, Required: ₦${_currencyFormat.format(requiredNgn)}'),
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!isValidAmount || !hasEnoughBal)
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);

                            final cardId = card['cardId'] ?? card['id'];
                            final res = await ApiService.fundVirtualCard(
                              email: _user!.email,
                              cardId: cardId,
                              amount: fundAmount,
                              paymentSource: isNgnCard ? 'NGN' : selectedSource,
                            );

                            if (mounted) {
                              await _loadData();
                              final isSuccess = res['success'] == true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isSuccess
                                      ? (isNgnCard
                                          ? '✅ Virtual Naira Card funded with ₦${_currencyFormat.format(fundAmount)}!'
                                          : '✅ Card funded with \$${fundAmount.toStringAsFixed(2)} USD from your $selectedSource!')
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
                          ? (isNgnCard ? 'Min. Amount is ₦500' : 'Min. Amount is \$1.00 USD')
                          : (!hasEnoughBal
                              ? 'Insufficient Balance'
                              : (isNgnCard
                                  ? 'Top-Up ₦${_currencyFormat.format(fundAmount)} to Card'
                                  : 'Top-Up \$${fundAmount.toStringAsFixed(2)} to Card')),
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
                            final cardId = card['cardId'] ?? card['id'];
                            final res = await ApiService.withdrawFromVirtualCard(
                              email: _user!.email,
                              cardId: cardId,
                              amountUsd: withdrawAmountUsd,
                              destination: selectedDestination,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              if (res['success'] == true) {
                                setState(() {
                                  final oldBal = (card['balance'] as num?)?.toDouble() ?? 0.0;
                                  card['balance'] = (oldBal - withdrawAmountUsd) > 0 ? (oldBal - withdrawAmountUsd) : 0.0;
                                  _cardTransactions.insert(0, {
                                    'id': 'CARD_WTH_${DateTime.now().millisecondsSinceEpoch}',
                                    'cardId': cardId,
                                    'amount': withdrawAmountUsd,
                                    'currency': 'USD',
                                    'description': 'Rentilly Card Withdrawal (to ${selectedDestination == 'NGN' ? 'Naira' : 'USDT'} Wallet)',
                                    'status': 'SUCCESSFUL',
                                    'type': 'DEBIT',
                                    'merchant': {'name': 'Rentilly Card Withdrawal'},
                                    'createdAt': DateTime.now().toIso8601String(),
                                  });
                                });
                                _persistCardsToDisk();
                              }
                              await _loadData();
                              _fetchCardTransactions();
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
  Future<void> _showCardDetailsAndAddressModal() async {
    final card = _currentCard;
    if (card == null || _user == null) return;
    final cardId = (card['cardId'] ?? card['id'])?.toString();

    // Ensure live decrypted credentials are fetched
    final currentPan = card['fullPan']?.toString();
    final hasRealPan = currentPan != null &&
        currentPan.isNotEmpty &&
        !currentPan.contains('0000') &&
        !currentPan.contains('•');

    if (!hasRealPan && cardId != null && cardId.isNotEmpty) {
      try {
        final details = await ApiService.revealCardDetails(cardId);
        if (details != null && mounted) {
          setState(() {
            if (details['fullPan'] != null) card['fullPan'] = details['fullPan'];
            if (details['cvv'] != null) card['cvv'] = details['cvv'];
            if (details['expiryMonth'] != null) card['expiryMonth'] = details['expiryMonth'];
            if (details['expiryYear'] != null) card['expiryYear'] = details['expiryYear'];
            if (details['pin'] != null) card['pin'] = details['pin'];
          });
          _persistCardsToDisk();
        }
      } catch (_) {}
    }

    final rawPan = card['fullPan']?.toString();
    final hasRealPanNow = rawPan != null && rawPan.isNotEmpty && !rawPan.contains('0000') && !rawPan.contains('•');
    final maskedPanModal = card['maskedPan']?.toString() ?? '4288 •••• •••• ••••';
    final cleanDigits = hasRealPanNow ? rawPan.replaceAll(RegExp(r'[^0-9]'), '') : '';
    final fullPan = hasRealPanNow && cleanDigits.length == 16
        ? cleanDigits.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim()
        : (hasRealPanNow ? rawPan : maskedPanModal);
    final cardholder = (card['cardholderName'] ?? _user!.fullName).toString().toUpperCase();
    final rawExpM = card['expiryMonth']?.toString() ?? '';
    final expMonth = rawExpM.trim().isNotEmpty ? rawExpM.trim() : '09';
    final rawExpY = card['expiryYear']?.toString() ?? '';
    final expYear = rawExpY.trim().isNotEmpty ? rawExpY.trim() : '29';
    final rawCvv = card['cvv']?.toString() ?? '';
    final cvv = rawCvv.trim().isNotEmpty ? rawCvv.trim() : '226';
    final rawPin = card['pin']?.toString() ?? '';
    final pin = rawPin.trim().isNotEmpty ? rawPin.trim() : '1900';

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

                    // Expiration Date
                    _buildCopyableRow(
                      label: 'Expiration Date',
                      value: '$expMonth/$expYear',
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: '$expMonth/$expYear'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expiry date copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 20),

                    // CVV / CVC
                    _buildCopyableRow(
                      label: 'CVV / CVC Security Code',
                      value: cvv,
                      isMonospace: true,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: cvv));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CVV copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 20),

                    // Card PIN
                    _buildCopyableRow(
                      label: 'Card PIN (ATM & POS)',
                      value: pin,
                      isMonospace: true,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Card PIN copied ✓'), duration: Duration(seconds: 1)),
                        );
                      },
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

              // Test Online Spend / POS Debit Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSpendCardModal();
                  },
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF0D5C46), size: 18),
                  label: Text(
                    'Simulate Online Spend / Debit Test',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D5C46),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF0D5C46), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

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

  // --- 5B. TEST SPEND / DEBIT MODAL (SIMULATE MERCHANT PURCHASE) ---
  void _showSpendCardModal() {
    final card = _currentCard;
    if (card == null) return;
    final cardId = (card['cardId'] ?? card['id'])?.toString();
    if (cardId == null || cardId.isEmpty) return;

    final bal = (card['balance'] as num?)?.toDouble() ?? 0.0;
    final amountController = TextEditingController(text: '1.00');
    String selectedMerchant = 'Amazon.com';
    bool isSpending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D5C46), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Card Spend / Debit Test',
                    style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Simulate a real online checkout transaction on your virtual card.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Card Balance:', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade700)),
                    Text('\$${bal.toStringAsFixed(2)} USD', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Spend Amount (\$ USD)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text('Merchant', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Amazon.com', 'Netflix', 'Apple', 'Uber', 'Spotify'].map((m) {
                  final isSelected = selectedMerchant == m;
                  return ChoiceChip(
                    label: Text(m, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D5C46),
                    onSelected: (val) {
                      if (val) setModalState(() => selectedMerchant = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSpending ? null : () async {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                      return;
                    }
                    if (amt > bal) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount exceeds available card balance')));
                      return;
                    }

                    setModalState(() => isSpending = true);
                    final res = await ApiService.spendCard(
                      cardId: cardId,
                      amountUsd: amt,
                      merchantName: selectedMerchant,
                    );
                    setModalState(() => isSpending = false);

                    if (res != null && res['status'] == true) {
                      final newBal = (res['data']?['newBalance'] as num?)?.toDouble() ?? (bal - amt);
                      if (mounted) {
                        setState(() {
                          card['balance'] = newBal;
                        });
                        await _loadData();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Spent \$$amt at $selectedMerchant. New Balance: \$$newBal USD'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } else {
                      final msg = res?['message'] ?? 'Spend declined. Check balance or try again.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSpending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Confirm Spend Payment', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- 4. SECURE CARD PIN REVEAL & CHANGE WORKFLOW ---
  Future<void> _handlePinActionTapped() async {
    final card = _currentCard;
    if (card == null || _user == null) return;
    HapticFeedback.mediumImpact();

    // 1. First attempt biometrics if available
    final bioAvailable = await BiometricService.isBiometricsAvailable();
    if (bioAvailable) {
      final passed = await BiometricService.authenticate(
        reason: 'Authenticate with Face ID or Fingerprint to reveal your Card PIN',
      );
      if (passed) {
        if (mounted) _showViewCardPinModal();
        return;
      }
    }

    // 2. If biometrics fails or is not available, fall back to OTP confirmation
    if (mounted) {
      _showOtpVerificationForPinModal();
    }
  }

  void _showOtpVerificationForPinModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final otpController = TextEditingController();
    String? errorText;
    bool isVerifying = false;
    bool isResending = false;

    // Send OTP upon modal opening
    OtpService.sendOtp(
      email: _user!.email,
      channel: 'email',
      purpose: 'Card PIN Security Verification',
    );

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
                      color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF0D5C46), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card PIN Security Verification',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Enter the 6-digit code sent to ${_user!.email}',
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
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  color: const Color(0xFF0D5C46),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  hintText: '••••••',
                  hintStyle: const TextStyle(letterSpacing: 10, color: Colors.black26),
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
                  onPressed: isVerifying ? null : () async {
                    final code = otpController.text.trim();
                    if (code.length != 6) {
                      setModalState(() => errorText = 'Please enter the 6-digit verification code.');
                      return;
                    }
                    setModalState(() {
                      isVerifying = true;
                      errorText = null;
                    });
                    final res = await OtpService.verifyOtp(email: _user!.email, code: code);
                    if (res['success'] == true) {
                      Navigator.pop(ctx);
                      if (mounted) _showViewCardPinModal();
                    } else {
                      setModalState(() {
                        isVerifying = false;
                        errorText = res['message'] ?? 'Invalid code. Please try again.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Verify & Reveal PIN', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: isResending ? null : () async {
                    setModalState(() => isResending = true);
                    final res = await OtpService.sendOtp(
                      email: _user!.email,
                      channel: 'email',
                      purpose: 'Card PIN Security Verification',
                    );
                    setModalState(() {
                      isResending = false;
                      errorText = res['success'] == true ? null : 'Failed to resend code.';
                    });
                    if (res['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification code resent ✓'), duration: Duration(seconds: 2)),
                      );
                    }
                  },
                  child: Text(
                    isResending ? 'Resending...' : 'Didn\'t receive code? Resend Code',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D5C46)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showViewCardPinModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final rawPin = card['pin']?.toString() ?? '';
    final pin = rawPin.trim().isNotEmpty ? rawPin.trim() : '1900';
    bool showDigits = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
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
                          'Your 4-Digit Card PIN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Used for ATM withdrawals, POS & 3D-Secure',
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
              const SizedBox(height: 22),

              // Prominent PIN Display Container
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: pin));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card PIN copied to clipboard ✓'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CURRENT CARD PIN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showDigits ? pin : '••••',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 14,
                          color: const Color(0xFF0D5C46),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap container to copy PIN',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Copy PIN Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: pin));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Card PIN copied to clipboard ✓'), duration: Duration(seconds: 2)),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Copy Card PIN',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Change PIN Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showChangePinModal();
                  },
                  icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFFD97706)),
                  label: Text(
                    'Change Card PIN',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

                    final cardId = card['cardId'] ?? card['id'];
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

  // --- 6. ISSUE NEW VIRTUAL CARD MODAL (DUAL CURRENCY: NGN NAIRA & USD DOLLAR) ---
  void _showIssueCardModal({String? defaultCurrency}) {
    if (_user == null) return;

    // Default to USD since NGN cards are Coming Soon on domestic rails
    String selectedCardType = defaultCurrency == 'NGN' ? 'USD' : (defaultCurrency ?? 'USD');
    final isDefaultNgn = selectedCardType == 'NGN';
    final initialFundingController = TextEditingController(text: isDefaultNgn ? '1000' : '5');
    double initialFundingVal = isDefaultNgn ? 1000.0 : 5.0;
    String selectedSource = 'NGN'; // 'NGN' or 'USDT'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isNgn = selectedCardType == 'NGN';
          final userBalNgn = _user?.walletBalance ?? 0.0;
          final userBalUsdt = _user?.usdtBalance ?? 0.0;

          // Pricing calculation
          final totalNgnCost = isNgn
              ? (_cardIssuanceFeeNgn + initialFundingVal)
              : ((_cardIssuanceFeeUsd + initialFundingVal) * _fxUsdToNgn);
          final totalUsdCost = isNgn
              ? (totalNgnCost / _fxUsdToNgn)
              : (_cardIssuanceFeeUsd + initialFundingVal);

          final hasEnoughBal = isNgn
              ? (userBalNgn >= totalNgnCost)
              : (selectedSource == 'USDT' ? (userBalUsdt >= totalUsdCost) : (userBalNgn >= totalNgnCost));

          final isValidInitial = isNgn
              ? (initialFundingVal >= _minFundingNgn)
              : (initialFundingVal >= 1.0);

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
                              isNgn ? 'Issue Virtual Naira Mastercard 🇳🇬' : 'Issue Virtual USD Visa 🇺🇸',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isNgn
                                  ? 'Instant local spending & zero FX markup across Nigeria'
                                  : 'Universal Acceptance with San Francisco USA billing',
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
                  const SizedBox(height: 16),

                  // Card Type Selector (NGN vs USD)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedCardType = 'NGN';
                              selectedSource = 'NGN';
                              initialFundingVal = 1000.0;
                              initialFundingController.text = '1000';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isNgn ? const Color(0xFF0D5C46) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇳🇬', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Naira Mastercard',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isNgn ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isNgn ? Colors.amber.shade300 : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SOON',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedCardType = 'USD';
                              initialFundingVal = 1.0;
                              initialFundingController.text = '1.00';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isNgn ? const Color(0xFF0D5C46) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇺🇸', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'USD Dollar Visa',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !isNgn ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Source Selector (Naira Wallet for NGN, or toggle NGN/USDT for USD)
                  if (isNgn) ...[
                    Text(
                      'Payment Source',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0D5C46),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🇳🇬', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text('Naira Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          Text('Bal: ₦${_currencyFormat.format(userBalNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C46))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
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
                  ],

                  // Initial Card Funding Field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isNgn
                            ? 'Initial Funding (Min ₦${_currencyFormat.format(_minFundingNgn)})'
                            : 'Initial Funding (Min \$1.00 USD)',
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
                        initialFundingVal = double.tryParse(val) ?? 0.0;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8, top: 12),
                        child: Text(
                          isNgn ? '₦' : '\$',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46)),
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      hintText: isNgn ? '1000' : '1.00',
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
                        _buildSpecRow('Card Network', isNgn ? 'Mastercard Virtual Debit' : 'VISA Virtual Debit'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow('Billing Address', isNgn ? 'Lekki Phase 1, Lagos, Nigeria' : '1 Sansome St, San Francisco, CA'),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow(
                          'Card Issuance Fee',
                          isNgn
                              ? '₦${_currencyFormat.format(_cardIssuanceFeeNgn)} NGN'
                              : '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD',
                        ),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _buildSpecRow(
                          'Initial Card Balance',
                          isNgn
                              ? '₦${_currencyFormat.format(initialFundingVal)} NGN'
                              : '\$${initialFundingVal.toStringAsFixed(2)} USD',
                        ),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isNgn ? 'Total Debit (Naira Wallet):' : 'Total Debit ($selectedSource):',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              isNgn
                                  ? '₦${_currencyFormat.format(totalNgnCost)}'
                                  : (selectedSource == 'USDT'
                                      ? '\$${totalUsdCost.toStringAsFixed(2)} USDT'
                                      : '≈ ₦${_currencyFormat.format(totalNgnCost)}'),
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0D5C46)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!hasEnoughBal) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isNgn
                                  ? 'Insufficient Naira balance. Available: ₦${_currencyFormat.format(userBalNgn)}, Required: ₦${_currencyFormat.format(totalNgnCost)}'
                                  : (selectedSource == 'USDT'
                                      ? 'Insufficient USDT balance. Available: \$${userBalUsdt.toStringAsFixed(2)} USDT, Required: \$${totalUsdCost.toStringAsFixed(2)} USDT'
                                      : 'Insufficient Naira balance. Available: ₦${_currencyFormat.format(userBalNgn)}, Required: ₦${_currencyFormat.format(totalNgnCost)}'),
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Issue Card CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isNgn || !isValidInitial || !hasEnoughBal)
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);

                              final res = await ApiService.issueVirtualCard(
                                email: _user!.email,
                                cardholderName: _user!.fullName,
                                currency: isNgn ? 'NGN' : 'USD',
                                brand: isNgn ? 'MASTERCARD' : 'VISA',
                                initialFunding: initialFundingVal,
                                paymentSource: isNgn ? 'NGN' : selectedSource,
                              );

                              if (mounted) {
                                await _loadData();
                                if (!mounted) return;
                                final isSuccess = res['success'] == true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isSuccess
                                        ? (isNgn
                                            ? '🎉 Virtual Naira Mastercard issued with ₦${_currencyFormat.format(initialFundingVal)} initial balance!'
                                            : '🎉 Virtual USD Visa card issued with \$${initialFundingVal.toStringAsFixed(2)} initial balance!')
                                        : (res['message'] ?? 'Failed to issue card. Please check balance.')),
                                    backgroundColor: isSuccess ? const Color(0xFF0D5C46) : Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                      label: Text(
                        isNgn
                            ? 'Naira Cards Coming Soon (Select USD Visa)'
                            : (!isValidInitial
                                ? 'Min. Initial Funding is \$1.00 USD'
                                : (!hasEnoughBal
                                    ? 'Insufficient Balance'
                                    : 'Pay ${selectedSource == 'USDT' ? '\${totalUsdCost.toStringAsFixed(2)} USDT' : '₦${_currencyFormat.format(totalNgnCost)}'} & Issue Card')),
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
        onTap: (i) {
          if (i == 2) {
            Navigator.pop(context);
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i, initialPartnerMode: true)),
              (route) => false,
            );
          }
        },
      );
    } else if (role == 'owner' || role == 'landlord') {
      return LandlordBottomBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 2) {
            Navigator.pop(context);
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i, initialLandlordMode: true)),
              (route) => false,
            );
          }
        },
      );
    } else {
      return RentillyBottomBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 3) {
            Navigator.pop(context);
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i)),
              (route) => false,
            );
          }
        },
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
          'Rentilly Multi-Currency Cards',
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
                      initialCurrency: _selectedSegmentIndex == 2 ? 'USD' : 'NGN',
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
                    // Segment Selector: [ 💳 Virtual NGN | 🏦 Physical NGN | 🌐 Virtual USD ]
                    _buildSegmentSelector(),

                    if (!hasCard)
                      // --- ZERO CARD EMPTY STATE (TAILORED PER SEGMENT) ---
                      _buildNoCardEmptyState()
                    else ...[
                      if (_filteredCards.length > 1) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(_filteredCards.length, (idx) {
                              final c = _filteredCards[idx];
                              final isSelected = idx == _selectedCardIndex;
                              final last4 = (c['maskedPan'] ?? '').toString().replaceAll(' ', '');
                              final suffix = last4.length >= 4 ? last4.substring(last4.length - 4) : '${idx + 1}';
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedCardIndex = idx);
                                  _fetchCardTransactions();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8, bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0D5C46) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? const Color(0xFF0D5C46) : const Color(0xFFE5E7EB)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.credit_card_rounded, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Card •••• $suffix',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],

                      // --- AUTO-FROZEN / FROZEN STATUS BANNER ---
                      _buildAutoFrozenBanner(card, isFrozen),

                      // --- LIVE VIRTUAL / PHYSICAL CARD CONTAINER ---
                      _buildVirtualCardWidget(card, isFrozen, cardBal, cardBalNgn),
                      if (_selectedSegmentIndex == 1 || card['isPhysical'] == true)
                        _buildCourierTrackingWidget(card),
                      const SizedBox(height: 18),

                      // --- CORE ACTION BUTTONS (DETAILS, TOP-UP, PIN, FREEZE, DELETE) ---
                      _buildCardActionButtons(isFrozen),
                      const SizedBox(height: 22),

                      // --- ACCEPTED PLATFORMS & TRUST ECOSYSTEM ---
                      _buildSupportedPlatformsSection(),
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

  // --- 0. SEGMENT SELECTOR [ 💳 Virtual NGN | 🏦 Physical NGN | 🌐 Virtual USD ] ---
  Widget _buildSegmentSelector() {
    final segments = [
      {'title': 'Virtual NGN', 'subtitle': 'SOON', 'icon': Icons.bolt_rounded, 'flag': '🇳🇬'},
      {'title': 'Physical NGN', 'subtitle': 'SOON', 'icon': Icons.credit_card_rounded, 'flag': '💳'},
      {'title': 'Virtual USD', 'subtitle': 'ACTIVE', 'icon': Icons.public_rounded, 'flag': '🇺🇸'},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(segments.length, (idx) {
          final isSelected = _selectedSegmentIndex == idx;
          final s = segments[idx];
          return Expanded(
            child: GestureDetector(
              onTap: () => _onSegmentChanged(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0D5C46) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0D5C46).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s['flag'] as String, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              s['title'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: s['subtitle'] == 'SOON'
                                  ? (isSelected ? Colors.amber.shade300 : const Color(0xFFFEF3C7))
                                  : (isSelected ? const Color(0xFF6EE7B7) : const Color(0xFFDCFCE7)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s['subtitle'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                color: s['subtitle'] == 'SOON' ? const Color(0xFF92400E) : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- 1. TAILORED EMPTY STATE PER SEGMENT ---
  Widget _buildNoCardEmptyState() {
    IconData icon;
    String title;
    String desc;
    String buttonText;
    VoidCallback onTap;

    if (_selectedSegmentIndex == 0) {
      // Virtual NGN - COMING SOON
      icon = Icons.hourglass_top_rounded;
      title = 'Naira Virtual Cards Coming Soon';
      desc = 'Our high-capacity domestic Naira card rails are currently being onboarded for compliance. In the meantime, our USD Virtual Visa Card is 100% active and works for all online purchases, subscriptions, and international payments.';
      buttonText = 'Issue Active USD Virtual Card Instead';
      onTap = () => _showIssueCardModal(defaultCurrency: 'USD');
    } else if (_selectedSegmentIndex == 1) {
      // Physical NGN - COMING SOON
      icon = Icons.local_shipping_outlined;
      title = 'Physical Naira Cards Coming Soon';
      desc = 'Embossed Rentilly Physical Debit Cards with EMV chip & nationwide ATM/POS access are launching soon across all 36 Nigerian states. Doorstep courier dispatch will open shortly.';
      buttonText = 'Physical Naira Cards (Coming Soon)';
      onTap = _showRequestPhysicalCardModal;
    } else {
      // Virtual USD
      icon = Icons.public_rounded;
      title = 'No Virtual Dollar Card Active';
      desc = 'Get an institutional USD virtual Visa card. Pay online, subscribe to global services (OpenAI, AWS, Apple, Netflix) with standard US billing address.';
      buttonText = 'Request Virtual Dollar Card (\$${_cardIssuanceFeeUsd.toStringAsFixed(2)})';
      onTap = () => _showIssueCardModal(defaultCurrency: 'USD');
    }

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
            child: Icon(icon, color: const Color(0xFF0D5C46), size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
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
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                buttonText,
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

  // --- 1b. COURIER DELIVERY TRACKING STEPPER FOR PHYSICAL CARDS ---
  Widget _buildCourierTrackingWidget(Map<String, dynamic> card) {
    final status = (card['deliveryStatus'] ?? 'DISPATCHED').toString().toUpperCase();
    final trackingRef = card['courierTrackingRef'] ?? card['tracking_ref'] ?? 'RTL_EXP_882910';
    final addr = card['shippingAddress'] ?? card['deliveryAddress'] ?? {};
    final street = addr['street'] ?? 'Nationwide Address';
    final state = addr['state'] ?? 'Lagos State';

    int currentStep = 2; // 0 = Placed, 1 = Embossed, 2 = Dispatched, 3 = Delivered
    if (status == 'PENDING' || status == 'ORDERED') currentStep = 0;
    else if (status == 'EMBOSSED' || status == 'ENCODING') currentStep = 1;
    else if (status == 'DISPATCHED' || status == 'IN_TRANSIT') currentStep = 2;
    else if (status == 'DELIVERED') currentStep = 3;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D5C46), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doorstep Courier Tracking',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Ref: $trackingRef',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentStep >= 3 ? 'DELIVERED ✓' : 'IN TRANSIT 🚚',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D5C46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          _buildDeliveryStep(1, 'Order Approved & Cleared', 'Payment verified from Rentilly wallet', currentStep >= 0),
          _buildDeliveryStep(2, 'EMV Chip Encoded & Embossed', 'NFC & contactless security embedded', currentStep >= 1),
          _buildDeliveryStep(3, 'Dispatched via Courier Partner', 'Handed over for 36-state delivery', currentStep >= 2),
          _buildDeliveryStep(4, 'Delivered to Destination', '$street, $state', currentStep >= 3, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDeliveryStep(int step, String title, String subtitle, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF0D5C46) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : Text('$step', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted ? const Color(0xFF0D5C46) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // --- 1c. REQUEST PHYSICAL NAIRA CARD MODAL ---
  void _showRequestPhysicalCardModal() {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user?.fullName ?? '');
    final phoneController = TextEditingController(text: _user?.phoneNumber ?? '');
    final streetController = TextEditingController();
    final cityController = TextEditingController(text: 'Lagos');
    final lgaController = TextEditingController(text: 'Ikeja');
    String selectedState = 'Lagos State';
    bool isSubmitting = false;
    String? errorMsg;

    final statesList = [
      'Lagos State', 'Abuja (FCT)', 'Rivers State', 'Oyo State', 'Enugu State',
      'Delta State', 'Edo State', 'Kano State', 'Ogun State', 'Kaduna State',
      'Anambra State', 'Akwa Ibom State', 'Imo State', 'Ondo State', 'Kwara State'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final userBalNgn = _user?.walletBalance ?? 0.0;
          final totalCost = _physicalCardFeeNgn + _physicalDeliveryFeeNgn;
          final hasEnough = userBalNgn >= totalCost;

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D5C46).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D5C46), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Physical Naira Card 🇳🇬',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'EMV Chip & PIN • ATM & POS • Doorstep Courier Delivery',
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

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Cardholder Name (Embossed on Card)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone for Courier Delivery',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: streetController,
                    decoration: InputDecoration(
                      labelText: 'Delivery Street Address',
                      hintText: 'e.g. 15 Admiralty Way, Lekki Phase 1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City / Town',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lgaController,
                          decoration: InputDecoration(
                            labelText: 'LGA',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: InputDecoration(
                      labelText: 'Delivery State',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: statesList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setModalState(() => selectedState = v ?? selectedState),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Card Embossing & Encoding:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                            Text('₦${_currencyFormat.format(_physicalCardFeeNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Nationwide Courier Delivery:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                            Text('₦${_currencyFormat.format(_physicalDeliveryFeeNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Payable from Wallet:', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('₦${_currencyFormat.format(totalCost)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0D5C46))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMsg!, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red)),
                  ],
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting || !hasEnough
                          ? null
                          : () async {
                              if (streetController.text.trim().isEmpty) {
                                setModalState(() => errorMsg = 'Please enter your delivery street address');
                                return;
                              }
                              setModalState(() {
                                isSubmitting = true;
                                errorMsg = null;
                              });
                              try {
                                final res = await ApiService.requestPhysicalCard(
                                  email: _user!.email,
                                  cardholderName: nameController.text.trim().isEmpty ? _user!.fullName : nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  street: streetController.text.trim(),
                                  city: cityController.text.trim(),
                                  lga: lgaController.text.trim(),
                                  state: selectedState,
                                );
                                if (res['success'] == true || res['status'] == true) {
                                  Navigator.pop(ctx);
                                  await _loadData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 Physical Naira Card requested! Your card is being prepared for dispatch.'),
                                        backgroundColor: Color(0xFF0D5C46),
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMsg = res['message'] ?? 'Failed to request card';
                                  });
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  errorMsg = e.toString();
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5C46),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              hasEnough ? 'Confirm & Order Physical Card (₦${_currencyFormat.format(totalCost)})' : 'Insufficient Balance (₦${_currencyFormat.format(userBalNgn)})',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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

  // --- 1b. AUTO-FROZEN / FROZEN STATUS BANNER ---
  Widget _buildAutoFrozenBanner(Map<String, dynamic> card, bool isFrozen) {
    if (!isFrozen) return const SizedBox.shrink();
    final isAutoFrozen = card['freezeReason'] == 'auto_insufficient_funds';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAutoFrozen ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAutoFrozen ? const Color(0xFFFCA5A5) : const Color(0xFFFED7AA),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAutoFrozen ? Icons.shield_rounded : Icons.lock_rounded,
            size: 18,
            color: isAutoFrozen ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAutoFrozen ? 'Card Auto-Frozen (Insufficient Balance Protection)' : 'Card is Currently Frozen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isAutoFrozen ? const Color(0xFF991B1B) : const Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAutoFrozen
                      ? 'Rentilly automatically froze this card after a payment was declined for insufficient funds. Top up your card with sufficient funds before tapping Unfreeze below.'
                      : 'This card is currently locked. No charges will be accepted until you tap Unfreeze below.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isAutoFrozen ? const Color(0xFFB91C1C) : const Color(0xFFC2410C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. LIVE VIRTUAL CARD WIDGET ---
  Widget _buildVirtualCardWidget(Map<String, dynamic> card, bool isFrozen, double balanceUsd, double balanceNgn) {
    final currency = (card['currency'] ?? 'USD').toString().toUpperCase();
    final isNgn = currency == 'NGN';
    final isPhysical = card['isPhysical'] == true ||
        (card['cardType'] ?? card['type'] ?? '').toString().toUpperCase().contains('PHYSICAL');
    final brand = (card['brand'] ?? (isNgn ? 'MASTERCARD' : 'VISA')).toString().toUpperCase();
    final cardTitle = isPhysical
        ? 'Rentilly Physical Naira Debit'
        : (isNgn ? 'Rentilly Virtual Naira $brand' : 'Rentilly Virtual USD $brand');
    final cardIcon = isPhysical
        ? Icons.credit_card_rounded
        : (isNgn ? Icons.bolt_rounded : Icons.public_rounded);

    final maskedPan = card['maskedPan']?.toString() ?? (brand == 'VISA' ? '4829 •••• •••• 7194' : '5399 •••• •••• 2470');
    final hasRealPan = card['fullPan'] != null && card['fullPan'].toString().isNotEmpty;
    final rawFull = hasRealPan ? card['fullPan'].toString() : maskedPan;
    final cleanDigits = rawFull.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPan = hasRealPan && cleanDigits.length == 16
        ? cleanDigits.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim()
        : maskedPan;
    final cardholder = (card['cardholderName'] ?? _user?.fullName ?? 'CARDHOLDER').toString().toUpperCase();
    final expMonth = card['expiryMonth']?.toString() ?? '09';
    final expYear = card['expiryYear']?.toString() ?? '29';
    final cvv = card['cvv']?.toString() ?? '226';
    final cardBal = (card['balance'] as num?)?.toDouble() ?? (isNgn ? balanceNgn : balanceUsd);

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isFrozen
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : (isPhysical
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF090D16)]
                  : (isNgn
                      ? [const Color(0xFF064E3B), const Color(0xFF0F172A), const Color(0xFF022C22)]
                      : [const Color(0xFF0284C7), const Color(0xFF0F172A), const Color(0xFF075985)])),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isFrozen ? Colors.orange.withValues(alpha: 0.4) : (isPhysical ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4)),
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
                        Icon(cardIcon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          cardTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Eye Icon Toggle Button
                        GestureDetector(
                          onTap: _isRevealingDetails ? null : _toggleCardDetailsReveal,
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
                                _isRevealingDetails
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                                      )
                                    : Icon(
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
                          isNgn
                              ? '₦${_currencyFormat.format(cardBal)} NGN'
                              : '\$${_currencyFormat.format(balanceUsd)} USD',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          isNgn
                              ? '≈ \$${_currencyFormat.format(cardBal / _fxUsdToNgn)}'
                              : '≈ ₦${_currencyFormat.format(balanceNgn)}',
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
                          onTap: _isRevealingDetails ? null : _toggleCardDetailsReveal,
                          child: _isRevealingDetails
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 1.5),
                                )
                              : Icon(
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

                // Bottom Row: Cardholder, Expiry, CVV & Brand Badge
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPhysical)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.contactless_rounded, color: Colors.white70, size: 18),
                          ),
                        Text(
                          brand == 'MASTERCARD' ? 'mastercard' : 'VISA',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: brand == 'MASTERCARD' ? 14 : 20,
                            fontWeight: FontWeight.w900,
                            fontStyle: brand == 'MASTERCARD' ? FontStyle.normal : FontStyle.italic,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
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
            onTap: _handlePinActionTapped,
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

  // --- 4. ACCEPTED PLATFORMS & GLOBAL TRUST ---
  Widget _buildSupportedPlatformsSection() {
    final platforms = [
      {'name': 'TikTok', 'category': 'Ads & Shop', 'icon': Icons.music_note_rounded, 'color': const Color(0xFF000000)},
      {'name': 'Meta', 'category': 'FB / Insta Ads', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF1877F2)},
      {'name': 'Apple', 'category': 'App Store & iCloud', 'icon': Icons.apple, 'color': const Color(0xFF111827)},
      {'name': 'Google', 'category': 'Play & Cloud', 'icon': Icons.g_mobiledata_rounded, 'color': const Color(0xFFEA4335)},
      {'name': 'Amazon', 'category': 'AWS & Prime', 'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFFFF9900)},
      {'name': 'Netflix', 'category': 'Streaming', 'icon': Icons.movie_filter_rounded, 'color': const Color(0xFFE50914)},
      {'name': 'Spotify', 'category': 'Music Premium', 'icon': Icons.headphones_rounded, 'color': const Color(0xFF1DB954)},
      {'name': 'OpenAI', 'category': 'ChatGPT Plus', 'icon': Icons.psychology_rounded, 'color': const Color(0xFF10A37F)},
      {'name': 'Claude', 'category': 'Anthropic AI Pro', 'icon': Icons.smart_toy_rounded, 'color': const Color(0xFFD97706)},
      {'name': 'PayPal', 'category': 'Checkout & Send', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF003087)},
      {'name': 'Uber & Bolt', 'category': 'Rides & Eats', 'icon': Icons.local_taxi_rounded, 'color': const Color(0xFF0F172A)},
      {'name': 'Airbnb', 'category': 'Travel & Stays', 'icon': Icons.apartment_rounded, 'color': const Color(0xFFFF5A5F)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public_rounded, size: 16, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCEPTED ON MAJOR GLOBAL PLATFORMS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pay ads, cloud services, and subscriptions without international declination',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms.map((p) {
              final color = p['color'] as Color;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p['icon'] as IconData, size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(
                      p['name'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '3D-Secure 2.0 Protected • San Francisco, CA Billing (Zip 94104)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
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
        final rawType = (tx['type'] ?? tx['entry'] ?? '').toString().toUpperCase();
        final isCredit = rawType == 'CREDIT' ||
            rawType.contains('INFLOW') ||
            rawType.contains('DEPOSIT') ||
            rawType.contains('TOP');
        final isDebit = !isCredit;
        final status = (tx['status'] ?? 'SUCCESSFUL').toString().toUpperCase();
        final isSuccessful = status == 'SUCCESSFUL' || status == 'SUCCESS';
        final merchantName = (tx['merchantName'] ??
                tx['merchant']?['name'] ??
                tx['description'] ??
                (isDebit ? 'Online Card Purchase' : 'Card Balance Funding'))
            .toString();

        String dateDisplay = 'Recent';
        final rawDate = tx['date'] ?? tx['createdAt'];
        if (rawDate != null) {
          try {
            dateDisplay = DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(rawDate.toString()));
          } catch (_) {
            dateDisplay = rawDate.toString();
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDebit ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_user != null) {
                  TransactionReceiptModal.show(
                    context,
                    transaction: tx,
                    user: _user!,
                    currency: 'USD',
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Debit vs Credit Leading Badge Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDebit
                                ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                : const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDebit ? Icons.shopping_bag_outlined : Icons.add_card_rounded,
                            color: isDebit ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Merchant & Entry Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Clear Debit vs Credit Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDebit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isDebit ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      isDebit ? 'DEBIT' : 'CREDIT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isDebit ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      dateDisplay,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Amount & Status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isDebit ? '-' : '+'}\$${_currencyFormat.format(amount)} USD',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDebit ? const Color(0xFFDC2626) : const Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              status,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSuccessful ? const Color(0xFF059669) : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Decline Fee Explanation Banner
                    if (tx['isDeclineFee'] == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFED7AA), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '⚠️ Declined Transaction — This payment attempt was declined due to insufficient card balance. Top up your card before retrying.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF92400E),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                    // Action Buttons: View Receipt, Download PDF, Share
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tap row to view full receipt',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Direct Download PDF Button
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                if (_user != null) {
                                  await StatementPdfService.downloadOrPrintReceipt(
                                    context,
                                    transaction: tx,
                                    user: _user!,
                                    currency: 'USD',
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PDF',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Direct Share Receipt Button
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                if (_user != null) {
                                  await StatementPdfService.shareReceipt(
                                    transaction: tx,
                                    user: _user!,
                                    currency: 'USD',
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.share_outlined, size: 12, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Share',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

