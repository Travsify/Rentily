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
import 'global_pay_tracker_screen.dart';

class TuitionPaymentScreen extends StatefulWidget {
  const TuitionPaymentScreen({super.key});

  @override
  State<TuitionPaymentScreen> createState() => _TuitionPaymentScreenState();
}

class _TuitionPaymentScreenState extends State<TuitionPaymentScreen> {
  UserProfile? _user;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // Form Controllers
  final _schoolController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _semesterController = TextEditingController(text: 'Fall Semester 2026/2027');
  final _amountController = TextEditingController();
  final _ibanController = TextEditingController();
  final _sortCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _invoiceUrlController = TextEditingController();

  String _selectedCountry = 'GB';
  String _selectedCurrency = 'GBP';

  bool _isGettingQuote = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _activeQuote;
  Timer? _countdownTimer;
  int _secondsRemaining = 900; // 15 minutes

  final List<Map<String, String>> _countries = [
    {'code': 'GB', 'name': 'United Kingdom (UK)', 'currency': 'GBP', 'rail': 'Faster Payments (FPS)', 'flag': '🇬🇧'},
    {'code': 'US', 'name': 'United States (USA)', 'currency': 'USD', 'rail': 'Fedwire / ACH', 'flag': '🇺🇸'},
    {'code': 'CA', 'name': 'Canada', 'currency': 'CAD', 'rail': 'EFT / Interac Direct', 'flag': '🇨🇦'},
    {'code': 'DE', 'name': 'Germany (EU SEPA)', 'currency': 'EUR', 'rail': 'SEPA Instant', 'flag': '🇩🇪'},
    {'code': 'IE', 'name': 'Ireland (EU SEPA)', 'currency': 'EUR', 'rail': 'SEPA Instant', 'flag': '🇮🇪'},
    {'code': 'FR', 'name': 'France (EU SEPA)', 'currency': 'EUR', 'rail': 'SEPA Instant', 'flag': '🇫🇷'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _schoolController.dispose();
    _studentNameController.dispose();
    _studentIdController.dispose();
    _semesterController.dispose();
    _amountController.dispose();
    _ibanController.dispose();
    _sortCodeController.dispose();
    _bankNameController.dispose();
    _invoiceUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    _user = await AuthService.getCurrentUser();
    if (_user != null) {
      _studentNameController.text = _user!.fullName;
    }
  }

  void _onCountryChanged(String code) {
    final matched = _countries.firstWhere((c) => c['code'] == code);
    setState(() {
      _selectedCountry = code;
      _selectedCurrency = matched['currency']!;
      _activeQuote = null;
      _countdownTimer?.cancel();
    });
  }

  Future<void> _fetchRateLockQuote() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter a valid tuition fee amount.');
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
                'Authorize Tuition Transfer',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your 4-digit Transaction PIN to secure this pre-auth hold and dispatch the international wire.',
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
                  hintStyle: const TextStyle(letterSpacing: 16),
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
                    'Confirm & Pay Now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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

    if (_schoolController.text.trim().isEmpty || _studentIdController.text.trim().isEmpty) {
      _showSnackbar('Please provide university name and student matriculation ID.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await AuthService.getToken();
      final body = {
        'userId': _user?.id,
        'userEmail': _user?.email,
        'quoteReference': _activeQuote!['quoteReference'],
        'orderType': 'tuition',
        'studentName': _studentNameController.text.trim(),
        'studentMatricId': _studentIdController.text.trim(),
        'institutionName': _schoolController.text.trim(),
        'semesterSession': _semesterController.text.trim(),
        'documentUrl': _invoiceUrlController.text.trim(),
        'pin': pin,
        'beneficiary': {
          'name': _schoolController.text.trim(),
          'countryCode': _selectedCountry,
          'currency': _selectedCurrency,
          'bankName': _bankNameController.text.trim().isNotEmpty
              ? _bankNameController.text.trim()
              : 'University Settlement Account',
          'accountNumberOrIban': _ibanController.text.trim().isNotEmpty
              ? _ibanController.text.trim()
              : 'GB29NWBK60161331926819',
          'routingCode': _sortCodeController.text.trim().isNotEmpty
              ? _sortCodeController.text.trim()
              : '601613',
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
        _showSnackbar(data['error'] ?? 'Tuition payment submission failed.');
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

  @override
  Widget build(BuildContext context) {
    final matchedCountry = _countries.firstWhere((c) => c['code'] == _selectedCountry);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pay International Tuition',
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
            // Destination Country Dropdown Card
            _buildSectionLabel('Destination Country & Currency'),
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
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  items: _countries.map((c) {
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
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['rail']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
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

            // University Information
            _buildSectionLabel('University / Institution'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _schoolController,
              hint: 'e.g. University of Manchester / Harvard University',
              icon: Icons.school,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Student Full Name'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _studentNameController,
                        hint: 'Full legal name',
                        icon: Icons.person,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Student Matric / App ID'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _studentIdController,
                        hint: 'e.g. UOM-849204',
                        icon: Icons.badge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // University Bank Account (IBAN / Sort Code)
            _buildSectionLabel('University Clearing Coordinates'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _ibanController,
              hint: _selectedCountry == 'GB' ? 'Account Number (e.g. 12345678)' : 'IBAN / Swift Account Number',
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _sortCodeController,
                    hint: _selectedCountry == 'GB' ? 'Sort Code (e.g. 60-16-13)' : 'ABA / SWIFT BIC Code',
                    icon: Icons.numbers,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _bankNameController,
                    hint: 'Bank Name (e.g. NatWest)',
                    icon: Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tuition Fee Amount
            _buildSectionLabel('Tuition Fee Amount ($_selectedCurrency)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    '${matchedCountry['flag']} $_selectedCurrency',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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
                      backgroundColor: AppColors.primary,
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

            // Rate Lock Fee Breakdown Card
            if (_activeQuote != null) _buildRateLockCard(),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _activeQuote == null || _isSubmitting ? null : _showPinModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_clock, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Authorize & Settle Tuition',
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
          prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
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
        color: const Color(0xFF07382B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mint.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
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
                  const Icon(Icons.timer, size: 16, color: AppColors.accentGold),
                  const SizedBox(width: 6),
                  Text(
                    'GUARANTEED RATE LOCK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mint,
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
          _buildBreakdownRow('Corridor Network Fee:', '₦${_currencyFormat.format(_activeQuote!['corridorFeeNgn'])}'),
          _buildBreakdownRow('Payment Rail:', _activeQuote!['paymentScheme'].toString().toUpperCase()),
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
                  color: AppColors.mint,
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
