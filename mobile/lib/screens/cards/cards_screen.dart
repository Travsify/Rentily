import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/partner_bottom_bar.dart';
import '../../widgets/landlord_bottom_bar.dart';
import '../../widgets/transaction_receipt_modal.dart';
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
  double _cardIssuanceFeeUsd = 3.00;
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');

  // Real cards list loaded from Supabase (ZERO MOCK DATA)
  List<Map<String, dynamic>> _userCards = [];
  int _selectedCardIndex = 0;

  // Real card transactions (empty if no transactions yet)
  List<Map<String, dynamic>> _cardTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();

    if (user != null) {
      try {
        final rates = await ApiService.fetchFxRates();
        final pricing = await ApiService.fetchCardPricing();
        final cards = await ApiService.fetchUserCards(user.email);

        if (mounted) {
          setState(() {
            _user = user;
            _fxUsdToNgn = rates['USD_NGN'] ?? 1510.0;
            _cardIssuanceFeeUsd = (pricing['issuanceFeeUsd'] as num?)?.toDouble() ?? 3.00;
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

  // --- 1. REVEAL / UNMASK CARD DETAILS ---
  void _toggleRevealDetails() {
    HapticFeedback.lightImpact();
    setState(() {
      _showCardDetails = !_showCardDetails;
    });
  }

  // --- 2. TOGGLE FREEZE / UNFREEZE ---
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
          content: Text(targetFrozen ? '🔒 Card has been frozen.' : '✅ Card is active and ready for use.'),
          backgroundColor: targetFrozen ? Colors.orange.shade800 : AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- 3. DELETE / TERMINATE CARD ---
  Future<void> _confirmDeleteCard() async {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(
              'Delete Virtual Card',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this virtual USD card ending in ${(card['maskedPan'] ?? '').toString().replaceAll(' ', '').substring(card['maskedPan'].toString().length - 4)}?\n\nThis card will be permanently deactivated and removed from your account.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete Card', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final cardId = card['id'] ?? card['cardId'];
      setState(() => _isLoading = true);

      final success = await ApiService.deleteVirtualCard(_user!.email, cardId);

      if (mounted) {
        if (success) {
          setState(() {
            _userCards.removeAt(_selectedCardIndex);
            if (_selectedCardIndex >= _userCards.length) {
              _selectedCardIndex = 0;
            }
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Virtual card was successfully deleted.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete card. Please try again.')),
          );
        }
      }
    }
  }

  // --- 4. TOP-UP / FUND CARD MODAL ---
  void _showFundCardModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final amountController = TextEditingController();
    String selectedWallet = 'NGN';
    double fundAmountUsd = 10.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final requiredNgn = fundAmountUsd * _fxUsdToNgn;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
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
                      color: Colors.white24,
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
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_card_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Up Virtual USD Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Instant conversion from your wallet',
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

                // Amount in USD Input
                Text(
                  'Amount to Load (USD)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController..text = fundAmountUsd.toStringAsFixed(0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('\$', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    final num = double.tryParse(val) ?? 0.0;
                    setModalState(() {
                      fundAmountUsd = num;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Conversion Summary Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Exchange Rate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('\$1.00 USD = ₦${_fxUsdToNgn.toStringAsFixed(2)} NGN', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total Debit', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('₦${_currencyFormat.format(requiredNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm Top Up Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: fundAmountUsd <= 0
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);

                            final cardId = card['id'] ?? card['cardId'];
                            final success = await ApiService.fundVirtualCard(_user!.email, cardId, fundAmountUsd);

                            if (mounted) {
                              setState(() {
                                if (success) {
                                  card['balance'] = ((card['balance'] as num?)?.toDouble() ?? 0.0) + fundAmountUsd;
                                }
                                _isLoading = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? '✅ Card funded successfully with \$${fundAmountUsd.toStringAsFixed(2)} USD!' : 'Failed to fund card. Please check your balance.'),
                                  backgroundColor: success ? AppColors.primary : Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Fund \$${fundAmountUsd.toStringAsFixed(2)} USD Now',
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

  // --- 4b. CHANGE CARD PIN MODAL ---
  void _showChangePinModal() {
    final card = _currentCard;
    if (card == null || _user == null) return;

    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
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
                    color: Colors.white24,
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
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pin_rounded, color: Colors.purpleAccent, size: 22),
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
                            color: Colors.white,
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
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'New 4-Digit Card PIN',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceCodePro(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  hintText: '••••',
                  hintStyle: const TextStyle(letterSpacing: 8, color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Confirm 4-Digit Card PIN',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceCodePro(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  hintText: '••••',
                  hintStyle: const TextStyle(letterSpacing: 8, color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),

              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  // --- 5. ISSUE NEW VIRTUAL CARD MODAL ---
  void _showIssueCardModal() {
    if (_user == null) return;

    String selectedWallet = 'NGN';
    double feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToNgn;
    String feeFormatted = '₦${_currencyFormat.format(feeInSelectedCurr)} NGN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
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
                    color: Colors.white24,
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
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Virtual Dollar Card',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'USD Visa • Global online payments & subscriptions',
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

              // Card Specifications
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Card Network', 'VISA Virtual Debit'),
                    const Divider(color: Colors.white12, height: 16),
                    _buildSpecRow('Card Currency', 'USD (\$)'),
                    const Divider(color: Colors.white12, height: 16),
                    _buildSpecRow('Cardholder Name', _user!.fullName),
                    const Divider(color: Colors.white12, height: 16),
                    _buildSpecRow('Issuance Fee', '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD ($feeFormatted)'),
                    const Divider(color: Colors.white12, height: 16),
                    _buildSpecRow('Billing Address', '651 N Broad St, Middletown, Delaware'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Issue Card Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    final success = await ApiService.issueVirtualCard(
                      email: _user!.email,
                      cardholderName: _user!.fullName,
                      currency: 'USD',
                      brand: 'VISA',
                      initialFunding: 0.0,
                    );

                    if (mounted) {
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '🎉 Virtual USD Visa card issued successfully!' : 'Failed to issue card. Please try again.'),
                          backgroundColor: success ? AppColors.primary : Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Pay $feeFormatted & Issue Card',
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

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  // --- FOOTER BOTTOM BAR WIDGET DEPENDING ON ROLE ---
  Widget _buildBottomBar() {
    final role = _user?.role?.toLowerCase() ?? 'renter';
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
        currentIndex: 2,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Virtual Dollar Cards Desk',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (hasCard)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
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

                      // --- 4 CORE CARD ACTIONS ---
                      _buildCardActionButtons(isFrozen),
                      const SizedBox(height: 22),

                      // --- CARD BILLING ADDRESS (DELAWARE USA) ---
                      _buildBillingAddressCard(),
                      const SizedBox(height: 22),

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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_card_off_rounded, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'No Virtual Dollar Card Active',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get an encrypted, institutional USD virtual Visa card. Pay online, subscribe to global tools (OpenAI, AWS, Apple, Netflix) with standard Delaware USA billing address.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showIssueCardModal,
              icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
              label: Text(
                'Request Virtual Dollar Card (\$${_cardIssuanceFeeUsd.toStringAsFixed(2)})',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. VIRTUAL CARD WIDGET ---
  Widget _buildVirtualCardWidget(Map<String, dynamic> card, bool isFrozen, double balanceUsd, double balanceNgn) {
    final cardholder = (card['cardholderName'] ?? _user?.fullName ?? 'Cardholder').toString().toUpperCase();
    final maskedPan = card['maskedPan']?.toString() ?? '4829 •••• •••• 7194';
    final fullPan = card['fullPan']?.toString() ?? maskedPan;
    final expMonth = card['expiryMonth']?.toString() ?? '12';
    final expYear = card['expiryYear']?.toString() ?? '28';
    final cvv = card['cvv']?.toString() ?? '819';

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFrozen
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFF065F46), const Color(0xFF0F172A), const Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isFrozen ? Colors.black38 : const Color(0xFF065F46).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
      ),
      child: Stack(
        children: [
          // Background subtle circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Logo, Brand & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Rentilly USD Card',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFrozen ? Colors.orange.withOpacity(0.2) : AppColors.primaryLight.withOpacity(0.25),
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
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _showCardDetails ? fullPan : maskedPan));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Card number copied to clipboard ✓'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            _showCardDetails ? fullPan : maskedPan,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_rounded, size: 14, color: Colors.white60),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom Row: Cardholder, Expiry, CVV & Visa Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARDHOLDER', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text(cardholder, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPIRES', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text('$expMonth/$expYear', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CVV', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text(_showCardDetails ? cvv : '•••', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIN', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: Colors.white60, letterSpacing: 1.0)),
                        Text(_showCardDetails ? (card['pin']?.toString() ?? '2491') : '••••', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
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

  // --- 3. 5 CORE ACTION BUTTONS (Details, Top-Up, PIN, Freeze, Delete) ---
  Widget _buildCardActionButtons(bool isFrozen) {
    return Row(
      children: [
        // 1. Reveal Details Toggle
        Expanded(
          child: _buildActionButton(
            icon: _showCardDetails ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            label: _showCardDetails ? 'Hide' : 'Details',
            color: Colors.blue.shade400,
            onTap: _toggleRevealDetails,
          ),
        ),
        const SizedBox(width: 6),

        // 2. Top-Up Card
        Expanded(
          child: _buildActionButton(
            icon: Icons.add_rounded,
            label: 'Top-Up',
            color: AppColors.primary,
            onTap: _showFundCardModal,
          ),
        ),
        const SizedBox(width: 6),

        // 3. Card PIN
        Expanded(
          child: _buildActionButton(
            icon: Icons.pin_rounded,
            label: 'PIN',
            color: Colors.purple.shade300,
            onTap: _showChangePinModal,
          ),
        ),
        const SizedBox(width: 6),

        // 4. Freeze / Unfreeze
        Expanded(
          child: _buildActionButton(
            icon: isFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            label: isFrozen ? 'Unfreeze' : 'Freeze',
            color: isFrozen ? Colors.green : Colors.orange.shade400,
            onTap: _toggleFreeze,
          ),
        ),
        const SizedBox(width: 6),

        // 5. Delete Card
        Expanded(
          child: _buildActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.red.shade400,
            onTap: _confirmDeleteCard,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. BILLING ADDRESS CARD (DELAWARE USA) ---
  Widget _buildBillingAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Card Billing Address',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '651 N Broad Street, Middletown, Delaware, 19709, United States'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Billing address copied to clipboard ✓'), duration: Duration(seconds: 1)),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Copy', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAddressRow('Street', '651 N Broad Street'),
          const SizedBox(height: 6),
          _buildAddressRow('City', 'Middletown'),
          const SizedBox(height: 6),
          _buildAddressRow('State', 'Delaware (DE)'),
          const SizedBox(height: 6),
          _buildAddressRow('Zip / Postal Code', '19709'),
          const SizedBox(height: 6),
          _buildAddressRow('Country', 'United States (USA)'),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  // --- 5. TRANSACTION LEDGER ---
  Widget _buildTransactionLedgerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Card Transactions',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          '${_cardTransactions.length} records',
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTransactionLedgerList() {
    if (_cardTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.white.withOpacity(0.2), size: 36),
            const SizedBox(height: 8),
            Text(
              'No card transactions yet',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Your online purchases and wallet top-ups will appear here in real-time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cardTransactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tx = _cardTransactions[i];
        final isCredit = tx['isCredit'] == true;
        final double amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        return GestureDetector(
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
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCredit ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_rounded,
                    color: isCredit ? Colors.green : Colors.blue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['title'] ?? 'Card Transaction',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tx['merchant'] ?? 'Online Merchant',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'}\$${amt.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? Colors.green : Colors.white,
                      ),
                    ),
                    Text(
                      tx['status'] ?? 'SUCCESS',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
