import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../../widgets/quick_utilities_modal.dart';
import '../../widgets/currency_selector_widget.dart';
import '../../widgets/virtual_card_widget.dart';
import '../bills/bills_screen.dart';

class PartnerWalletScreen extends StatefulWidget {
  const PartnerWalletScreen({super.key});

  @override
  State<PartnerWalletScreen> createState() => _PartnerWalletScreenState();
}

class _PartnerWalletScreenState extends State<PartnerWalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;
  bool _isSyncing = false;
  double _escrowCommission = 0.0;
  List<dynamic> _commissionTxns = [];
  Timer? _balancePoller;
  String _selectedCurrency = 'NGN';
  bool _hideBalance = false;
  Map<String, dynamic>? _cardData;
  final Map<String, Map<String, String>> _virtualAccounts = {
    'USD': {
      'bankName': 'Lead Bank (USA)',
      'accountNumber': '8858607609',
      'routingNumber': '101000019',
      'type': 'US Checking (ACH / Fedwire)',
      'status': 'ACTIVE',
    },
    'GBP': {
      'bankName': 'ClearBank (UK)',
      'accountNumber': '74920481',
      'sortCode': '04-00-04',
      'type': 'UK Faster Payments / BACS',
      'status': 'ACTIVE',
    },
    'EUR': {
      'bankName': 'Banque Internationale (EU)',
      'iban': 'LU92 0019 4000 8858 6076',
      'bic': 'BILULULL',
      'type': 'SEPA & SEPA Instant (EUR)',
      'status': 'ACTIVE',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
    AuthService.currentUserNotifier.addListener(_onUserChanged);
    _startBalancePolling();
  }

  void _startBalancePolling() {
    _balancePoller?.cancel();
    _balancePoller = Timer.periodic(const Duration(seconds: 6), (_) async {
      await _syncLiveBalance();
    });
  }

  void _onUserChanged() {
    if (mounted) {
      final updated = AuthService.currentUserNotifier.value;
      if (updated != null) {
        setState(() => _user = updated);
      }
    }
  }

  @override
  void dispose() {
    _balancePoller?.cancel();
    AuthService.currentUserNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  Future<void> _syncLiveBalance() async {
    if (!mounted || _user == null) return;
    final email = _user!.email;
    if (email.isEmpty) return;

    try {
      final live = await ApiService.fetchLiveBalance(email);
      final liveTxns = await ApiService.fetchLiveTransactions(email);
      if (!mounted) return;

      if (live != null) {
        final serverBal = (live['walletBalance'] as num?)?.toDouble() ?? _user!.walletBalance;
        final serverAcc = live['accountNumber']?.toString();
        final serverBank = live['bankName']?.toString();

        if (serverBal != _user!.walletBalance || (serverAcc != null && serverAcc != _user!.accountNumber)) {
          final updated = _user!.copyWith(
            walletBalance: serverBal,
            accountNumber: (serverAcc != null && serverAcc.isNotEmpty) ? serverAcc : _user!.accountNumber,
            bankName: (serverBank != null && serverBank.isNotEmpty) ? serverBank : _user!.bankName,
          );
          await AuthService.updateUser(updated);
          if (mounted) {
            setState(() {
              _user = updated;
              if (liveTxns.isNotEmpty) _commissionTxns = liveTxns;
            });
          }
        } else if (liveTxns.isNotEmpty && mounted) {
          setState(() {
            _commissionTxns = liveTxns;
          });
        }
      }
    } catch (_) {}
  }

  void _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _user = user;
        });
      }

      final commissions = await ApiService.fetchPartnerCommissions(user.id, user.email);
      final live = await ApiService.fetchLiveBalance(user.email);
      final liveTxns = await ApiService.fetchLiveTransactions(user.email);

      UserProfile effectiveUser = user;
      if (live != null) {
        final serverBal = (live['walletBalance'] as num?)?.toDouble() ?? user.walletBalance;
        final serverAcc = live['accountNumber']?.toString();
        final serverBank = live['bankName']?.toString();
        effectiveUser = user.copyWith(
          walletBalance: serverBal,
          accountNumber: (serverAcc != null && serverAcc.isNotEmpty) ? serverAcc : user.accountNumber,
          bankName: (serverBank != null && serverBank.isNotEmpty) ? serverBank : user.bankName,
        );
        await AuthService.updateUser(effectiveUser);
      }

      if (mounted) {
        setState(() {
          _user = effectiveUser;
          _escrowCommission = (commissions['escrowBalance'] as num?)?.toDouble() ?? 0.0;
          _commissionTxns = liveTxns.isNotEmpty ? liveTxns : (commissions['transactions'] ?? []);
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showIssueCardModal() {
    final name = _user?.businessName ?? _user?.fullName ?? 'Corporate Partner';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Issue Global Virtual Card',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your corporate virtual card will be provisioned instantly through Bridgecard CaaS in USD currency with institutional-grade encryption for global SaaS, international travel & marketing.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cardholder / Entity', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Currency / Type', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('USD • Virtual Visa', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Card Issuance Fee', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('\$3.00 (₦4,550)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _cardData = {
                      'cardholderName': name,
                      'maskedPan': '4829 •••• •••• 7194',
                      'fullPan': '4829 9102 3847 7194',
                      'expiryMonth': '08',
                      'expiryYear': '29',
                      'cvv': '819',
                      'balance': 0.0,
                    };
                  });
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 Corporate Virtual Dollar Card activated! (\$3.00 fee processed)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Pay \$3.00 & Activate Card',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _copyAccount(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account Coordinates $accountNumber copied! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _requestVirtualAccountModal(String curr) {
    final flag = curr == 'USD' ? '🇺🇸' : curr == 'GBP' ? '🇬🇧' : '🇪🇺';
    final name = curr == 'USD' ? 'US Dollar (ACH & Fedwire)' : curr == 'GBP' ? 'British Pound (Faster Payments)' : 'Euro (SEPA IBAN)';
    final bank = curr == 'USD' ? 'Lead Bank (USA)' : curr == 'GBP' ? 'ClearBank (UK)' : 'Banque Internationale (EU)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$flag Dedicated $curr Virtual Account',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Provision institutional domestic banking coordinates with $bank to receive cross-border diaspora rent, tenancy retainers, and broker commissions.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collection Rail', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Settlement Speed', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('Instant / Same-Day', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Activation Fee', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                      Text('FREE (CAC Accredited)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 $curr Inbound Account activated successfully!',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Provision $curr Virtual Account Now',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isVerified = _user?.isVerified ?? false;
    final String symbol = _selectedCurrency == 'USD' ? '\$' : _selectedCurrency == 'GBP' ? '£' : _selectedCurrency == 'EUR' ? '€' : '₦';
    final double operationalBalance = _selectedCurrency == 'NGN' ? (_user?.walletBalance ?? 0.0) : 0.00;
    final escrowCommission = _selectedCurrency == 'NGN' ? _escrowCommission : 0.00;
    final accountNumber = _user?.accountNumber ?? 'Pending KYC';
    final bankName = _user?.bankName ?? 'Flutterwave MFB';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Commissions & Escrow Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadUser(),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Multi-Currency Vault Switcher Tabs
              CurrencySelectorWidget(
                selectedCurrency: _selectedCurrency,
                onCurrencySelected: (curr) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCurrency = curr);
                },
              ),
              const SizedBox(height: 14),

              // Dual Balance Card (Operational Balance vs Escrow Commission Balance)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                            const Icon(Icons.business_center_rounded, size: 16, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              'PARTNER OPERATING VAULT ($_selectedCurrency)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFF22C55E).withValues(alpha: 0.2) : AppColors.accentOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange),
                          ),
                          child: Text(
                            isVerified ? 'CAC ACCREDITED 🛡️' : 'TIER 1 (UNVERIFIED)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isVerified ? const Color(0xFF4ADE80) : AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operational Funded Balance
                    Text('AVAILABLE OPERATING FUNDS ($_selectedCurrency)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('$symbol${_currencyFormat.format(operationalBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: () => setState(() => _hideBalance = !_hideBalance),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Divider
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),

                    // Escrow Commission Balance (Only on NGN)
                    if (_selectedCurrency == 'NGN') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('COMMISSIONS IN ESCROW (2.5% RENT / 2.0% SALE)', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                              const SizedBox(height: 2),
                              Text('₦${_currencyFormat.format(escrowCommission)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'RELEASES ON KEY HANDOVER',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CROSS-BORDER SETTLEMENT', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                          Text('ZERO FX SPREAD LOSS', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Virtual Bank Account Section (Dynamic per Currency)
              if (_selectedCurrency == 'NGN') ...[
                if (!isVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 20, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            Text(
                              'CAC & Identity Verification Required',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'To comply with CBN regulations and prevent ghost brokerage accounts, dedicated settlement bank accounts are only provisioned after completing CAC and Tier-3 BVN/NIN verification.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF78350F), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            VerificationModal.show(context, onSuccess: (updated) {
                              setState(() => _user = updated);
                            });
                          },
                          icon: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
                          label: Text('Complete Tier-3 KYC Verification', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB45309),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderDark),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'DEDICATED COMMISSIONS ACCOUNT',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Text(
                                'AUTOMATED SETTLEMENT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accountNumber,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$bankName • Direct Tenancy Inflows',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                              onPressed: () => _copyAccount(accountNumber),
                              tooltip: 'Copy Account Number',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Foreign Currency Account Card (USD / GBP / EUR)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                              const Icon(Icons.public_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'DEDICATED $_selectedCurrency INBOUND VAULT',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              'KORAPAY GLOBAL RAILS',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _virtualAccounts[_selectedCurrency]?['accountNumber'] ?? _virtualAccounts[_selectedCurrency]?['iban'] ?? 'Coordinates Active',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_virtualAccounts[_selectedCurrency]?['bankName']} • ${_virtualAccounts[_selectedCurrency]?['type']}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _copyAccount(_virtualAccounts[_selectedCurrency]?['accountNumber'] ?? _virtualAccounts[_selectedCurrency]?['iban'] ?? ''),
                            tooltip: 'Copy Coordinates',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: () => _requestVirtualAccountModal(_selectedCurrency),
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                          label: Text('Request Custom $_selectedCurrency Coordinates', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Wallet Quick Actions (Add Money, Withdraw, Utilities, KYC)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_user != null) {
                          AddMoneyModal.show(
                            context,
                            user: _user!,
                            onAccountUpdated: (u) => setState(() => _user = u),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text('Fund Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_user == null || !_user!.isVerified) {
                          VerificationModal.show(context, onSuccess: (updated) {
                            setState(() => _user = updated);
                          });
                          return;
                        }
                        WithdrawalModal.show(
                          context,
                          user: _user!,
                          onWithdrawalSuccess: (newBal) {
                            setState(() => _user = _user!.copyWith(walletBalance: newBal));
                          },
                        );
                      },
                      icon: const Icon(Icons.north_east_rounded, size: 16),
                      label: Text('Disburse Funds', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Virtual Dollar Card Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Corporate Virtual Dollar Card',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: (_cardData != null) ? AppColors.primaryLight.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (_cardData != null) ? 'Bridgecard Active' : 'Not Issued',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: (_cardData != null) ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_cardData == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Virtual Dollar Card Issued',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Issue an encrypted USD virtual debit card instantly via Bridgecard CaaS for global payments, ad spend, and SaaS.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _showIssueCardModal,
                          icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.white),
                          label: Text(
                            '+ Issue Virtual Dollar Card (\$3.00)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                VirtualCardWidget(
                  cardholderName: _cardData!['cardholderName'] ?? 'Corporate Partner',
                  maskedPan: _cardData!['maskedPan'] ?? '4829 •••• •••• 7194',
                  fullPan: _cardData!['fullPan'] ?? '4829 9102 3847 7194',
                  expiryMonth: _cardData!['expiryMonth'] ?? '08',
                  expiryYear: _cardData!['expiryYear'] ?? '29',
                  cvv: _cardData!['cvv'] ?? '819',
                  balance: (_cardData!['balance'] as num?)?.toDouble() ?? 0.0,
                  currency: 'USD',
                  brand: 'VISA',
                  isFrozen: _cardData!['isFrozen'] == true,
                  onFundCard: () {},
                  onToggleFreeze: () {
                    setState(() {
                      _cardData!['isFrozen'] = !(_cardData!['isFrozen'] == true);
                    });
                  },
                ),
              const SizedBox(height: 24),

              // Transaction & Settlement History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commission Settlement Ledger',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_commissionTxns.length} Records',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_commissionTxns.isNotEmpty)
                Column(
                  children: _commissionTxns.map((tx) {
                    final isMap = tx is Map;
                    final title = isMap ? (tx['title'] ?? tx['description'] ?? 'Commission Payout') : 'Commission Payout';
                    final amount = isMap ? ((tx['amount'] as num?)?.toDouble() ?? 0.0) : 0.0;
                    final isCredit = amount >= 0;
                    final date = isMap ? (tx['date'] ?? tx['createdAt'] ?? '') : '';
                    final ref = isMap ? (tx['reference'] ?? tx['id'] ?? '') : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isCredit ? const Color(0xFF16A34A) : Colors.red).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isCredit ? const Color(0xFF16A34A) : Colors.red,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (ref.isNotEmpty)
                                  Text(
                                    'Ref: $ref',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isCredit ? '+' : '-'}₦${_currencyFormat.format(amount.abs())}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isCredit ? const Color(0xFF16A34A) : Colors.red,
                                ),
                              ),
                              if (date.isNotEmpty)
                                Text(
                                  date.length > 10 ? date.substring(0, 10) : date,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.history_rounded, size: 32, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text('No Recent Commission Settlements', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('When tenants complete rent payment and move-in key handover, 2.5% rent and 2.0% sale commission payouts appear here.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
