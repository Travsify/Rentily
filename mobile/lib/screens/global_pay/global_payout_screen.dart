import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/global_payout_models.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_security_service.dart';

class GlobalPayoutScreen extends StatefulWidget {
  final String? initialCurrency;
  final String? initialCountry;
  final String? initialPurpose;

  const GlobalPayoutScreen({
    super.key,
    this.initialCurrency,
    this.initialCountry,
    this.initialPurpose,
  });

  @override
  State<GlobalPayoutScreen> createState() => _GlobalPayoutScreenState();
}

class _GlobalPayoutScreenState extends State<GlobalPayoutScreen> {
  UserProfile? _user;
  final NumberFormat _nairaFormat = NumberFormat('#,##0', 'en_US');

  // Recipient Type
  String _recipientType = 'individual'; // 'individual' | 'corporate'

  // Selected Country & Corridor
  Map<String, dynamic> _selectedCountry = {
    'code': 'GB',
    'name': 'United Kingdom',
    'flag': '🇬🇧',
    'currency': 'GBP',
    'rail': 'Faster Payments (FPS)',
    'time': 'Instant - 2 Hours',
    'fee': 3000.0,
  };

  final List<Map<String, dynamic>> _countries = [
    {
      'code': 'GB',
      'name': 'United Kingdom',
      'flag': '🇬🇧',
      'currency': 'GBP',
      'rail': 'Faster Payments (FPS)',
      'time': 'Instant - 2 Hours',
      'fee': 3000.0,
    },
    {
      'code': 'US',
      'name': 'United States',
      'flag': '🇺🇸',
      'currency': 'USD',
      'rail': 'Fedwire / ACH',
      'time': 'Same Day - 24 Hours',
      'fee': 7500.0,
    },
    {
      'code': 'DE',
      'name': 'Germany (Eurozone)',
      'flag': '🇩🇪',
      'currency': 'EUR',
      'rail': 'SEPA / SEPA Instant',
      'time': 'Same Day (Instant)',
      'fee': 5000.0,
    },
    {
      'code': 'FR',
      'name': 'France (Eurozone)',
      'flag': '🇫🇷',
      'currency': 'EUR',
      'rail': 'SEPA / SEPA Instant',
      'time': 'Same Day (Instant)',
      'fee': 5000.0,
    },
    {
      'code': 'CA',
      'name': 'Canada',
      'flag': '🇨🇦',
      'currency': 'CAD',
      'rail': 'EFT / Interac Direct',
      'time': 'Same Day - 24 Hours',
      'fee': 5000.0,
    },
    {
      'code': 'KE',
      'name': 'Kenya',
      'flag': '🇰🇪',
      'currency': 'KES',
      'rail': 'Safaricom M-Pesa / Mobile Money',
      'time': 'Instant (Under 5 Mins)',
      'fee': 2500.0,
    },
    {
      'code': 'GH',
      'name': 'Ghana',
      'flag': '🇬🇭',
      'currency': 'GHS',
      'rail': 'MTN MoMo / Vodafone Cash',
      'time': 'Instant (Under 5 Mins)',
      'fee': 2500.0,
    },
    {
      'code': 'ZA',
      'name': 'South Africa',
      'flag': '🇿🇦',
      'currency': 'ZAR',
      'rail': 'EFT Domestic Clearing',
      'time': 'Same Day - 24 Hours',
      'fee': 5000.0,
    },
    {
      'code': 'AE',
      'name': 'United Arab Emirates (Dubai)',
      'flag': '🇦🇪',
      'currency': 'AED',
      'rail': 'Direct Clearing Rail',
      'time': '24 Hours',
      'fee': 15000.0,
    },
    {
      'code': 'CN',
      'name': 'China (Chinese Yuan)',
      'flag': '🇨🇳',
      'currency': 'CNY',
      'rail': 'Direct Clearing Rail',
      'time': '24 - 48 Hours',
      'fee': 15000.0,
    },
    {
      'code': 'AU',
      'name': 'Australia (Australian Dollar)',
      'flag': '🇦🇺',
      'currency': 'AUD',
      'rail': 'Direct Clearing Rail',
      'time': '24 - 48 Hours',
      'fee': 15000.0,
    },
    {
      'code': 'GL',
      'name': 'Global (150+ Other Countries)',
      'flag': '🌐',
      'currency': 'USD',
      'rail': 'SWIFT International Wire',
      'time': '24 - 48 Hours',
      'fee': 15000.0,
    },
  ];

  // Transfer Purpose
  String _selectedPurpose = 'Family Support & Living Expenses';
  final List<String> _purposes = [
    'Family Support & Living Expenses',
    'Contractor & Freelancer Salary',
    'Overseas Property & Rent Remittance',
    'Medical & Healthcare Settlement',
    'Supplier & Vendor Invoice Settlement',
    'University Tuition & Educational Costs',
    'Legal & Advisory Professional Fees',
    'General Offshore Direct Transfer',
  ];

  // Form Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _routingCodeController = TextEditingController(); // Sort Code / Routing / Transit
  final TextEditingController _swiftBicController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _momoOperatorController = TextEditingController();

  // Quote State
  GlobalPayQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  Timer? _debounceTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  // Submission State
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    if (widget.initialCountry != null) {
      final match = _countries.where((e) => e['code'] == widget.initialCountry!.toUpperCase()).toList();
      if (match.isNotEmpty) _selectedCountry = match.first;
    } else if (widget.initialCurrency != null) {
      final match = _countries.where((e) => e['currency'] == widget.initialCurrency!.toUpperCase()).toList();
      if (match.isNotEmpty) _selectedCountry = match.first;
    }
    if (widget.initialPurpose != null) {
      _selectedPurpose = widget.initialPurpose!;
    }
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _accountNumberController.dispose();
    _routingCodeController.dispose();
    _swiftBicController.dispose();
    _bankNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _momoOperatorController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _user = user;
      });
    }
  }

  void _onAmountChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchQuote();
    });
  }

  Future<void> _fetchQuote() async {
    final amtText = _amountController.text.trim().replaceAll(',', '');
    final amt = double.tryParse(amtText);
    if (amt == null || amt <= 0) {
      setState(() {
        _quote = null;
        _quoteError = null;
      });
      return;
    }

    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });

    try {
      final q = await ApiService.getUniversalQuote(
        destinationCurrency: _selectedCountry['currency'],
        destinationAmount: amt,
        destinationCountry: _selectedCountry['code'],
      );

      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _quote = q;
          if (q != null) {
            _startQuoteTimer(q.ttlSeconds);
          } else {
            _quoteError = 'Unable to get guaranteed rate quote. Please try again.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _quoteError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _startQuoteTimer(int seconds) {
    _countdownTimer?.cancel();
    _secondsRemaining = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        t.cancel();
        _fetchQuote(); // auto refresh rate
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTimer() {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.70,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Select Destination Country', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: _countries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderDark),
                  itemBuilder: (_, i) {
                    final c = _countries[i];
                    final isSel = c['code'] == _selectedCountry['code'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Text(c['flag'], style: const TextStyle(fontSize: 28)),
                      title: Text(c['name'], style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: isSel ? FontWeight.bold : FontWeight.w600, color: isSel ? AppColors.primary : AppColors.textPrimary)),
                      subtitle: Text('${c['currency']} • ${c['rail']}', style: GoogleFonts.spaceMono(fontSize: 11, color: AppColors.textSecondary)),
                      trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) : null,
                      onTap: () {
                        setState(() {
                          _selectedCountry = c;
                        });
                        Navigator.pop(ctx);
                        _fetchQuote();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSubmit() async {
    final name = _nameController.text.trim();
    final acc = _accountNumberController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter the recipient full legal name.', isError: true);
      return;
    }
    if (acc.isEmpty) {
      _showSnack('Please enter the recipient account number or IBAN.', isError: true);
      return;
    }
    if (_quote == null) {
      _showSnack('Please enter a valid amount and wait for the rate quote.', isError: true);
      return;
    }

    // Check wallet balance
    final bal = _user?.walletBalance ?? 0.0;
    if (bal < _quote!.totalDebitedNgn) {
      _showSnack('Insufficient wallet balance. Required: ₦${_nairaFormat.format(_quote!.totalDebitedNgn)}, Available: ₦${_nairaFormat.format(bal)}', isError: true);
      return;
    }

    // Security check: Biometrics or PIN
    final verified = await PaymentSecurityService.authorizeTransaction(
      context,
      title: 'Global Payout (${_selectedCountry['currency']} ${_quote!.destinationAmount})',
      amount: _quote!.totalDebitedNgn,
      recipient: name,
    );
    if (!verified) return;

    setState(() => _isSubmitting = true);

    try {
      final beneficiary = UniversalBeneficiary(
        name: name,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        countryCode: _selectedCountry['code'],
        currency: _selectedCountry['currency'],
        bankName: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : _selectedCountry['name'],
        accountNumberOrIban: acc,
        routingCode: _routingCodeController.text.trim().isNotEmpty ? _routingCodeController.text.trim() : null,
        swiftBic: _swiftBicController.text.trim().isNotEmpty ? _swiftBicController.text.trim() : null,
        mobileOperator: _momoOperatorController.text.trim().isNotEmpty ? _momoOperatorController.text.trim() : null,
        type: _recipientType,
      );

      final res = await ApiService.submitUniversalPayout(
        quoteReference: _quote!.quoteReference,
        orderType: 'remittance',
        transferPurpose: _selectedPurpose,
        beneficiary: beneficiary,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['status'] == true && res['data'] != null) {
          final data = res['data'];
          _showRemittanceSuccessDialog(
            reference: data['reference'] ?? 'RGP_${DateTime.now().millisecondsSinceEpoch}',
            beneficiaryName: name,
            destAmount: _quote!.destinationAmount,
            destCurrency: _selectedCountry['currency'],
            totalNgn: _quote!.totalDebitedNgn,
            rail: _selectedCountry['rail'],
          );
        } else {
          _showSnack(res['error'] ?? res['message'] ?? 'Global payout could not be processed.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack(e.toString().replaceAll('Exception:', '').trim(), isError: true);
      }
    }
  }

  void _showRemittanceSuccessDialog({
    required String reference,
    required String beneficiaryName,
    required double destAmount,
    required String destCurrency,
    required double totalNgn,
    required String rail,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.borderDark)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Transfer Dispatched! 🌍',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your global payout has been scheduled and dispatched to direct international clearing rails.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
              child: Column(
                children: [
                  _dialogRow('Recipient:', beneficiaryName),
                  const SizedBox(height: 6),
                  _dialogRow('Delivering:', '$destCurrency ${destAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _dialogRow('Debited:', '₦${_nairaFormat.format(totalNgn)}'),
                  const SizedBox(height: 6),
                  _dialogRow('Clearing Rail:', rail),
                  const SizedBox(height: 6),
                  _dialogRow('Reference:', reference),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reference));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied to clipboard!')));
            },
            child: Text('Copy Reference', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : AppColors.mint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = _selectedCountry['currency'];
    final rail = _selectedCountry['rail'];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: Text('Global Payout & Remittance', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Recipient Type Switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _recipientType = 'individual'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _recipientType == 'individual' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Individual Person', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: _recipientType == 'individual' ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _recipientType = 'corporate'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _recipientType == 'corporate' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Business / Entity', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: _recipientType == 'corporate' ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Destination Country Card
            _buildLabel('DESTINATION COUNTRY & CORRIDOR'),
            const SizedBox(height: 6),
            InkWell(
              onTap: _openCountryPicker,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
                child: Row(
                  children: [
                    Text(_selectedCountry['flag'], style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCountry['name'], style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('$rail • Settlement: ${_selectedCountry['time']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Amount to Send
            _buildLabel('TRANSFER AMOUNT (${_selectedCountry['currency']})'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.spaceMono(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 1000',
                hintStyle: GoogleFonts.spaceMono(fontSize: 16, color: AppColors.textSecondary),
                prefixIcon: Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(_selectedCountry['currency'], style: GoogleFonts.spaceMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),

            // 4. Live Quote Card
            if (_isLoadingQuote) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ] else if (_quote != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.mint),
                            const SizedBox(width: 6),
                            Text('Guaranteed Rate Locked', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mint)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(_formatTimer(), style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mint)),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.borderDark),
                    _summaryLine('Exchange Rate:', '1 $currency = ₦${_nairaFormat.format(_quote!.customerRate)}'),
                    const SizedBox(height: 4),
                    _summaryLine('Transfer Cost:', '₦${_nairaFormat.format(_quote!.sourceAmountNgn)}'),
                    const SizedBox(height: 4),
                    _summaryLine('Corridor Rail Fee:', '₦${_nairaFormat.format(_quote!.corridorFeeNgn)}'),
                    const Divider(height: 16, color: AppColors.borderDark),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Wallet Debit:', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('₦${_nairaFormat.format(_quote!.totalDebitedNgn)} NGN', style: GoogleFonts.spaceMono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_quoteError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _quoteError!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 5. Transfer Purpose Dropdown
            _buildLabel('PURPOSE OF TRANSFER'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPurpose,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceDark,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
                  items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPurpose = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 6. Beneficiary Information Section
            _buildLabel('BENEFICIARY DETAILS (${_recipientType == 'individual' ? 'INDIVIDUAL' : 'BUSINESS'})'),
            const SizedBox(height: 6),
            _buildInputField(
              controller: _nameController,
              label: _recipientType == 'individual' ? 'Full Legal Name (as on bank ID)' : 'Registered Business Legal Name',
              hint: _recipientType == 'individual' ? 'e.g. Eleanor Vance' : 'e.g. Apex Global Logistics Ltd',
            ),
            const SizedBox(height: 10),
            _buildInputField(
              controller: _emailController,
              label: 'Recipient Email (for Remittance Advice PDF)',
              hint: 'e.g. recipient@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            // Dynamic fields per country/rail
            if (_selectedCountry['code'] == 'GB') ...[
              _buildInputField(controller: _bankNameController, label: 'Bank Name (Optional)', hint: 'e.g. Monzo Bank / Barclays / HSBC'),
              const SizedBox(height: 10),
              _buildInputField(controller: _routingCodeController, label: 'Sort Code (6 digits)', hint: 'e.g. 04-06-05', keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'Account Number (8 digits) or GB IBAN', hint: 'e.g. 31389897', keyboardType: TextInputType.text),
            ] else if (_selectedCountry['code'] == 'US') ...[
              _buildInputField(controller: _bankNameController, label: 'Bank Name (Optional)', hint: 'e.g. JPMorgan Chase / Wells Fargo'),
              const SizedBox(height: 10),
              _buildInputField(controller: _routingCodeController, label: 'ABA / Fedwire Routing Number (9 digits)', hint: 'e.g. 021000021', keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'US Checking or Savings Account Number', hint: 'e.g. 9876543210', keyboardType: TextInputType.number),
            ] else if (_selectedCountry['currency'] == 'EUR') ...[
              _buildInputField(controller: _bankNameController, label: 'Bank Name (Optional)', hint: 'e.g. Deutsche Bank / BNP Paribas'),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'European IBAN (starts with country code)', hint: 'e.g. FR7630006000011234567890189', keyboardType: TextInputType.text),
              const SizedBox(height: 10),
              _buildInputField(controller: _swiftBicController, label: 'BIC / SWIFT Code', hint: 'e.g. BNPAFRPP', keyboardType: TextInputType.text),
            ] else if (_selectedCountry['code'] == 'CA') ...[
              _buildInputField(controller: _bankNameController, label: 'Bank Name (Optional)', hint: 'e.g. Royal Bank of Canada (RBC) / TD'),
              const SizedBox(height: 10),
              _buildInputField(controller: _routingCodeController, label: 'Transit (5 digits) & Institution (3 digits)', hint: 'e.g. 12345-001', keyboardType: TextInputType.text),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'Canadian Account Number', hint: 'e.g. 1234567', keyboardType: TextInputType.number),
            ] else if (_selectedCountry['code'] == 'KE' || _selectedCountry['code'] == 'GH') ...[
              _buildInputField(controller: _momoOperatorController, label: 'Mobile Money Operator', hint: _selectedCountry['code'] == 'KE' ? 'e.g. Safaricom M-Pesa' : 'e.g. MTN MoMo / Vodafone Cash'),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'Mobile Phone Number', hint: 'e.g. +254 712 345 678', keyboardType: TextInputType.phone),
            ] else ...[
              _buildInputField(controller: _bankNameController, label: 'Beneficiary Bank Name', hint: 'e.g. Emirates NBD / Standard Chartered'),
              const SizedBox(height: 10),
              _buildInputField(controller: _accountNumberController, label: 'Account Number or IBAN', hint: 'e.g. AE120330000012345678901'),
              const SizedBox(height: 10),
              _buildInputField(controller: _swiftBicController, label: 'SWIFT / BIC Code', hint: 'e.g. EBILAEADXXX'),
            ],

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _quote != null ? 'Send ${_selectedCountry['currency']} ${_quote!.destinationAmount.toStringAsFixed(2)}' : 'Authorize Payout',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary));
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}