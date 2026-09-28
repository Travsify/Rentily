import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../../widgets/partner_bottom_bar.dart';
import '../../widgets/landlord_bottom_bar.dart';
import '../main_navigation_screen.dart';
import 'global_pay_tracker_screen.dart';

class SupplierPayoutScreen extends StatefulWidget {
  const SupplierPayoutScreen({super.key});

  @override
  State<SupplierPayoutScreen> createState() => _SupplierPayoutScreenState();
}

class _SupplierPayoutScreenState extends State<SupplierPayoutScreen> {
  UserProfile? _user;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // Form Controllers
  final _vendorNameController = TextEditingController();
  final _invoiceNumController = TextEditingController();
  final _poNumController = TextEditingController();
  final _goodsDescController = TextEditingController();
  final _vendorTaxIdController = TextEditingController();
  final _documentUrlController = TextEditingController();
  final _amountController = TextEditingController();
  final _ibanController = TextEditingController();
  final _swiftController = TextEditingController();
  final _bankNameController = TextEditingController();

  String _selectedCountry = 'CN';
  String _selectedCurrency = 'USD';
  String _preferredScheme = 'swift';

  bool _isGettingQuote = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _activeQuote;
  Timer? _countdownTimer;
  int _secondsRemaining = 900;

  final List<Map<String, String>> _vendorCountries = [
    {'code': 'CN', 'name': 'China (Shenzhen/Guangzhou/Yiwu)', 'currency': 'USD', 'rail': 'SWIFT Wire', 'flag': '🇨🇳', 'scheme': 'swift'},
    {'code': 'TR', 'name': 'Turkey (Istanbul/Bursa)', 'currency': 'USD', 'rail': 'SWIFT Wire', 'flag': '🇹🇷', 'scheme': 'swift'},
    {'code': 'AE', 'name': 'United Arab Emirates (Dubai)', 'currency': 'USD', 'rail': 'SWIFT Wire', 'flag': '🇦🇪', 'scheme': 'swift'},
    {'code': 'US', 'name': 'United States (B2B Commercial)', 'currency': 'USD', 'rail': 'Fedwire / ACH', 'flag': '🇺🇸', 'scheme': 'fedwire'},
    {'code': 'GB', 'name': 'United Kingdom (Commercial)', 'currency': 'GBP', 'rail': 'Faster Payments (FPS)', 'flag': '🇬🇧', 'scheme': 'fps'},
    {'code': 'DE', 'name': 'Germany (Eurozone)', 'currency': 'EUR', 'rail': 'SEPA Commercial', 'flag': '🇩🇪', 'scheme': 'sepa'},
    {'code': 'IT', 'name': 'Italy (Eurozone)', 'currency': 'EUR', 'rail': 'SEPA Commercial', 'flag': '🇮🇹', 'scheme': 'sepa'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _vendorNameController.dispose();
    _invoiceNumController.dispose();
    _poNumController.dispose();
    _goodsDescController.dispose();
    _vendorTaxIdController.dispose();
    _documentUrlController.dispose();
    _amountController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    _user = await AuthService.getCurrentUser();
  }

  void _onCountryChanged(String code) {
    final matched = _vendorCountries.firstWhere((c) => c['code'] == code);
    setState(() {
      _selectedCountry = code;
      _selectedCurrency = matched['currency']!;
      _preferredScheme = matched['scheme']!;
      _activeQuote = null;
      _countdownTimer?.cancel();
    });
  }

  Future<void> _fetchRateLockQuote() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter a valid invoice amount.');
      return;
    }

    setState(() => _isGettingQuote = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/global-pay/quote'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'destinationCurrency': _selectedCurrency,
          'destinationAmount': amount,
          'destinationCountry': _selectedCountry,
          'preferredScheme': _preferredScheme,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == true && data['data'] != null) {
        setState(() {
          _activeQuote = data['data'];
          _secondsRemaining = (_activeQuote!['ttlSeconds'] ?? 900) as int;
        });
        _startTimer();
      } else {
        _showSnackbar(data['error'] ?? 'Could not lock FX quote.');
      }
    } catch (e) {
      _showSnackbar('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGettingQuote = false);
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() => _activeQuote = null);
        _showSnackbar('Rate lock expired. Please refresh to lock latest rate.');
      }
    });
  }

  void _showPinModal() {
    final pinController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authorize Supplier Wire',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your 4-digit PIN to lock funds and dispatch this B2B overseas supplier payment.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 16,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (pin.length < 4) {
                      _showSnackbar('Please enter your 4-digit PIN');
                      return;
                    }
                    Navigator.pop(ctx);
                    _executeTransfer(pin);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Confirm & Pay Supplier',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Future<void> _executeTransfer(String pin) async {
    if (_activeQuote == null) {
      _showSnackbar('Quote has expired. Please fetch a fresh rate lock.');
      return;
    }

    if (_vendorNameController.text.trim().isEmpty || _invoiceNumController.text.trim().isEmpty) {
      _showSnackbar('Please provide supplier name and proforma invoice number.');
      return;
    }

    if (_ibanController.text.trim().isEmpty || _swiftController.text.trim().isEmpty || _bankNameController.text.trim().isEmpty) {
      _showSnackbar('Please provide supplier bank clearing coordinates (Bank Name, IBAN/Account, and SWIFT/Routing code).');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await AuthService.getToken();
      final body = {
        'userId': _user?.id,
        'userEmail': _user?.email,
        'quoteReference': _activeQuote!['quoteReference'],
        'orderType': 'supplier',
        'invoiceNumber': _invoiceNumController.text.trim(),
        'poNumber': _poNumController.text.trim(),
        'goodsDescription': _goodsDescController.text.trim(),
        'vendorTaxId': _vendorTaxIdController.text.trim(),
        'documentUrl': _documentUrlController.text.trim(),
        'pin': pin,
        'beneficiary': {
          'name': _vendorNameController.text.trim(),
          'countryCode': _selectedCountry,
          'currency': _selectedCurrency,
          'bankName': _bankNameController.text.trim(),
          'accountNumberOrIban': _ibanController.text.trim(),
          'routingCode': _swiftController.text.trim(),
          'swiftBic': _swiftController.text.trim(),
          'vendorTaxId': _vendorTaxIdController.text.trim(),
        }
      };

      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/global-pay/submit'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 && data['status'] == true && data['data'] != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GlobalPayTrackerScreen(order: data['data']),
          ),
        );
      } else {
        _showSnackbar(data['error'] ?? 'Supplier payment submission failed.');
      }
    } catch (e) {
      _showSnackbar('Submission error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.textPrimary),
    );
  }

  Widget _buildBottomBar() {
    final role = _user?.role.toLowerCase() ?? 'renter';
    if (role == 'partner') {
      return PartnerBottomBar(
        currentIndex: 2,
        onTap: (i) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i, initialPartnerMode: true)),
            (route) => false,
          );
        },
      );
    } else if (role == 'owner' || role == 'landlord') {
      return LandlordBottomBar(
        currentIndex: 2,
        onTap: (i) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i, initialLandlordMode: true)),
            (route) => false,
          );
        },
      );
    } else {
      return RentillyBottomBar(
        currentIndex: 3,
        onTap: (i) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: i)),
            (route) => false,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchedCountry = _vendorCountries.firstWhere((c) => c['code'] == _selectedCountry);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      bottomNavigationBar: _buildBottomBar(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pay Overseas Supplier',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Country Selector
            _buildSectionLabel('Supplier Location & Clearing Rail'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountry,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.accentGoldDark),
                  items: _vendorCountries.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Row(
                        children: [
                          Text(c['flag']!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${c['name']} (${c['currency']})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['rail']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentGoldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _onCountryChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vendor Name & Invoicing
            _buildSectionLabel('Vendor / Beneficiary Company Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _vendorNameController,
              hint: 'e.g. Shenzhen Electronics Ltd / Istanbul Textiles A.S.',
              icon: Icons.business,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Proforma Invoice #'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _invoiceNumController,
                        hint: 'e.g. PI-2026-9481',
                        icon: Icons.receipt_long,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Purchase Order (PO) #'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _poNumController,
                        hint: 'e.g. PO-8831',
                        icon: Icons.tag,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Goods / Commercial Description'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _goodsDescController,
                        hint: 'e.g. Industrial machinery parts',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Supplier Tax ID / TIN'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _vendorTaxIdController,
                        hint: 'e.g. 91330100MA27',
                        icon: Icons.badge_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSectionLabel('Commercial Invoice / BL Document (URL or Ref)'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _documentUrlController,
              hint: 'Paste invoice document URL or customs clearance link',
              icon: Icons.attach_file_rounded,
            ),
            const SizedBox(height: 16),

            // Bank Information
            _buildSectionLabel('Supplier Bank IBAN / Account Number'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _ibanController,
              hint: 'Beneficiary IBAN or Account Number',
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _swiftController,
                    hint: 'SWIFT / BIC Code',
                    icon: Icons.language,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _bankNameController,
                    hint: 'Bank Name',
                    icon: Icons.apartment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Invoice Amount
            _buildSectionLabel('Invoice Payable Amount ($_selectedCurrency)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    '${matchedCountry['flag']} $_selectedCurrency',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGoldDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        if (_activeQuote != null) {
                          setState(() {
                            _activeQuote = null;
                            _countdownTimer?.cancel();
                          });
                        }
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isGettingQuote ? null : _fetchRateLockQuote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGoldDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: _isGettingQuote
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _activeQuote == null ? 'Lock Rate' : 'Locked',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rate Lock Card
            if (_activeQuote != null) _buildRateLockCard(),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _activeQuote == null || _isSubmitting ? null : _showPinModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGoldDark,
                  disabledBackgroundColor: AppColors.accentGoldDark.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Authorize & Disburse Wire',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: AppColors.accentGoldDark),
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRateLockCard() {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 14,
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
                  const Icon(Icons.verified, size: 16, color: AppColors.accentGold),
                  const SizedBox(width: 6),
                  Text(
                    'GUARANTEED RATE LOCK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$mins:$secs Remaining',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildBreakdownRow('Locked Rate:', '1 $_selectedCurrency = ₦${_currencyFormat.format(_activeQuote!['customerRate'])}'),
          if (_activeQuote!['platformFeeNgn'] != null && (_activeQuote!['platformFeeNgn'] as num) > 0)
            _buildBreakdownRow('Platform Fee (${_activeQuote!['platformFeePercent'] ?? 1.2}%):', '₦${_currencyFormat.format(_activeQuote!['platformFeeNgn'])}'),
          _buildBreakdownRow('Corridor Network Fee:', '₦${_currencyFormat.format(_activeQuote!['corridorFeeNgn'])}'),
          _buildBreakdownRow('Clearing Rail:', _activeQuote!['paymentScheme'].toString().toUpperCase()),
          const Divider(color: Colors.white24, height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Debited from Wallet:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '₦${_currencyFormat.format(_activeQuote!['totalDebitedNgn'])}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
