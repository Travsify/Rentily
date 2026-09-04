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
import '../../widgets/transaction_receipt_modal.dart';
import '../../widgets/statement_export_modal.dart';
import '../../widgets/currency_swap_modal.dart';
import '../cards/cards_screen.dart';
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
      if (mounted) {
        setState(() {
          _user = user;
        });
      }

      final commissions = await ApiService.fetchPartnerCommissions(user.id, user.email);
      final live = await ApiService.fetchLiveBalance(user.email);
      final liveTxns = await ApiService.fetchLiveTransactions(user.email);

      // Fetch remote feature flags
      try {
        await ApiService.fetchFeatureFlags();
      } catch (_) {}

      // Fetch live Virtual Dollar Card from Supabase
      try {
        final cards = await ApiService.fetchUserCards(user.email);
        if (mounted) {
          setState(() {
            _cardData = cards.isNotEmpty ? cards.first : null;
          });
        }
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
          _escrowCommission = (commissions['escrowBalance'] as num?)?.toDouble() ?? 0.0;
          _commissionTxns = liveTxns.isNotEmpty ? liveTxns : (commissions['transactions'] ?? []);
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Provision foreign virtual account on explicit user request
  void _provisionAccountOnDemand(String curr) {
    HapticFeedback.heavyImpact();
    setState(() {
      if (curr == 'USD') {
        _virtualAccounts['USD'] = {
          'bankName': 'Lead Bank (USA)',
          'accountNumber': '8858${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'routingNumber': '101000019',
          'type': 'US Checking (ACH / Fedwire)',
          'status': 'ACTIVE',
        };
      } else if (curr == 'GBP') {
        _virtualAccounts['GBP'] = {
          'bankName': 'ClearBank (UK)',
          'accountNumber': '7492${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
          'sortCode': '04-00-04',
          'type': 'UK Faster Payments / BACS',
          'status': 'ACTIVE',
        };
      } else if (curr == 'EUR') {
        _virtualAccounts['EUR'] = {
          'bankName': 'Banque Internationale (EU)',
          'iban': 'LU92 0019 4000 8858 ${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
          'bic': 'BILULULL',
          'type': 'SEPA & SEPA Instant (EUR)',
          'status': 'ACTIVE',
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎉 Your dedicated $curr collection account has been provisioned!',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showIssueCardModal() {
    final name = _user?.businessName ?? _user?.fullName ?? 'Corporate Partner';
    String selectedFundingWallet = 'NGN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Calculate fees depending on chosen wallet and dynamic admin pricing
          double feeInSelectedCurr = _cardIssuanceFeeUsd;
          String feeFormatted = '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD';
          double availableBalance = 0.0;
          String currSymbol = '\$';

          if (selectedFundingWallet == 'NGN') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToNgn;
            feeFormatted = '₦${_currencyFormat.format(feeInSelectedCurr)} NGN';
            availableBalance = _user?.walletBalance ?? 0.0;
            currSymbol = '₦';
          } else if (selectedFundingWallet == 'USD') {
            feeInSelectedCurr = _cardIssuanceFeeUsd;
            feeFormatted = '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD';
            availableBalance = _usdBalance;
            currSymbol = '\$';
          } else if (selectedFundingWallet == 'GBP') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToGbp;
            feeFormatted = '£${_currencyFormat.format(feeInSelectedCurr)} GBP';
            availableBalance = _gbpBalance;
            currSymbol = '£';
          } else if (selectedFundingWallet == 'EUR') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToEur;
            feeFormatted = '€${_currencyFormat.format(feeInSelectedCurr)} EUR';
            availableBalance = _eurBalance;
            currSymbol = '€';
          }

          final bool hasEnoughBalance = availableBalance >= feeInSelectedCurr;

          return Container(
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
                      'Request Virtual Dollar Card',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Provision an encrypted USD Visa debit card for global SaaS, travel, and international ad spend.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Select Funding Source Wallet
                Text(
                  'SELECT PAYMENT WALLET',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    {'curr': 'NGN', 'flag': '🇳🇬', 'bal': _user?.walletBalance ?? 0.0, 'sym': '₦'},
                    {'curr': 'USD', 'flag': '🇺🇸', 'bal': _usdBalance, 'sym': '\$'},
                    {'curr': 'GBP', 'flag': '🇬🇧', 'bal': _gbpBalance, 'sym': '£'},
                    {'curr': 'EUR', 'flag': '🇪🇺', 'bal': _eurBalance, 'sym': '€'},
                  ].map((w) {
                    final isSel = selectedFundingWallet == w['curr'];
                    final code = w['curr'] as String;
                    final flag = w['flag'] as String;
                    final bal = w['bal'] as double;
                    final sym = w['sym'] as String;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedFundingWallet = code),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark, width: isSel ? 1.5 : 1.0),
                          ),
                          child: Column(
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(code, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? AppColors.primary : AppColors.textPrimary)),
                              Text('$sym${_currencyFormat.format(bal)}', style: GoogleFonts.plusJakartaSans(fontSize: 8, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Pricing Summary Box
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
                          Text('Cardholder Name', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Card Issuance Fee', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          Text(feeFormatted, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.accentOrange)),
                        ],
                      ),
                      if (selectedFundingWallet != 'USD') ...[
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Exchange Rate', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.textMuted)),
                            Text(
                              selectedFundingWallet == 'NGN' ? '\$1.00 = ₦${_fxUsdToNgn.toStringAsFixed(0)} NGN' : selectedFundingWallet == 'GBP' ? '\$1.00 = £${_fxUsdToGbp.toStringAsFixed(2)} GBP' : '\$1.00 = €${_fxUsdToEur.toStringAsFixed(2)} EUR',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Button (Pay or Insufficient Balance)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: hasEnoughBalance
                        ? () async {
                            Navigator.pop(ctx);
                            
                            // Deduct fee from the selected wallet
                            if (selectedFundingWallet == 'NGN') {
                              final newNaira = (_user?.walletBalance ?? 0.0) - feeInSelectedCurr;
                              final updated = _user!.copyWith(walletBalance: newNaira);
                              await AuthService.updateUser(updated);
                              setState(() => _user = updated);
                            } else if (selectedFundingWallet == 'USD') {
                              setState(() => _usdBalance -= feeInSelectedCurr);
                            } else if (selectedFundingWallet == 'GBP') {
                              setState(() => _gbpBalance -= feeInSelectedCurr);
                            } else if (selectedFundingWallet == 'EUR') {
                              setState(() => _eurBalance -= feeInSelectedCurr);
                            }

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
                                  '🎉 Virtual Dollar Card activated! ($feeFormatted debited from $selectedFundingWallet wallet)',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () {
                            Navigator.pop(ctx);
                            if (_user != null) {
                              AddMoneyModal.show(context, user: _user!, onAccountUpdated: (u) => setState(() => _user = u));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasEnoughBalance ? AppColors.primary : AppColors.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      hasEnoughBalance ? 'Pay $feeFormatted & Issue Card' : 'Insufficient $selectedFundingWallet Balance — Fund Wallet',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
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
                          'To comply with CBN regulations and prevent ghost brokerage accounts, your dedicated settlement Naira bank account is provisioned after completing CAC and Tier-3 verification.',
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
