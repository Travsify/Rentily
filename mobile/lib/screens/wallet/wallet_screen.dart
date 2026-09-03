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
import '../../services/statement_pdf_service.dart';
import '../vaults/vaults_screen.dart';
import '../../widgets/add_money_modal.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/date_of_birth_modal.dart';
import '../../widgets/withdrawal_modal.dart';
import '../../widgets/currency_selector_widget.dart';
import '../../widgets/virtual_card_widget.dart';
import '../../widgets/transaction_receipt_modal.dart';
import '../../widgets/statement_export_modal.dart';
import '../../widgets/currency_swap_modal.dart';
import '../cards/cards_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  bool _hideBalance = false;
  UserProfile? _user;
  bool _isLoading = true;
  String _selectedCurrency = 'NGN';
  bool _isCardFrozen = false;
  double _cardBalance = 1250.00;
  double _fxUsdToNgn = 1510.0;
  double _fxUsdToGbp = 0.76;
  double _fxUsdToEur = 0.91;
  double _cardIssuanceFeeUsd = 3.00;
  String? _usdtTronAddress;
  String _activeAccountTab = 'NGN'; // 'NGN' | 'USDT'

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _user = AuthService.currentUserNotifier.value;
      });
    }
  }

  List<Map<String, dynamic>> _transactions = [];

  Future<void> _loadData() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = u;
        _isLoading = false;
      });
    }

    try {
      await ApiService.fetchFeatureFlags();
    } catch (_) {}

    if (u != null) {
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/wallet/balance?userId=${u.id}&email=${u.email}');
        final res = await http.get(url).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == true && data['walletBalance'] != null) {
            final double serverBal = (data['walletBalance'] as num).toDouble();
            final userData = data['user'] as Map<String, dynamic>? ?? {};
            final double serverUsdtBal = (data['usdtBalance'] as num?)?.toDouble() ?? (userData['usdtBalance'] as num?)?.toDouble() ?? 0.0;
            if (data['usdtTronAddress'] != null || userData['usdtTronAddress'] != null) {
              _usdtTronAddress = (data['usdtTronAddress'] ?? userData['usdtTronAddress']).toString();
            }
            final updated = u.copyWith(
              walletBalance: serverBal,
              usdtBalance: serverUsdtBal,
              fullName: userData['fullName']?.toString() ?? u.fullName,
              accountNumber: (userData['accountNumber']?.toString() != null && userData['accountNumber'].toString().isNotEmpty)
                  ? userData['accountNumber'].toString()
                  : u.accountNumber,
              bankName: userData['bankName']?.toString() ?? u.bankName,
              isVerified: userData['isVerified'] ?? u.isVerified,
            );
            await AuthService.updateUser(updated);
            if (mounted) setState(() => _user = updated);
          }
        }
      } catch (_) {}

      // Fetch full transactions ledger (Credits & Debits)
      try {
        final txUrl = Uri.parse('${AppConstants.apiBaseUrl}/payments/transactions?email=${u.email}');
        final txRes = await http.get(txUrl).timeout(const Duration(seconds: 8));
        if (txRes.statusCode == 200) {
          final txJson = json.decode(txRes.body);
          if (txJson['status'] == true && txJson['data'] is List) {
            if (mounted) {
              setState(() {
                _transactions = List<Map<String, dynamic>>.from(txJson['data']);
              });
            }
          }
        }
      } catch (_) {}
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

      // Fetch remote feature flags
      try {
        await ApiService.fetchFeatureFlags();
      } catch (_) {}

      // Fetch live Virtual Dollar Card from Supabase
      try {
        final cards = await ApiService.fetchUserCards(u.email);
        if (mounted) {
          setState(() {
            _cardData = cards.isNotEmpty ? cards.first : null;
          });
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic>? _cardData;

  void _showIssueCardModal() {
    final name = _user?.fullName ?? _user?.businessName ?? 'Valued Customer';
    String selectedFundingWallet = 'NGN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double feeInSelectedCurr = _cardIssuanceFeeUsd;
          String feeFormatted = '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD';
          double availableBalance = 0.0;

          if (selectedFundingWallet == 'NGN') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToNgn;
            feeFormatted = '₦${_currencyFormat.format(feeInSelectedCurr)} NGN';
            availableBalance = _user?.walletBalance ?? 0.0;
          } else if (selectedFundingWallet == 'USD') {
            feeInSelectedCurr = _cardIssuanceFeeUsd;
            feeFormatted = '\$${_cardIssuanceFeeUsd.toStringAsFixed(2)} USD';
            availableBalance = 0.0;
          } else if (selectedFundingWallet == 'GBP') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToGbp;
            feeFormatted = '£${_currencyFormat.format(feeInSelectedCurr)} GBP';
            availableBalance = 0.0;
          } else if (selectedFundingWallet == 'EUR') {
            feeInSelectedCurr = _cardIssuanceFeeUsd * _fxUsdToEur;
            feeFormatted = '€${_currencyFormat.format(feeInSelectedCurr)} EUR';
            availableBalance = 0.0;
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
                  'Provision an encrypted USD Visa debit card for global subscriptions, shopping, and international travel.',
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
                    {'curr': 'USD', 'flag': '🇺🇸', 'bal': 0.0, 'sym': '\$'},
                    {'curr': 'GBP', 'flag': '🇬🇧', 'bal': 0.0, 'sym': '£'},
                    {'curr': 'EUR', 'flag': '🇪🇺', 'bal': 0.0, 'sym': '€'},
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
                            if (selectedFundingWallet == 'NGN') {
                              final newNaira = (_user?.walletBalance ?? 0.0) - feeInSelectedCurr;
                              final updated = _user!.copyWith(walletBalance: newNaira);
                              await AuthService.updateUser(updated);
                              setState(() => _user = updated);
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
                                  '🎉 Virtual Dollar Card issued successfully! ($feeFormatted processed)',
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

  void _copyAccount() {
    final acc = _user?.accountNumber;
    if (acc == null || acc.isEmpty) {
      if (_user != null && (_user!.accountNumber == null || _user!.rekycRequired)) {
        DateOfBirthModal.show(context, user: _user!, onSuccess: (updated) {
          setState(() => _user = updated);
        });
      } else {
        VerificationModal.show(context, onSuccess: (updated) {
          setState(() => _user = updated);
        });
      }
      return;
    }
    Clipboard.setData(ClipboardData(text: acc));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account Number Copied: $acc',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
                    child: Text('Complete KYC Verification', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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
                'Deposit USDT via TRON Network',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Send only Tether USD (USDT) on the TRON (TRC20) blockchain to this address. Inbound deposits are credited to your Rentilly balance at live market exchange rates.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
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
    final String effectiveCurrency = ApiService.featureFlags.enableMultiCurrencyVault ? _selectedCurrency : 'NGN';
    final String symbol = effectiveCurrency == 'USD' ? '\$' : effectiveCurrency == 'GBP' ? '£' : effectiveCurrency == 'EUR' ? '€' : '₦';
    final double balance = effectiveCurrency == 'NGN' ? (_user?.walletBalance ?? 0.00) : 0.00;
    final String bank = effectiveCurrency == 'USD' 
        ? 'Lead Bank (USA)' 
        : effectiveCurrency == 'GBP' 
        ? 'ClearBank (UK)' 
        : effectiveCurrency == 'EUR' 
        ? 'Banque Internationale (EU)' 
        : (_user?.bankName ?? '9PSB (Rentilly)');
    final String? accNum = effectiveCurrency == 'NGN' ? _user?.accountNumber : null;
    final String accountLabel = effectiveCurrency == 'USD' 
        ? 'US CHECKING (ACH / ROUTING: 101000019)' 
        : effectiveCurrency == 'GBP' 
        ? 'UK ACCOUNT (SORT CODE: 04-00-04)' 
        : effectiveCurrency == 'EUR' 
        ? 'EUROPEAN IBAN (SEPA INSTANT)' 
        : 'DEDICATED NUBAN ACCOUNT';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Rentilly Living Wallet',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Export Statement',
            onPressed: () {
              if (_user != null) {
                StatementExportModal.show(
                  context,
                  user: _user!,
                  transactions: _transactions,
                  initialCurrency: effectiveCurrency,
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 3),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 12),
              ],

              // Main Debit Wallet Card (Emerald Teal & Deep Pine with Gold/Amber Accents)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D5C46),
                      Color(0xFF07382B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'RENTILLY GLOBAL ESCROW',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            accNum != null ? bank.toUpperCase() : 'PENDING ACTIVATION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Balance Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeAccountTab == 'USDT'
                              ? 'TOTAL AVAILABLE (USDT VAULT)'
                              : 'TOTAL AVAILABLE BALANCE ($effectiveCurrency)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        if (_activeAccountTab == 'USDT')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '1 USDT ≈ ₦${_currencyFormat.format(_fxUsdToNgn)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00E676),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _hideBalance
                              ? '$symbol • • • • • •'
                              : (_activeAccountTab == 'USDT'
                                  ? '\$${(_user?.usdtBalance ?? 0.0).toStringAsFixed(2)} USDT'
                                  : '$symbol${_currencyFormat.format(balance)}'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
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
                    if (_activeAccountTab == 'USDT' && !_hideBalance)
                      Text(
                        '≈ ₦${_currencyFormat.format((_user?.usdtBalance ?? 0.0) * 1400.0)} NGN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Brand-Styled Currency Switcher: NGN vs USDT
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                                padding: const EdgeInsets.symmetric(vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: _activeAccountTab == 'NGN' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _activeAccountTab == 'NGN'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '🇳🇬 NGN Bank',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _activeAccountTab == 'NGN' ? AppColors.primary : Colors.white.withValues(alpha: 0.8),
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
                                padding: const EdgeInsets.symmetric(vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: _activeAccountTab == 'USDT' ? const Color(0xFF00E676) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _activeAccountTab == 'USDT'
                                      ? [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 13,
                                      color: _activeAccountTab == 'USDT' ? const Color(0xFF07382B) : Colors.white.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'USDT (TRC20)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: _activeAccountTab == 'USDT' ? const Color(0xFF07382B) : Colors.white.withValues(alpha: 0.8),
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
                    const SizedBox(height: 10),

                    // Display View Based on Active Tab
                    if (_activeAccountTab == 'NGN') ...[
                      // Real NGN Account Box
                      if (accNum != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      accountLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    Text(
                                      '$accNum • $bank',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: accNum));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Account Details Copied: $accNum',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Copy',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            if (_user != null && (_user!.accountNumber == null || _user!.rekycRequired)) {
                              DateOfBirthModal.show(context, user: _user!, onSuccess: (updated) {
                                setState(() => _user = updated);
                              });
                            } else {
                              VerificationModal.show(context, onSuccess: (updated) {
                                setState(() => _user = updated);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'VIRTUAL ACCOUNT',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        'Not Generated Yet',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Activate Now',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ] else ...[
                      // USDT TRC20 Card with Full Options
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3B2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                                Expanded(
                                  child: Text(
                                    'TRON NETWORK ADDRESS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_usdtTronAddress != null && _usdtTronAddress!.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _usdtTronAddress!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      final addr = _usdtTronAddress!;
                                      Clipboard.setData(ClipboardData(text: addr));
                                      HapticFeedback.lightImpact();
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('USDT Address Copied: $addr'),
                                          backgroundColor: AppColors.primary,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF07382B)),
                                          const SizedBox(width: 3),
                                          Text(
                                            'COPY',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF07382B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                          'Pending KYC • Tap to Complete Verification',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
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
                            const SizedBox(height: 10),
                            // Quick Action Buttons for USDT
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showUsdtDepositSheet,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.qr_code_2_rounded, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Deposit QR',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_user != null) {
                                        WithdrawalModal.show(
                                          context,
                                          user: _user!,
                                          onWithdrawalSuccess: (newBal) => setState(() => _user = _user!.copyWith(walletBalance: newBal)),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.currency_exchange_rounded, size: 12, color: Color(0xFF00E676)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Swap / Convert',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
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
                ),
              ),
              const SizedBox(height: 18),

              // Wallet Actions (Add Money, Swap, Withdraw, Statement, Vault)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(Icons.add_rounded, 'Add Money', () {
                      if (_user != null) {
                        AddMoneyModal.show(
                          context,
                          user: _user!,
                          onAccountUpdated: (u) => setState(() => _user = u),
                        );
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildActionButton(Icons.currency_exchange_rounded, 'Swap', () {
                      if (_user != null) {
                        CurrencySwapModal.show(
                          context,
                          user: _user!,
                          onSwapSuccess: (newNgn, newUsdt) => setState(() => _user = _user!.copyWith(walletBalance: newNgn, usdtBalance: newUsdt)),
                        );
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildActionButton(Icons.north_east_rounded, 'Withdraw', () {
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
                    }),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildActionButton(Icons.description_outlined, 'Statement', _showStatementDialog),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildActionButton(Icons.savings_rounded, 'Vault', () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VaultsScreen()),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Rentilly Virtual Dollar Card Section (Controlled Dynamically by Admin Remote Feature Flags)
              if (ApiService.featureFlags.enableVirtualCards) ...[
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rentilly Global Dollar Card',
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
                            fontWeight: FontWeight.w800,
                            color: Colors.white, // Ultra visible white
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Issue an instant virtual debit card for global shopping, subscriptions & escrow payments.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: const Color(0xFF94A3B8), // Readable crisp slate
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
                              ).then((_) => _loadData());
                            },
                            icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Open Card Desk / Issue Card',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CardsScreen()),
                      ).then((_) => _loadData());
                    },
                    child: VirtualCardWidget(
                      cardholderName: _cardData!['cardholderName'] ?? _user?.fullName ?? 'Cardholder',
                      maskedPan: _cardData!['maskedPan'] ?? '•••• •••• •••• 0000',
                      fullPan: _cardData!['fullPan'] ?? '0000 0000 0000 0000',
                      expiryMonth: _cardData!['expiryMonth'] ?? '12',
                      expiryYear: _cardData!['expiryYear'] ?? '28',
                      cvv: _cardData!['cvv'] ?? '000',
                      balance: (_cardData!['balance'] as num?)?.toDouble() ?? 0.0,
                      currency: 'USD',
                      brand: 'VISA',
                      isFrozen: _isCardFrozen,
                      onFundCard: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CardsScreen()),
                        ).then((_) => _loadData());
                      },
                      onToggleFreeze: () {
                        setState(() => _isCardFrozen = !_isCardFrozen);
                      },
                    ),
                  ),
                const SizedBox(height: 24),
              ],

              // Actual Transaction History (Reconciled Live Flutterwave Data)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSACTION HISTORY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_user != null && _user!.walletBalance > 0)
                    Text(
                      'Tap item to download PDF receipt',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_transactions.isEmpty && (_user == null || _user!.walletBalance <= 0))
                // Empty State for Real Data
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: AppColors.backgroundDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Transactions Yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your deposits, rent savings yields, and utility token receipts will appear here in real-time.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Dynamic Transactions Ledger (Credits & Debits)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  itemBuilder: (context, i) {
                    final tx = _transactions[i];

                    final isCredit = tx['isCredit'] == true;
                    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final title = tx['title'] ?? tx['type'] ?? 'Transaction';
                    final subtitle = tx['type'] ?? (isCredit ? 'Electronic Bank Transfer • Dedicated Escrow' : 'Direct Bank Payout');

                    return InkWell(
                      onTap: () => _showTransactionReceiptSheet(tx),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCredit
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : const Color(0xFFE11D48).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                                size: 18,
                                color: isCredit ? AppColors.primary : const Color(0xFFE11D48),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? "+ " : "- "}₦${_currencyFormat.format(amt)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isCredit ? AppColors.primary : const Color(0xFFE11D48),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tx['status'] ?? 'SUCCESS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    ),
  );
}

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatementDialog() {
    if (_user == null) return;
    
    String selectedDuration = 'all_time';
    DateTime? fromDate;
    DateTime? toDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final now = DateTime.now();
          if (selectedDuration == '7_days') {
            fromDate = now.subtract(const Duration(days: 7));
          } else if (selectedDuration == '30_days') {
            fromDate = now.subtract(const Duration(days: 30));
          } else if (selectedDuration == '90_days') {
            fromDate = now.subtract(const Duration(days: 90));
          } else if (selectedDuration == 'all_time') {
            fromDate = null;
          }

          final filteredTxs = _transactions.where((tx) {
            if (fromDate == null) return true;
            if (tx['date'] == null) return true;
            final d = DateTime.tryParse(tx['date'].toString());
            if (d == null) return true;
            if (fromDate != null && d.isBefore(fromDate!.subtract(const Duration(seconds: 1)))) return false;
            if (toDate != null && d.isAfter(toDate!.add(const Duration(days: 1)))) return false;
            return true;
          }).toList();

          final dateDisplay = fromDate != null
              ? '${DateFormat('dd MMM yyyy').format(fromDate!)} - ${DateFormat('dd MMM yyyy').format(toDate ?? now)}'
              : 'All Time (Full Account History)';

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Account Statement',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select statement timeframe and download certified PDF ledger with all transactions.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                Text(
                  'SELECT STATEMENT DURATION',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDurationChip('All Time', 'all_time', selectedDuration, () {
                        setModalState(() {
                          selectedDuration = 'all_time';
                          fromDate = null;
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildDurationChip('Last 7 Days', '7_days', selectedDuration, () {
                        setModalState(() {
                          selectedDuration = '7_days';
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildDurationChip('Last 30 Days', '30_days', selectedDuration, () {
                        setModalState(() {
                          selectedDuration = '30_days';
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildDurationChip('Last 90 Days', '90_days', selectedDuration, () {
                        setModalState(() {
                          selectedDuration = '90_days';
                        });
                      }),
                      const SizedBox(width: 6),
                      _buildDurationChip('Custom Range', 'custom', selectedDuration, () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange: DateTimeRange(
                            start: now.subtract(const Duration(days: 30)),
                            end: now,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDuration = 'custom';
                            fromDate = picked.start;
                            toDate = picked.end;
                          });
                        }
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                          Text('STATEMENT TIMEFRAME', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          Text(dateDisplay, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('MATCHED TRANSACTIONS', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          Text('${filteredTxs.length} Transaction${filteredTxs.length == 1 ? '' : 's'} included', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CURRENT CLOSING BALANCE', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          Text('₦${_currencyFormat.format(_user!.walletBalance)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await StatementPdfService.shareStatement(
                            user: _user!,
                            transactions: filteredTxs,
                            fromDate: fromDate,
                            toDate: toDate,
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.primary),
                        label: Text('Share Statement', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await StatementPdfService.downloadOrPrintStatement(
                            context,
                            user: _user!,
                            transactions: filteredTxs,
                            fromDate: fromDate,
                            toDate: toDate,
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        label: Text('Download PDF', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationChip(String label, String key, String selectedKey, VoidCallback onTap) {
    final isSel = selectedKey == key;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
            color: isSel ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showTransactionReceiptSheet(Map<String, dynamic> tx) {
    if (_user == null) return;
    TransactionReceiptModal.show(
      context,
      transaction: tx,
      user: _user!,
      currency: _selectedCurrency,
    );
  }
}
