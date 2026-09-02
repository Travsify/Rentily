import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
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
  bool _isCardFrozen = false;
  bool _showCardDetails = false;
  double _cardBalance = 1250.00;
  double _fxUsdToNgn = 1510.0;
  final NumberFormat _currencyFormat = NumberFormat('#,###.00', 'en_US');

  final List<Map<String, dynamic>> _cardTransactions = [
    {
      'id': 'CRD_TX_1092',
      'reference': 'BRG_POS_98319241',
      'title': 'OpenAI ChatGPT Plus Subscription',
      'merchant': 'OpenAI, LLC - San Francisco, CA',
      'category': 'AI & Cloud Software',
      'type': 'Card POS / Online',
      'amount': 20.00,
      'isCredit': false,
      'status': 'SUCCESSFUL',
      'date': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String(),
    },
    {
      'id': 'CRD_TX_1091',
      'reference': 'BRG_POS_88204910',
      'title': 'Amazon Web Services (AWS)',
      'merchant': 'Amazon Web Services - Seattle, WA',
      'category': 'Cloud Infrastructure',
      'type': 'Card POS / Online',
      'amount': 45.50,
      'isCredit': false,
      'status': 'SUCCESSFUL',
      'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'id': 'CRD_TX_1090',
      'reference': 'BRG_TOP_77182910',
      'title': 'Card Wallet Funding (NGN -> USD)',
      'merchant': 'Rentilly Multi-Currency Vault',
      'category': 'Card Top-Up',
      'type': 'Card Funding',
      'amount': 500.00,
      'isCredit': true,
      'status': 'SUCCESSFUL',
      'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'id': 'CRD_TX_1089',
      'reference': 'BRG_POS_66192841',
      'title': 'Uber Technologies International',
      'merchant': 'Uber Trips - London, UK',
      'category': 'Travel & Mobility',
      'type': 'Card POS / Online',
      'amount': 18.25,
      'isCredit': false,
      'status': 'SUCCESSFUL',
      'date': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndRates();
  }

  Future<void> _loadUserAndRates() async {
    final user = await AuthService.getCurrentUser();
    try {
      final rates = await ApiService.fetchFxRates();
      if (mounted) {
        setState(() {
          _fxUsdToNgn = rates['USD_NGN'] ?? 1510.0;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  void _toggleFreezeCard() {
    HapticFeedback.mediumImpact();
    setState(() => _isCardFrozen = !_isCardFrozen);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isCardFrozen ? '🔒 Virtual Dollar Card frozen successfully!' : '🔓 Virtual Dollar Card active & ready for transactions!',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _isCardFrozen ? AppColors.accentOrange : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTopUpModal() {
    final amountCtrl = TextEditingController();
    String fundingSource = 'NGN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final amtUsd = double.tryParse(amountCtrl.text) ?? 0.0;
          final amtNgn = amtUsd * _fxUsdToNgn;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fund Virtual Dollar Card',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'SELECT FUNDING SOURCE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    {'id': 'NGN', 'label': '🇳🇬 Naira Wallet', 'bal': _user?.walletBalance ?? 0.0, 'sym': '₦'},
                    {'id': 'USD', 'label': '🇺🇸 USD Vault', 'bal': 0.0, 'sym': '\$'},
                  ].map((w) {
                    final isSel = fundingSource == w['id'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => fundingSource = w['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSel ? AppColors.primary : const Color(0xFFE2E8F0), width: isSel ? 1.5 : 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w['label'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? AppColors.primary : AppColors.textPrimary)),
                              Text('Bal: ${w['sym']}${_currencyFormat.format(w['bal'] as double)}', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount (USD)',
                    prefixText: '\$ ',
                    hintText: '50.00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                if (fundingSource == 'NGN' && amtUsd > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Conversion (Rate: \$1 = ₦${_fxUsdToNgn.toStringAsFixed(0)}):', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                        Text('₦${_currencyFormat.format(amtNgn)} NGN', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: amtUsd <= 0
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            setState(() {
                              _cardBalance += amtUsd;
                              _cardTransactions.insert(0, {
                                'id': 'CRD_TX_${DateTime.now().millisecondsSinceEpoch}',
                                'reference': 'BRG_TOP_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                                'title': 'Card Wallet Top-Up ($fundingSource -> USD)',
                                'merchant': 'Rentilly Multi-Currency Vault',
                                'category': 'Card Top-Up',
                                'type': 'Card Funding',
                                'amount': amtUsd,
                                'isCredit': true,
                                'status': 'SUCCESSFUL',
                                'date': DateTime.now().toIso8601String(),
                              });
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Funded \$${_currencyFormat.format(amtUsd)} USD successfully!', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Confirm & Fund Card', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holderName = _user?.fullName ?? _user?.businessName ?? 'PREMIUM CARDHOLDER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Virtual Dollar Cards',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Export Card Statement',
            onPressed: () {
              if (_user != null) {
                StatementExportModal.show(
                  context,
                  user: _user!,
                  transactions: _cardTransactions,
                  cardTransactions: _cardTransactions,
                  cardDetails: {
                    'last4': '8842',
                    'name': holderName,
                    'balance': _cardBalance,
                    'brand': 'Visa USD Virtual Debit Card',
                  },
                  initialCurrency: 'CARD',
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D Virtual Visa Card Widget
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isCardFrozen
                            ? [const Color(0xFF475569), const Color(0xFF334155)]
                            : [const Color(0xFF0F172A), const Color(0xFF0B4F3F), const Color(0xFF022C22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isCardFrozen ? const Color(0xFF475569) : const Color(0xFF0B4F3F)).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'RENTILLY GLOBAL',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                                  ),
                                ),
                                if (_isCardFrozen) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentOrange,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'FROZEN',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              'VISA',
                              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white),
                            ),
                          ],
                        ),

                        // Card Number with Reveal Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showCardDetails ? '4187  8859  3019  8842' : '••••  ••••  ••••  8842',
                              style: GoogleFonts.sourceCodePro(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0),
                            ),
                            IconButton(
                              icon: Icon(_showCardDetails ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70, size: 20),
                              onPressed: () => setState(() => _showCardDetails = !_showCardDetails),
                            ),
                          ],
                        ),

                        // Expiry, CVV & Cardholder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CARDHOLDER', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, color: Colors.white60, letterSpacing: 0.8)),
                                const SizedBox(height: 2),
                                Text(
                                  holderName.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('EXPIRES', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, color: Colors.white60)),
                                    const SizedBox(height: 2),
                                    Text('12/29', style: GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CVV', style: GoogleFonts.plusJakartaSans(fontSize: 7.5, color: Colors.white60)),
                                    const SizedBox(height: 2),
                                    Text(_showCardDetails ? '482' : '•••', style: GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Balance & Quick Action Control Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AVAILABLE CARD BALANCE', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text('\$${_currencyFormat.format(_cardBalance)} USD', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                            Switch.adaptive(
                              value: !_isCardFrozen,
                              activeColor: AppColors.primary,
                              onChanged: (_) => _toggleFreezeCard(),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showTopUpModal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text('Top Up Card', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (_user != null) {
                                    StatementExportModal.show(
                                      context,
                                      user: _user!,
                                      transactions: _cardTransactions,
                                      cardTransactions: _cardTransactions,
                                      initialCurrency: 'CARD',
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: Text('Card Statement', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Card Transactions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Card Activity & Merchant POS',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_cardTransactions.length} Settled',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transaction List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cardTransactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final tx = _cardTransactions[i];
                      final isCredit = tx['isCredit'] == true;
                      final amt = (tx['amount'] as num).toDouble();
                      final merchant = tx['merchant'] ?? tx['title'];
                      final dateStr = tx['date'] != null
                          ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(tx['date'].toString()) ?? DateTime.now())
                          : 'Recent';

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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
                                  color: isCredit ? const Color(0xFF16A34A) : AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      merchant,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$dateStr • Tap for Receipt 📄',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isCredit ? "+" : "-"}\$${_currencyFormat.format(amt)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? const Color(0xFF16A34A) : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
