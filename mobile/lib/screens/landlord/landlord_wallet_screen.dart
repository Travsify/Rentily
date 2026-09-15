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
import '../../widgets/transaction_receipt_modal.dart';
import '../../widgets/statement_export_modal.dart';
import '../../widgets/currency_swap_modal.dart';
import '../../widgets/virtual_card_widget.dart';
import '../cards/cards_screen.dart';
import '../bills/bills_screen.dart';

class LandlordWalletScreen extends StatefulWidget {
  const LandlordWalletScreen({super.key});

  @override
  State<LandlordWalletScreen> createState() => _LandlordWalletScreenState();
}

class _LandlordWalletScreenState extends State<LandlordWalletScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');
  UserProfile? _user;
  bool _isLoading = true;
  String _selectedLedgerFilter = 'All';
  String _selectedCurrency = 'NGN';
  bool _isCardFrozen = false;
  double _escrowBalance = 0.0;
  String? _usdtTronAddress;
  String _activeAccountTab = 'DAILY'; // 'DAILY' (NGN) | 'USDT' (TRC20)
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _cardData;

  // Live balance polling — fires every 8 seconds
  Timer? _balancePoller;
  double _lastKnownBalance = 0;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUserNotifier.value;
    _isLoading = _user == null;
    _lastKnownBalance = _user?.walletBalance ?? 0;
    _loadUserAndTransactions();
    AuthService.currentUserNotifier.addListener(_onUserUpdated);
    // Start polling after first load settles
    Future.delayed(const Duration(seconds: 5), _startBalancePolling);
  }

  @override
  void dispose() {
    _balancePoller?.cancel();
    AuthService.currentUserNotifier.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _startBalancePolling() {
    _balancePoller?.cancel();
    _balancePoller = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (mounted) await _syncLiveBalance();
    });
  }

  /// Polls /wallet/balance; if balance increased, updates UI immediately and shows toast.
  Future<void> _syncLiveBalance() async {
    if (!mounted || _user == null) return;
    final email = _user!.email;
    if (email.isEmpty) return;
    try {
      final live = await ApiService.fetchLiveBalance(email);
      if (live == null || !mounted) return;
      final liveBalance = (live['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final liveUsdt = (live['usdtBalance'] as num?)?.toDouble() ?? 0.0;
      final liveAccNo = live['accountNumber']?.toString() ?? _user!.accountNumber;
      final liveTronAddr = live['usdtTronAddress']?.toString();
      if (liveTronAddr != null && liveTronAddr.isNotEmpty) {
        _usdtTronAddress = liveTronAddr;
      }
      if (liveBalance != _lastKnownBalance || liveUsdt != _user!.usdtBalance) {
        final isGain = liveBalance > _lastKnownBalance;
        final diff = (liveBalance - _lastKnownBalance).abs();
        _lastKnownBalance = liveBalance;
        final updated = _user!.copyWith(
          walletBalance: liveBalance,
          usdtBalance: liveUsdt,
          accountNumber: liveAccNo,
        );
        await AuthService.updateUser(updated);
        if (mounted) {
          setState(() => _user = updated);
          await _loadTransactions();
          if (mounted && isGain && diff > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '💰 +₦${_currencyFormat.format(diff)} received! Balance updated.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  void _onUserUpdated() {
    if (mounted) {
      setState(() {
        _user = AuthService.currentUserNotifier.value;
      });
      _loadTransactions();
    }
  }

  void _loadUserAndTransactions() async {
    final user = await AuthService.getCurrentUser();
    await _loadTransactions();
    try {
      await ApiService.fetchFeatureFlags();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _user = user;
        _lastKnownBalance = user?.walletBalance ?? 0;
        _isLoading = false;
      });
    }
    if (user != null) {
      try {
        final live = await ApiService.fetchLiveBalance(user.email);
        final escrowSummary = await ApiService.fetchLandlordEscrowSummary(email: user.email, ownerId: user.id);
        final liveEscrow = (escrowSummary['totalEscrowVolume'] as num?)?.toDouble() ??
                           (escrowSummary['activeEscrowBalance'] as num?)?.toDouble() ?? 0.0;
        if (live != null && mounted) {
          final serverBal = (live['walletBalance'] as num?)?.toDouble() ?? user.walletBalance;
          final serverUsdtBal = (live['usdtBalance'] as num?)?.toDouble() ?? user.usdtBalance;
          final liveTronAddr = live['usdtTronAddress']?.toString();
          if (liveTronAddr != null && liveTronAddr.isNotEmpty) {
            _usdtTronAddress = liveTronAddr;
          }
          final updated = user.copyWith(walletBalance: serverBal, usdtBalance: serverUsdtBal);
          await AuthService.updateUser(updated);
          setState(() {
            _user = updated;
            _lastKnownBalance = serverBal;
            _escrowBalance = liveEscrow;
          });
        }
      } catch (_) {}

      try {
        final cards = await ApiService.fetchUserCards(user.email);
        if (mounted) {
          setState(() {
            _cardData = cards.isNotEmpty ? cards.first : null;
          });
        }
      } catch (_) {}
    }
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
                  'Your dedicated TRON (TRC20) deposit address is automatically generated once your Rentilly Tier 1 account verification is completed.',
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

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await AuthService.getCurrentUser();
    final email = user?.email ?? '';
    final acc = user?.accountNumber ?? '';

    // 1. Load local cached transactions
    final savedTxnsJson = prefs.getString('rentilly_landlord_transactions');
    if (savedTxnsJson != null) {
      try {
        _transactions = List<Map<String, dynamic>>.from(json.decode(savedTxnsJson));
      } catch (_) {}
    }

    // 2. Fetch live transactions from Rentilly Backend Server
    try {
      final liveTxns = await ApiService.fetchLiveTransactions(email);
      if (liveTxns.isNotEmpty) {
        final List<Map<String, dynamic>> parsedLive = [];
        for (var t in liveTxns) {
          final isCredit = t['isCredit'] == true || (t['type'] ?? '').toString().toLowerCase() == 'credit';
          final amt = ((t['amount'] as num?)?.toDouble() ?? 0.0).abs();
          final signedAmount = isCredit ? amt : -amt;
          final statusRaw = (t['status'] ?? 'SUCCESSFUL').toString().toUpperCase();
          final status = (statusRaw == 'SUCCESSFUL' || statusRaw == 'SUCCESS' || statusRaw == 'COMPLETED') ? 'Completed' :
                         (statusRaw == 'PENDING' ? 'Processing' : (statusRaw == 'FAILED' ? 'Failed' : statusRaw));

          final subtitle = (t['subtitle'] != null && t['subtitle'].toString().isNotEmpty)
              ? t['subtitle'].toString()
              : (t['sender'] != null && t['sender'].toString().isNotEmpty
                  ? 'From: ${t['sender']}'
                  : (t['beneficiary'] != null && t['beneficiary'].toString().isNotEmpty
                      ? 'To: ${t['beneficiary']}'
                      : (acc.isNotEmpty ? 'Direct Settlement ($acc)' : 'Direct Settlement')));

          parsedLive.add({
            'id': t['id'] ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
            'title': t['title'] ?? (isCredit ? 'Wallet Inbound Deposit' : 'Outbound Payment'),
            'subtitle': subtitle,
            'amount': signedAmount,
            'type': isCredit ? 'inflow' : 'outflow',
            'isCredit': isCredit,
            'status': status,
            'date': t['date'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(t['date']) ?? DateTime.now()) : 'Today',
            'reference': t['reference'] ?? t['id'] ?? 'REF-${DateTime.now().millisecondsSinceEpoch}',
            'channel': t['category'] == 'utility' ? 'Utility Bills Service' : 'Direct Bank Settlement',
            'session': 'SES-${t['reference'] ?? DateTime.now().millisecondsSinceEpoch}',
            'description': t['description'],
            'narration': t['narration'],
            'beneficiary': t['beneficiary'],
            'recipientAccount': t['recipientAccount'],
            'recipientBank': t['recipientBank'],
            'currency': t['currency'] ?? 'NGN',
            'fee': t['fee'],
          });
        }
        if (parsedLive.isNotEmpty) {
          _transactions = parsedLive;
          await prefs.setString('rentilly_landlord_transactions', json.encode(_transactions));
        }
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  void _copyAccount(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account Number $accountNumber copied! 📋', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- 1. SHOW TRANSACTION RECEIPT MODAL ---
  void _showTransactionReceiptModal(BuildContext context, Map<String, dynamic> txn) {
    if (_user == null) return;
    TransactionReceiptModal.show(
      context,
      transaction: txn,
      user: _user!,
      currency: _selectedCurrency,
    );
  }

  // --- 2. DOWNLOAD / EXPORT FULL ACCOUNT STATEMENT PDF ---
  void _downloadStatement() {
    if (_user == null) return;
    StatementExportModal.show(
      context,
      user: _user!,
      transactions: _transactions,
      initialCurrency: _selectedCurrency,
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

    final isVerified = _user?.isVerified ?? true;
    final name = _user?.fullName ?? _user?.businessName ?? 'Property Owner';
    final String effectiveCurrency = ApiService.featureFlags.enableMultiCurrencyVault ? _selectedCurrency : 'NGN';
    final String symbol = effectiveCurrency == 'USD' ? '\$' : effectiveCurrency == 'GBP' ? '£' : effectiveCurrency == 'EUR' ? '€' : '₦';
    final double operationalBalance = effectiveCurrency == 'NGN' ? (_user?.walletBalance ?? 0.0) : 0.00;
    final escrowBalance = _escrowBalance;
    final accountNumber = effectiveCurrency == 'NGN' ? (_user?.accountNumber ?? '') : '';
    final rawBank = _user?.bankName ?? 'Wema Bank';
    final cleanBank = rawBank.replaceAll(RegExp(r'\s*\([Ff]incra\)', caseSensitive: false), '').replaceAll(RegExp(r'Fincra\s*', caseSensitive: false), '').trim();
    final bankName = effectiveCurrency == 'USD' 
        ? 'Lead Bank (USA) • ACH/Wire' 
        : effectiveCurrency == 'GBP' 
        ? 'ClearBank (UK) • Sort: 04-00-04' 
        : effectiveCurrency == 'EUR' 
        ? 'Banque Internationale (EU)' 
        : cleanBank;
    final String accountLabel = effectiveCurrency == 'USD' 
        ? 'US CHECKING (ACH / ROUTING: 101000019)' 
        : effectiveCurrency == 'GBP' 
        ? 'UK ACCOUNT (SORT CODE: 04-00-04)' 
        : effectiveCurrency == 'EUR' 
        ? 'EUROPEAN IBAN (SEPA INSTANT)' 
        : 'DEDICATED SETTLEMENT NUBAN';

    final filteredTransactions = _selectedLedgerFilter == 'All'
        ? _transactions
        : _selectedLedgerFilter == 'Inflows'
            ? _transactions.where((t) => (t['amount'] as double) > 0).toList()
            : _selectedLedgerFilter == 'Outflows'
                ? _transactions.where((t) => (t['amount'] as double) < 0).toList()
                : _transactions.where((t) => t['type'] == 'escrow').toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Settlement & Escrow Vault',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: AppColors.primary),
            onPressed: _downloadStatement,
            tooltip: 'Download Statement',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _loadUserAndTransactions();
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Multi-Currency Vault Switcher (Only when enabled)
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

              // 1. Multi-Vault Switcher Tab: Dedicated NGN vs USDT TRC20 Crypto
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeAccountTab = 'DAILY');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeAccountTab == 'DAILY' ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🇳🇬', style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  'NGN Escrow Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _activeAccountTab == 'DAILY' ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeAccountTab = 'USDT');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeAccountTab == 'USDT' ? const Color(0xFF0F5B46) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('₮', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: _activeAccountTab == 'USDT' ? Colors.white : const Color(0xFF0F5B46))),
                                const SizedBox(width: 6),
                                Text(
                                  'USDT TRC20 Vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _activeAccountTab == 'USDT' ? Colors.white : AppColors.textSecondary,
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
              ),

              // 2. Dual Balance Card (Styled in Rentilly Brand Green with Emerald & Gold Accents)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _activeAccountTab == 'USDT'
                        ? const [Color(0xFF064E3B), Color(0xFF065F46)]
                        : const [Color(0xFF064E3B), Color(0xFF042F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.35), width: 1.2),
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
                            Icon(
                              _activeAccountTab == 'USDT' ? Icons.currency_bitcoin_rounded : Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _activeAccountTab == 'USDT'
                                  ? 'LANDLORD USDT TRC20 CRYPTO VAULT'
                                  : 'LANDLORD GLOBAL VAULT ($effectiveCurrency)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF4ADE80),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4ADE80)),
                          ),
                          child: Text(
                            _activeAccountTab == 'USDT' ? 'TRON (TRC20)' : 'VERIFIED VAULT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operational Funded Balance / USDT Balance
                    Text(
                      _activeAccountTab == 'USDT' ? 'AVAILABLE CRYPTO BALANCE (USDT)' : 'AVAILABLE OPERATING FUNDS ($effectiveCurrency)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeAccountTab == 'USDT'
                          ? '\$${(_user?.usdtBalance ?? 0.0).toStringAsFixed(2)} USDT'
                          : '$symbol${_currencyFormat.format(operationalBalance)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    if (_activeAccountTab == 'USDT') ...[
                      const SizedBox(height: 2),
                      Text(
                        '≈ ₦${_currencyFormat.format((_user?.usdtBalance ?? 0.0) * 1510.0)} NGN • 1 USDT ≈ ₦1,510.00',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4ADE80)),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Divider
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),

                    // Escrow Balance (Rent & Sales Proceeds)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE SETTLEMENT\nFUNDS IN ESCROW',
                                style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₦${_currencyFormat.format(escrowBalance)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RELEASES ON\nKEY CONFIRM',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFFFBBF24)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Vault Account Detail (Dedicated NUBAN vs USDT TRC20 Address)
              if (_activeAccountTab == 'USDT') ...[
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF0F5B46)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'DEDICATED USDT (TRC20) DEPOSIT ADDRESS',
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TRON NETWORK',
                              style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
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
                                  _usdtTronAddress != null && _usdtTronAddress!.isNotEmpty
                                      ? '${_usdtTronAddress!.substring(0, 10)}...${_usdtTronAddress!.substring(_usdtTronAddress!.length - 8)}'
                                      : (_user?.isVerified == true ? 'Generating TRC20 Address...' : 'Complete KYC to Activate'),
                                  style: GoogleFonts.firaCode(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send only USDT on TRON (TRC20) blockchain',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                            onPressed: () {
                              if (_usdtTronAddress != null && _usdtTronAddress!.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: _usdtTronAddress!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('USDT TRC20 Address Copied: ${_usdtTronAddress!}'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              } else {
                                _showUsdtDepositSheet();
                              }
                            },
                            tooltip: 'Copy TRC20 Address',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showUsdtDepositSheet,
                              icon: const Icon(Icons.qr_code_rounded, size: 14, color: Colors.white),
                              label: Text('Deposit (QR)', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5B46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  CurrencySwapModal.show(
                                    context,
                                    user: _user!,
                                    onSwapSuccess: (newNgn, newUsdt) async {
                                      setState(() => _user = _user!.copyWith(walletBalance: newNgn, usdtBalance: newUsdt));
                                      await _loadTransactions();
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.currency_exchange_rounded, size: 13, color: Colors.white),
                              label: Text('Swap to NGN', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  WithdrawalModal.show(
                                    context,
                                    user: _user!,
                                    onWithdrawalSuccess: (newBal, [newTx]) async {
                                      setState(() {
                                        _user = _user!.copyWith(walletBalance: newBal);
                                        if (newTx != null) {
                                          _transactions.insert(0, newTx);
                                        }
                                      });
                                      await _loadTransactions();
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.north_east_rounded, size: 14, color: AppColors.primary),
                              label: Text('Withdraw', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Virtual Bank Account Section (Rentilly Brand Green Accent)
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              accountLabel,
                              style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AUTO\nSETTLE',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
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
                                Text(accountNumber.isNotEmpty ? accountNumber : (_user?.isVerified == true ? 'Generating NUBAN...' : 'Pending Verification'), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                                Text(
                                  '$bankName • $name / Rentilly',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  AddMoneyModal.show(context, user: _user!, onAccountUpdated: (u) async {
                                    setState(() => _user = u);
                                    await _loadTransactions();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                              label: Text('Fund', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  CurrencySwapModal.show(
                                    context,
                                    user: _user!,
                                    onSwapSuccess: (newNgn, newUsdt) async {
                                      setState(() => _user = _user!.copyWith(walletBalance: newNgn, usdtBalance: newUsdt));
                                      await _loadTransactions();
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.currency_exchange_rounded, size: 13, color: Colors.white),
                              label: Text('Swap', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5B46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_user != null) {
                                  WithdrawalModal.show(
                                    context,
                                    user: _user!,
                                    onWithdrawalSuccess: (newBal, [newTx]) async {
                                      setState(() {
                                        _user = _user!.copyWith(walletBalance: newBal);
                                        if (newTx != null) {
                                          _transactions.insert(0, newTx);
                                        }
                                      });
                                      await _loadTransactions();
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.north_east_rounded, size: 14, color: AppColors.primary),
                              label: Text('Withdraw', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              // Rentilly Landlord Virtual Dollar Card (Controlled Dynamically by Admin Remote Feature Flags)
              if (ApiService.featureFlags.enableVirtualCards) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Landlord Virtual Dollar Card',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardsScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Open Cards Desk',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_cardData != null)
                  Column(
                    children: [
                      VirtualCardWidget(
                        cardId: (_cardData!['cardId'] ?? _cardData!['id'])?.toString(),
                        cardholderName: _cardData!['cardholderName'] ?? _user?.fullName ?? 'PATRICK ACHUA',
                        maskedPan: _cardData!['maskedPan'] ?? '•••• •••• •••• ••••',
                        fullPan: _cardData!['fullPan'] ?? '',
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
                  )
                else
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardsScreen()));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.credit_card_rounded, color: Color(0xFF38BDF8), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '3D-Secure Virtual Visa Dollar Card',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Issue & fund virtual USD cards for international SaaS, building maintenance & supplies.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.white70,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF38BDF8)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],

              // Unit Utilities & Maintenance Pod
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UNIT UTILITIES & MAINTENANCE',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                  ),
                  Text(
                    'INSTANT DISPATCH',
                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    _buildUtilityButton(
                      Icons.electric_bolt_rounded,
                      'Electricity',
                      'Prepaid DisCo',
                      AppColors.accentOrange,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'electricity')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.phone_android_rounded,
                      'Airtime',
                      'Quick Top-Up',
                      AppColors.primary,
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'airtime')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.wifi_rounded,
                      'Data Bundle',
                      '4K Video Tours',
                      const Color(0xFFF59E0B),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'data')));
                      },
                    ),
                    _buildUtilityButton(
                      Icons.tv_rounded,
                      'Cable TV',
                      'DSTV/GOTV',
                      const Color(0xFF7C3AED),
                      () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillsScreen(initialCategory: 'cable')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Verified Recent Disbursements & Transaction History Ledger (Clickable to PDF Receipt)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'RECENT DISBURSEMENTS\n& LEDGER',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _downloadStatement,
                    icon: const Icon(Icons.download_rounded, size: 13, color: AppColors.primary),
                    label: Text(
                      'Statement PDF',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Inflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Outflows'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Escrow'),
                ],
              ),
              const SizedBox(height: 10),

              ...filteredTransactions.map((tx) {
                final amount = tx['amount'] as double;
                final isPositive = amount > 0;
                final txCurr = (tx['currency'] ?? '').toString().toUpperCase();
                final titleUpper = (tx['title'] ?? tx['narration'] ?? '').toString().toUpperCase();
                final isNairaDest = titleUpper.contains('-> ₦') || titleUpper.contains('₦') || titleUpper.contains('TO NAIRA') || txCurr == 'NGN';
                final isUsdtTx = !isNairaDest && (txCurr == 'USDT' || titleUpper.contains('USDT') || titleUpper.contains('TRC20') || titleUpper.contains('TRON'));
                final isUsdTx = !isNairaDest && (txCurr == 'USD' || titleUpper.contains('DOLLAR CARD') || titleUpper.contains('USD CARD') || titleUpper.contains('VIRTUAL USD'));
                final currSymbol = isUsdtTx ? '\$' : (isUsdTx ? '\$' : '₦');
                final currSuffix = isUsdtTx ? ' USDT' : (isUsdTx ? ' USD' : '');

                final formatted = isPositive
                    ? '+$currSymbol${_currencyFormat.format(amount)}$currSuffix'
                    : '-$currSymbol${_currencyFormat.format(amount.abs())}$currSuffix';

                return InkWell(
                  onTap: () => _showTransactionReceiptModal(context, tx),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
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
                            color: (isPositive ? const Color(0xFF16A34A) : Colors.red).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: isPositive ? const Color(0xFF16A34A) : Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(tx['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                              if ((tx['description'] ?? tx['remark'] ?? tx['reason']) != null &&
                                  (tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim().isNotEmpty &&
                                  !(tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim().toLowerCase().contains('rentilly payout'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '“${(tx['description'] ?? tx['remark'] ?? tx['reason']).toString().trim()}”',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text('${tx['date']} • Tap for PDF Receipt 📄', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatted, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF16A34A) : Colors.red)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(tx['status'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedLedgerFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLedgerFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
