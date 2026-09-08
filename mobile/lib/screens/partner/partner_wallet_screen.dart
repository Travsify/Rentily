import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../../widgets/currency_selector_widget.dart';
import '../../widgets/virtual_card_widget.dart';
import '../../widgets/transaction_receipt_modal.dart';
import '../../widgets/statement_export_modal.dart';
import '../../widgets/currency_swap_modal.dart';
import '../cards/cards_screen.dart';

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
  
  // Multi-currency vault balances (stored on-demand)
  double _usdBalance = 0.0;
  double _gbpBalance = 0.0;
  double _eurBalance = 0.0;
  String? _usdtTronAddress;
  String _activeAccountTab = 'NGN'; // 'NGN' | 'USDT'

  // Zero dummy data: Starts EMPTY until user taps 'Get Account'
  final Map<String, Map<String, String>> _virtualAccounts = {};

  // Live Dynamic FX Benchmarks & Card Pricing (Admin Configurable)
  double _fxUsdToNgn = 1510.0;
  double _fxUsdToGbp = 0.76;
  double _fxUsdToEur = 0.91;
  double _cardIssuanceFeeUsd = 3.00;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUserNotifier.value;
    _isLoading = _user == null;
    _loadUser();
    AuthService.currentUserNotifier.addListener(_onUserChanged);
    _startBalancePolling();
  }

  void _startBalancePolling() {
    _balancePoller?.cancel();
    _balancePoller = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (mounted) await _syncLiveBalance();
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
        final serverUsdtBal = (live['usdtBalance'] as num?)?.toDouble() ?? _user!.usdtBalance;
        final serverAcc = live['accountNumber']?.toString();
        final serverBank = live['bankName']?.toString();
        if (live['usdtTronAddress'] != null) {
          _usdtTronAddress = live['usdtTronAddress'].toString();
        }

        if (serverBal != _user!.walletBalance || serverUsdtBal != _user!.usdtBalance || (serverAcc != null && serverAcc != _user!.accountNumber)) {
          final updated = _user!.copyWith(
            walletBalance: serverBal,
            usdtBalance: serverUsdtBal,
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

      // Sync live Virtual Dollar Card from Supabase
      try {
        final cards = await ApiService.fetchUserCards(email);
        if (mounted) {
          setState(() {
            _cardData = cards.isNotEmpty ? cards.first : null;
          });
        }
      } catch (_) {}
    } catch (_) {}
  }

  void _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      // 0. Instantly load cached card from disk (0ms)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('rentilly_cached_cards_${user.email}');
        if (cached != null) {
          final List<dynamic> decoded = json.decode(cached);
          if (decoded.isNotEmpty && mounted && _cardData == null) {
            setState(() {
              _cardData = Map<String, dynamic>.from(decoded.first as Map);
            });
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _user = user;
        });
      }

      // Parallelize cloud requests
      final results = await Future.wait([
        ApiService.fetchPartnerCommissions(user.id, user.email),
        ApiService.fetchLiveBalance(user.email),
        ApiService.fetchLiveTransactions(user.email),
        ApiService.fetchUserCards(user.email),
      ]);

      final commissions = results[0] as Map<String, dynamic>?;
      final live = results[1] as Map<String, dynamic>?;
      final liveTxns = (results[2] as List<Map<String, dynamic>>?) ?? [];
      final cards = results[3] as List<Map<String, dynamic>>?;

      if (cards != null && cards.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rentilly_cached_cards_${user.email}', json.encode(cards));
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          if (cards != null) {
            _cardData = cards.isNotEmpty ? cards.first : null;
          }
        });
      }

      try {
        await ApiService.fetchFeatureFlags();
      } catch (_) {}

      UserProfile effectiveUser = user;
      if (live != null) {
        final serverBal = (live['walletBalance'] as num?)?.toDouble() ?? user.walletBalance;
        final serverUsdtBal = (live['usdtBalance'] as num?)?.toDouble() ?? user.usdtBalance;
        final serverAcc = live['accountNumber']?.toString();
        final serverBank = live['bankName']?.toString();
        effectiveUser = user.copyWith(
          walletBalance: serverBal,
          usdtBalance: serverUsdtBal,
          accountNumber: (serverAcc != null && serverAcc.isNotEmpty) ? serverAcc : user.accountNumber,
          bankName: (serverBank != null && serverBank.isNotEmpty) ? serverBank : user.bankName,
        );
        await AuthService.updateUser(effectiveUser);
      }

      try {
        final rates = await ApiService.fetchFxRates();
        final pricing = await ApiService.fetchCardPricing();
        if (mounted) {
          setState(() {
            _fxUsdToNgn = rates['USD_NGN'] ?? 1510.0;
            _fxUsdToGbp = (rates['GBP_NGN'] != null && rates['USD_NGN'] != null)
                ? (rates['USD_NGN']! / rates['GBP_NGN']!)
                : 0.76;
            _fxUsdToEur = (rates['EUR_NGN'] != null && rates['USD_NGN'] != null)
                ? (rates['USD_NGN']! / rates['EUR_NGN']!)
                : 0.91;
            _cardIssuanceFeeUsd = (pricing['issuanceFeeUsd'] as num?)?.toDouble() ?? 3.00;
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _user = effectiveUser;
          _escrowCommission = (commissions?['escrowBalance'] as num?)?.toDouble() ?? 0.0;
          _commissionTxns = liveTxns.isNotEmpty ? liveTxns : List<Map<String, dynamic>>.from((commissions?['transactions'] as List<dynamic>?) ?? []);
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Request foreign virtual account on explicit user request
  void _provisionAccountOnDemand(String curr) {
    HapticFeedback.heavyImpact();
    if (_user?.isVerified != true) {
      VerificationModal.show(context, onSuccess: (updated) {
        setState(() => _user = updated);
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'International $curr collection accounts require enterprise brokerage tier upgrade. Reach out via Live Support Desk. 🌐',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
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

  void _showUsdtDepositSheet() {
    if (_usdtTronAddress == null || _usdtTronAddress!.isEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.accentOrange),
                const SizedBox(height: 12),
                Text('Personal TRC20 Wallet Pending', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Your dedicated TRON (TRC20) deposit address is automatically generated once your Rentilly 9PSB Tier 1 account verification is completed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      VerificationModal.show(context, onSuccess: (updated) {
                        setState(() => _user = updated);
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('Complete KYB Verification', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    final effectiveAddress = _usdtTronAddress!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TRON (TRC20) NETWORK ONLY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF07382B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Partner USDT Deposit Address',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Send only USDT over the TRON TRC20 network. Any deposits are credited and converted to your settlement wallet at live rates.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=$effectiveAddress',
                  width: 160,
                  height: 160,
                  errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2_rounded, size: 120, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        effectiveAddress,
                        style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: effectiveAddress));
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Address copied: $effectiveAddress'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy TRC20 Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: effectiveAddress));
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Address copied: $effectiveAddress'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showCommissionSplitCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return _CommissionSplitCalculatorSheet(
              currencyFormat: _currencyFormat,
              onCopy: (summary) {
                Clipboard.setData(ClipboardData(text: summary));
                HapticFeedback.lightImpact();
                Navigator.pop(modalCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Co-Broker split breakdown copied to clipboard!'),
                    backgroundColor: Color(0xFF0F5B46),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
          },
        );
      },
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
    final String effectiveCurrency = ApiService.featureFlags.enableMultiCurrencyVault ? _selectedCurrency : 'NGN';
    final String symbol = effectiveCurrency == 'USD' ? '\$' : effectiveCurrency == 'GBP' ? '£' : effectiveCurrency == 'EUR' ? '€' : '₦';
    final double operationalBalance = effectiveCurrency == 'NGN' 
        ? (_user?.walletBalance ?? 0.0) 
        : effectiveCurrency == 'USD' 
        ? _usdBalance 
        : effectiveCurrency == 'GBP' 
        ? _gbpBalance 
        : _eurBalance;
    final escrowCommission = effectiveCurrency == 'NGN' ? _escrowCommission : 0.00;
    final accountNumber = _user?.accountNumber ?? 'Pending KYC';
    final bankName = _user?.bankName ?? '9PSB (Rentilly)';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Commissions & Escrow Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Export Statement',
            onPressed: () {
              if (_user != null) {
                StatementExportModal.show(
                  context,
                  user: _user!,
                  transactions: _commissionTxns.whereType<Map<String, dynamic>>().toList(),
                  initialCurrency: effectiveCurrency,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadUser(),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Multi-Currency Vault Switcher Tabs (Only when Multi-Currency feature is enabled)
              if (ApiService.featureFlags.enableMultiCurrencyVault) ...[
                CurrencySelectorWidget(
                  selectedCurrency: effectiveCurrency,
                  onCurrencySelected: (curr) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCurrency = curr);
                  },
                ),
                const SizedBox(height: 14),
              ],

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
                              'PARTNER OPERATING VAULT ($effectiveCurrency)',
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
                    Text('AVAILABLE OPERATING FUNDS ($effectiveCurrency)', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white60)),
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

                    // Escrow Commission Balance (Only on NGN) - Zero Spillover Layout
                    if (effectiveCurrency == 'NGN') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COMMISSIONS IN ESCROW',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.4),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₦${_currencyFormat.format(escrowCommission)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'RELEASE ON KEY HANDOVER',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
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

              // Virtual Bank Account Section (Naira = Auto upon KYC, Foreign = On-Demand 'Get Account')
              if (effectiveCurrency == 'NGN') ...[
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
                          'To comply with CBN regulations and prevent ghost brokerage accounts, your dedicated settlement Naira bank account is provisioned after completing CAC and identity verification.',
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
                          label: Text('Complete Identity Verification', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                  // Brand-Styled Currency Switcher: NGN vs USDT
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeAccountTab = 'NGN');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _activeAccountTab == 'NGN' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _activeAccountTab == 'NGN'
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🇳🇬 NGN Bank Account',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _activeAccountTab == 'NGN' ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeAccountTab = 'USDT');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _activeAccountTab == 'USDT' ? const Color(0xFF07382B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _activeAccountTab == 'USDT'
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 13,
                                    color: _activeAccountTab == 'USDT' ? const Color(0xFF00E676) : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'USDT (TRC20)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: _activeAccountTab == 'USDT' ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Display Based on Active Tab
                  if (_activeAccountTab == 'NGN') ...[
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
                                        'DEDICATED NAIRA SETTLEMENT ACCOUNT',
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
                                child: GestureDetector(
                                  onTap: () {
                                    if (_user?.accountNumber == null || _user!.accountNumber!.isEmpty) {
                                      VerificationModal.show(context, onSuccess: (updated) {
                                        setState(() => _user = updated);
                                      });
                                    }
                                  },
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
                                      if (_user?.accountNumber == null || _user!.accountNumber!.isEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentOrange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.accentOrange),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Pending 9PSB • Tap to complete KYB ⚡',
                                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_user?.accountNumber != null && _user!.accountNumber!.isNotEmpty)
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
                  ] else ...[
                    // USDT TRC20 Card with Full Options
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07382B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'TRC20',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF00E676),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TRON NETWORK WALLET',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '1 USDT ≈ ₦${_currencyFormat.format(_fxUsdToNgn)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFF00E676)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_usdtTronAddress != null && _usdtTronAddress!.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _usdtTronAddress!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.firaCode(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Auto-converted to NGN balance on deposit',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF00E676)),
                                  onPressed: () {
                                    final addr = _usdtTronAddress!;
                                    Clipboard.setData(ClipboardData(text: addr));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('USDT Address Copied: $addr', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy Address',
                                ),
                              ],
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                VerificationModal.show(context, onSuccess: (updated) {
                                  setState(() => _user = updated);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.accentOrange),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Pending KYB • Tap to Complete Verification',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white70),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Quick Actions for Partner USDT
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showUsdtDepositSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.qr_code_2_rounded, size: 13, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text('Deposit QR', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_user != null) {
                                      CurrencySwapModal.show(
                                        context,
                                        user: _user!,
                                        onSwapSuccess: (newNgn, newUsdt) => setState(() => _user = _user!.copyWith(walletBalance: newNgn, usdtBalance: newUsdt)),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.currency_exchange_rounded, size: 13, color: Color(0xFF00E676)),
                                        const SizedBox(width: 4),
                                        Text('Swap / Convert', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ] else if (ApiService.featureFlags.enableMultiCurrencyVault) ...[
                // Foreign Currency Account Card (USD / GBP / EUR) — Pure On-Demand
                if (!_virtualAccounts.containsKey(effectiveCurrency)) ...[
                  // Not Requested Yet State with 'Get Account' Button
                  Container(
                    padding: const EdgeInsets.all(18),
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
                                Text(_selectedCurrency == 'USD' ? '🇺🇸' : _selectedCurrency == 'GBP' ? '🇬🇧' : '🇪🇺', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  '$_selectedCurrency Inbound Collection Account',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Not Requested Yet',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Request a dedicated domestic $_selectedCurrency collection account to receive international direct deposits, tenancy escrow retainers, and overseas broker commissions without FX spread loss.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () => _provisionAccountOnDemand(_selectedCurrency),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Get $_selectedCurrency Account',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
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
                  ),
                ] else ...[
                  // Active Provisioned Account Card
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
                                'ACTIVE',
                                style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_user?.accountNumber == null || _user!.accountNumber!.isEmpty) {
                                    VerificationModal.show(context, onSuccess: (updated) {
                                      setState(() => _user = updated);
                                    });
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _virtualAccounts[_selectedCurrency]?['accountNumber'] ?? _virtualAccounts[_selectedCurrency]?['iban'] ?? '',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_virtualAccounts[_selectedCurrency]?['bankName']} • ${_virtualAccounts[_selectedCurrency]?['type']}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    if (_user?.accountNumber == null || _user!.accountNumber!.isEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentOrange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.accentOrange),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Pending 9PSB • Tap to complete KYB ⚡',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_user?.accountNumber != null && _user!.accountNumber!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                                onPressed: () => _copyAccount(_virtualAccounts[_selectedCurrency]?['accountNumber'] ?? _virtualAccounts[_selectedCurrency]?['iban'] ?? ''),
                                tooltip: 'Copy Coordinates',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // Wallet Quick Actions (Fund Wallet, Swap, Disburse)
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
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                      label: Text('Fund', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_user != null) {
                          CurrencySwapModal.show(
                            context,
                            user: _user!,
                            onSwapSuccess: (newNgn, newUsdt) => setState(() => _user = _user!.copyWith(walletBalance: newNgn, usdtBalance: newUsdt)),
                          );
                        }
                      },
                      icon: const Icon(Icons.currency_exchange_rounded, size: 15),
                      label: Text('Swap', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5B46),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      icon: const Icon(Icons.north_east_rounded, size: 15),
                      label: Text('Disburse', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
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

              // Virtual Dollar Card Section (Controlled Dynamically by Admin Remote Feature Flags)
              if (ApiService.featureFlags.enableVirtualCards) ...[
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Virtual Dollar Card',
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
                        (_cardData != null) ? 'Active' : 'Not Issued',
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
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.credit_card_rounded, color: Color(0xFF34D399), size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Virtual Dollar Card Issued',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Request an encrypted USD virtual Visa card instantly. Pay the card fee from your Naira, Dollar, Pound, or Euro wallet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: const Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CardsScreen()),
                              ).then((_) => _syncLiveBalance());
                            },
                            icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Open Card Desk / Issue Card',
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
                  Column(
                    children: [
                      VirtualCardWidget(
                        cardId: (_cardData!['cardId'] ?? _cardData!['id'])?.toString(),
                        cardholderName: _cardData!['cardholderName'] ?? _user?.businessName ?? _user?.fullName ?? 'Corporate Partner',
                        maskedPan: _cardData!['maskedPan'] ?? '•••• •••• •••• ••••',
                        fullPan: _cardData!['fullPan'] ?? _cardData!['pan'] ?? '',
                        expiryMonth: _cardData!['expiryMonth'] ?? '••',
                        expiryYear: _cardData!['expiryYear'] ?? '••',
                        cvv: _cardData!['cvv'] ?? '•••',
                        balance: (_cardData!['balance'] as num?)?.toDouble() ?? 0.0,
                        currency: 'USD',
                        brand: 'VISA',
                        isFrozen: _cardData!['isFrozen'] == true,
                        onFundCard: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CardsScreen()),
                          ).then((_) => _syncLiveBalance());
                        },
                        onToggleFreeze: () {
                          setState(() {
                            _cardData!['isFrozen'] = !(_cardData!['isFrozen'] == true);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardsScreen())),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                          label: Text('Open Full Cards Screen', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],

              // Co-Broker Commission Split Calculator Trigger Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Co-Broker Split Calculator 🧮',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Simulate 50/50, 60/40 & 70/30 commission splits on rents and sales.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _showCommissionSplitCalculator,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Calculate',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Transaction & Settlement History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commission Settlement Ledger',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_commissionTxns.length} Records • Tap for PDF',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_commissionTxns.isNotEmpty)
                Column(
                  children: _commissionTxns.map((tx) {
                    final isMap = tx is Map;
                    final txMap = isMap ? Map<String, dynamic>.from(tx) : <String, dynamic>{};
                    final title = isMap ? (tx['title'] ?? tx['narration'] ?? tx['description'] ?? 'Commission Payout') : 'Commission Payout';
                    final amount = isMap ? ((tx['amount'] as num?)?.toDouble() ?? 0.0).abs() : 0.0;
                    final isCredit = isMap && (tx['isCredit'] == true || (tx['type'] ?? '').toString().toLowerCase() == 'credit');
                    final date = isMap ? (tx['date'] ?? tx['createdAt'] ?? '') : '';
                    final ref = isMap ? (tx['reference'] ?? tx['id'] ?? '') : '';

                    return GestureDetector(
                      onTap: () {
                        if (_user != null) {
                          TransactionReceiptModal.show(
                            context,
                            transaction: txMap.isNotEmpty ? txMap : {'title': title, 'amount': amount, 'reference': ref, 'date': date},
                            user: _user!,
                            currency: _selectedCurrency,
                          );
                        }
                      },
                      child: Container(
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
                                      'Ref: $ref • Receipt 📄',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final txCurr = (tx['currency'] ?? '').toString().toUpperCase();
                                final titleUpper = title.toString().toUpperCase();
                                final isUsdtTx = txCurr == 'USDT' || titleUpper.contains('USDT') || titleUpper.contains('TRC20') || titleUpper.contains('TRON');
                                final isUsdTx = txCurr == 'USD' || titleUpper.contains('DOLLAR CARD') || titleUpper.contains('USD CARD') || titleUpper.contains('VIRTUAL USD');
                                final currSymbol = isUsdtTx ? '\$' : (isUsdTx ? '\$' : '₦');
                                final currSuffix = isUsdtTx ? ' USDT' : (isUsdTx ? ' USD' : '');

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isCredit ? '+' : '-'}$currSymbol${_currencyFormat.format(amount.abs())}$currSuffix',
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
                                );
                              },
                            ),
                          ],
                        ),
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

class _CommissionSplitCalculatorSheet extends StatefulWidget {
  final NumberFormat currencyFormat;
  final ValueChanged<String> onCopy;

  const _CommissionSplitCalculatorSheet({
    required this.currencyFormat,
    required this.onCopy,
  });

  @override
  State<_CommissionSplitCalculatorSheet> createState() => _CommissionSplitCalculatorSheetState();
}

class _CommissionSplitCalculatorSheetState extends State<_CommissionSplitCalculatorSheet> {
  String _dealType = 'rent'; // 'rent' or 'sale'
  final TextEditingController _amountCtrl = TextEditingController(text: '5000000');
  double _commissionRate = 10.0; // 10% rent, 5% sale
  double _splitRatio = 0.50; // 0.50 (50/50), 0.60 (60/40), 0.70 (70/30)
  bool _deductWht = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _dealType = type;
      if (type == 'rent') {
        _commissionRate = 10.0;
      } else {
        _commissionRate = 5.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dealAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final grossCommission = dealAmount * (_commissionRate / 100.0);
    final platformFeeRate = _dealType == 'rent' ? 2.5 : 2.0;
    final platformFee = dealAmount * (platformFeeRate / 100.0);
    // Agency pool available to split
    final distributablePool = (grossCommission - platformFee).clamp(0.0, double.infinity);
    final listingShare = distributablePool * _splitRatio;
    final coBrokerShare = distributablePool * (1.0 - _splitRatio);

    final listingWht = _deductWht ? listingShare * 0.05 : 0.0;
    final coBrokerWht = _deductWht ? coBrokerShare * 0.05 : 0.0;

    final listingNet = listingShare - listingWht;
    final coBrokerNet = coBrokerShare - coBrokerWht;

    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Co-Broker Commission Split',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Deal Type Toggle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _onTypeChanged('rent'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _dealType == 'rent' ? AppColors.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tenancy / Lease (Rent)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _dealType == 'rent' ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _onTypeChanged('sale'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _dealType == 'sale' ? AppColors.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Property Outright Sale',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _dealType == 'sale' ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Deal Value Input
            Text(
              'Gross Transaction Value (₦)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                hintText: 'e.g. 5,000,000',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [2500000, 5000000, 10000000, 25000000, 50000000].map((val) {
                  final label = val >= 1000000 ? '₦${(val / 1000000).toStringAsFixed(val % 1000000 == 0 ? 0 : 1)}M' : '₦$val';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() {
                          _amountCtrl.text = val.toString();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Split Ratio Selector
            Text(
              'Co-Brokerage Split Ratio',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildRatioChip('50 / 50', 'Equal Share', 0.50),
                const SizedBox(width: 8),
                _buildRatioChip('60 / 40', 'Listing Lead', 0.60),
                const SizedBox(width: 8),
                _buildRatioChip('70 / 30', 'Exclusive Mandate', 0.70),
              ],
            ),
            const SizedBox(height: 12),

            // WHT Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deduct 5% WHT (Withholding Tax)', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('FIRS / LIRS compliant agency withholding', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                  ],
                ),
                Switch.adaptive(
                  value: _deductWht,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _deductWht = val),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Detailed Settlement Breakdown Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Gross Property Value', '₦${widget.currencyFormat.format(dealAmount)}', isMuted: true),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Agency Commission (${_commissionRate.toStringAsFixed(1)}%)',
                    '₦${widget.currencyFormat.format(grossCommission)}',
                    color: const Color(0xFFFBBF24),
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Rentilly Escrow Fee (${platformFeeRate.toStringAsFixed(1)}%)',
                    '-₦${widget.currencyFormat.format(platformFee)}',
                    color: const Color(0xFFEF4444),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFF334155), height: 1),
                  ),
                  _buildSummaryRow(
                    'Net Distributable Pool',
                    '₦${widget.currencyFormat.format(distributablePool)}',
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(height: 12),

                  // Split Breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Listing Host (${(_splitRatio * 100).toInt()}%)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                            ),
                            Text(
                              '₦${widget.currencyFormat.format(listingNet)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                        if (_deductWht) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• 5% WHT deducted: ₦${widget.currencyFormat.format(listingWht)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                              Text('Gross: ₦${widget.currencyFormat.format(listingShare)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Color(0xFF334155), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Co-Broker (${((1.0 - _splitRatio) * 100).toInt()}%)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF4ADE80)),
                            ),
                            Text(
                              '₦${widget.currencyFormat.format(coBrokerNet)}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF4ADE80)),
                            ),
                          ],
                        ),
                        if (_deductWht) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• 5% WHT deducted: ₦${widget.currencyFormat.format(coBrokerWht)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                              Text('Gross: ₦${widget.currencyFormat.format(coBrokerShare)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action: Copy Agreement Breakdown
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final summary = StringBuffer();
                  summary.writeln('📋 RENTILLY CO-BROKER COMMISSION SPLIT AGREEMENT');
                  summary.writeln('Date: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}');
                  summary.writeln('Deal Type: ${_dealType == 'rent' ? 'Tenancy / Lease' : 'Outright Property Sale'}');
                  summary.writeln('Gross Deal Value: ₦${widget.currencyFormat.format(dealAmount)}');
                  summary.writeln('Agency Commission Rate: ${_commissionRate.toStringAsFixed(1)}%');
                  summary.writeln('Gross Commission Pool: ₦${widget.currencyFormat.format(grossCommission)}');
                  summary.writeln('Rentilly Escrow Platform Fee ($platformFeeRate%): ₦${widget.currencyFormat.format(platformFee)}');
                  summary.writeln('Net Distributable Pool: ₦${widget.currencyFormat.format(distributablePool)}');
                  summary.writeln('----------------------------------------');
                  summary.writeln('• Listing Partner Share (${(_splitRatio * 100).toInt()}%): ₦${widget.currencyFormat.format(listingNet)} ${_deductWht ? '(Net after 5% WHT)' : ''}');
                  summary.writeln('• Co-Broker Share (${((1.0 - _splitRatio) * 100).toInt()}%): ₦${widget.currencyFormat.format(coBrokerNet)} ${_deductWht ? '(Net after 5% WHT)' : ''}');
                  if (_deductWht) {
                    summary.writeln('Total WHT Remitted (5%): ₦${widget.currencyFormat.format(listingWht + coBrokerWht)}');
                  }
                  summary.writeln('----------------------------------------');
                  summary.writeln('Settlement Method: Rentilly Automated Escrow Vault');
                  summary.writeln('Regulatory Compliance: LASRERA & Nigerian Tenancy Code');

                  widget.onCopy(summary.toString());
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  'Copy Co-Broker Agreement Note',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5B46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioChip(String ratio, String subtitle, double val) {
    final isSelected = (_splitRatio - val).abs() < 0.01;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _splitRatio = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                ratio,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF065F46) : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  color: isSelected ? const Color(0xFF059669) : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isBold = false, bool isMuted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isMuted ? const Color(0xFF94A3B8) : Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isBold ? 13 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
