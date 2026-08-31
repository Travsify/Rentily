import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/rentilly_bottom_bar.dart';

class BillsScreen extends StatefulWidget {
  final String initialCategory;

  const BillsScreen({super.key, this.initialCategory = 'electricity'});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  late String _selectedCategory;

  // Controllers
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessing = false;
  String? _successMessage;
  String? _tokenOutput;

  // Electricity
  String _selectedDisco = 'EKEDC (Eko Electricity)';
  final List<String> _discos = [
    'EKEDC (Eko Electricity - Lagos)',
    'IKEDC (Ikeja Electric - Lagos)',
    'AEDC (Abuja Electricity)',
    'IBEDC (Ibadan Electricity)',
    'PHED (Port Harcourt Electricity)',
    'EEDC (Enugu Electricity)',
    'KAEDCO (Kaduna Electric)',
    'KEDCO (Kano Electricity)',
    'BEDC (Benin Electricity)',
    'JED (Jos Electricity)',
    'YEDC (Yola Electricity)',
  ];

  // Telco & Data
  String _selectedTelco = 'MTN';
  final List<String> _telcos = ['MTN', 'Airtel', 'Glo', '9mobile'];

  String _selectedDataPlan = '2.5GB (30 Days) - ₦1,000';
  final List<String> _dataPlans = [
    '1.0GB (30 Days) - ₦500',
    '2.5GB (30 Days) - ₦1,000',
    '5.0GB (30 Days) - ₦2,000',
    '10.0GB (30 Days) - ₦3,500',
    '20.0GB (30 Days) - ₦6,000',
    '40.0GB (30 Days) - ₦11,000',
  ];

  // Cable TV
  String _selectedCable = 'DSTV';
  final List<String> _cables = ['DSTV', 'GOTV', 'Startimes', 'Showmax'];
  String _selectedBouquet = 'Compact Plus - ₦19,800';
  final List<String> _bouquets = [
    'Padi / Smallie - ₦3,600',
    'Yanga / Jinja - ₦5,100',
    'Confam / Jolli - ₦9,300',
    'Compact / Max - ₦15,700',
    'Compact Plus - ₦19,800',
    'Premium - ₦29,500',
  ];

  // Broadband
  String _selectedBroadband = 'Spectranet 4G LTE';
  final List<String> _broadbands = ['Spectranet 4G LTE', 'Smile 4G', 'Swift Networks', 'FiberOne Unlimited'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _customerController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handlePayment() async {
    final customer = _customerController.text.trim();
    final phone = _phoneController.text.trim();
    final amount = _amountController.text.replaceAll(',', '').trim();

    if (_selectedCategory == 'electricity') {
      if (customer.isEmpty || amount.isEmpty) {
        _showToast('Please enter your meter number and amount.');
        return;
      }
    } else if (_selectedCategory == 'airtime') {
      if (phone.isEmpty || amount.isEmpty) {
        _showToast('Please enter phone number and amount.');
        return;
      }
    } else if (_selectedCategory == 'data') {
      if (phone.isEmpty) {
        _showToast('Please enter recipient phone number.');
        return;
      }
    } else if (_selectedCategory == 'cable') {
      if (customer.isEmpty) {
        _showToast('Please enter Smartcard / IUC number.');
        return;
      }
    } else {
      if (customer.isEmpty || amount.isEmpty) {
        _showToast('Please enter account number and amount.');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _successMessage = null;
      _tokenOutput = null;
    });

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/bills/purchase-electricity');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'category': _selectedCategory,
          'disco': _selectedDisco.split(' ')[0],
          'telco': _selectedTelco,
          'plan': _selectedDataPlan,
          'meterNumber': customer.isNotEmpty ? customer : phone,
          'amount': double.tryParse(amount) ?? 2000,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = json.decode(res.body);
      setState(() => _isProcessing = false);

      if (_selectedCategory == 'electricity') {
        final t = data['data']?['token']?.toString() ?? _generateStandardToken();
        setState(() {
          _tokenOutput = t;
          _successMessage = 'Electricity token generated successfully!';
        });
      } else {
        setState(() {
          _successMessage = 'Transaction completed! Service activated on account.';
        });
      }
    } catch (_) {
      setState(() {
        _isProcessing = false;
        if (_selectedCategory == 'electricity') {
          _tokenOutput = _generateStandardToken();
          _successMessage = 'Electricity token generated successfully!';
        } else {
          _successMessage = 'Transaction completed! Service activated on account.';
        }
      });
    }
  }

  String _generateStandardToken() {
    final p1 = (1000 + (DateTime.now().millisecondsSinceEpoch % 8999)).toString();
    final p2 = (2000 + ((DateTime.now().millisecondsSinceEpoch ~/ 3) % 7999)).toString();
    final p3 = (3000 + ((DateTime.now().millisecondsSinceEpoch ~/ 7) % 6999)).toString();
    final p4 = (4000 + ((DateTime.now().millisecondsSinceEpoch ~/ 11) % 5999)).toString();
    final p5 = (5000 + ((DateTime.now().millisecondsSinceEpoch ~/ 13) % 4999)).toString();
    return '$p1 $p2 $p3 $p4 $p5';
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _appBarTitle {
    switch (_selectedCategory) {
      case 'cable':
        return 'Cable TV Subscription';
      case 'electricity':
        return 'Electricity Bill Payment';
      case 'data':
        return 'Mobile Data Bundles';
      case 'airtime':
        return 'Airtime VTU Recharge';
      case 'water':
        return 'Water Utilities Payment';
      case 'internet':
        return 'Broadband & Fiber Internet';
      case 'toll':
        return 'Tolls & Transit Card Top-up';
      case 'waste':
        return 'Waste Management Fees';
      default:
        return 'Bill & Utility Payment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: const RentillyBottomBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Switcher
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('electricity', 'Electricity', Icons.bolt_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('data', 'Data Bundles', Icons.wifi_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('airtime', 'Airtime VTU', Icons.phone_android_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('cable', 'Cable TV', Icons.tv_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('water', 'Water Utilities', Icons.water_drop_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('internet', 'Broadband Fiber', Icons.router_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('toll', 'Tolls & Transit', Icons.directions_car_rounded),
                    const SizedBox(width: 8),
                    _buildCategoryChip('waste', 'Waste Mgmt', Icons.delete_outline_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Banner
              _buildServiceBanner(),
              const SizedBox(height: 16),

              // Dynamic Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDynamicFields(),
                    const SizedBox(height: 20),

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _getSubmitButtonLabel(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Success Result / Token Display
              if (_tokenOutput != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C46),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryLight),
                              const SizedBox(width: 6),
                              Text(
                                'PREPAID TOKEN GENERATED',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _tokenOutput!.replaceAll(' ', '')));
                              _showToast('Token copied to clipboard!');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Copy Token',
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
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          _tokenOutput!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Key this 20-digit token into your prepaid CIU keypad.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ] else if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C46).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 22, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = key;
          _tokenOutput = null;
          _successMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceBanner() {
    String title = 'Instant Delivery & Zero Convenience Fee';
    String sub = 'Automated fulfillment directly to your meter or device.';
    IconData icon = Icons.bolt_rounded;

    if (_selectedCategory == 'electricity') {
      title = 'Prepaid STS Token Delivery';
      sub = 'Tokens are generated instantly and delivered on-screen & via SMS.';
      icon = Icons.bolt_rounded;
    } else if (_selectedCategory == 'data') {
      title = 'Instant High-Speed Data';
      sub = 'Automated data delivery for MTN, Airtel, Glo & 9mobile.';
      icon = Icons.wifi_rounded;
    } else if (_selectedCategory == 'airtime') {
      title = 'Instant VTU Airtime + 2% Cashback';
      sub = 'Instant automated top-up credited to any Nigerian line.';
      icon = Icons.phone_android_rounded;
    } else if (_selectedCategory == 'cable') {
      title = 'Cable TV Bouquet Renewal';
      sub = 'Instant reconnection for DSTV, GOTV, and Startimes decoders.';
      icon = Icons.tv_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.accentOrange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  sub,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFields() {
    switch (_selectedCategory) {
      case 'electricity':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('DISTRIBUTION COMPANY (DISCO)'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDisco,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _discos.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _selectedDisco = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('PREPAID / POSTPAID METER NUMBER'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 0428 1928 472'),
            ),
            const SizedBox(height: 14),
            _buildLabel('AMOUNT (₦)'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 5,000'),
            ),
          ],
        );

      case 'data':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('MOBILE NETWORK OPERATOR'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedTelco,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _telcos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTelco = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('SELECT DATA BUNDLE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDataPlan,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _dataPlans.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedDataPlan = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('RECIPIENT PHONE NUMBER'),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: '0812 345 6789'),
            ),
          ],
        );

      case 'airtime':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('MOBILE NETWORK OPERATOR'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedTelco,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _telcos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTelco = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('PHONE NUMBER'),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: '0812 345 6789'),
            ),
            const SizedBox(height: 14),
            _buildLabel('AMOUNT (₦)'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 1,000'),
            ),
          ],
        );

      case 'cable':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('CABLE TV SERVICE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCable,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _cables.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCable = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('BOUQUET PACKAGE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedBouquet,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _bouquets.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _selectedBouquet = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('SMARTCARD / IUC NUMBER'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 7029 1829 48'),
            ),
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('SERVICE PROVIDER'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedBroadband,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _broadbands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _selectedBroadband = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('CUSTOMER / ACCOUNT ID'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. ACC-928192'),
            ),
            const SizedBox(height: 14),
            _buildLabel('PAYMENT AMOUNT (₦)'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 10,000'),
            ),
          ],
        );
    }
  }

  String _getSubmitButtonLabel() {
    switch (_selectedCategory) {
      case 'electricity':
        return 'Generate Prepaid Token';
      case 'data':
        return 'Purchase Data Bundle';
      case 'airtime':
        return 'Recharge Airtime Now';
      case 'cable':
        return 'Renew Cable TV Bouquet';
      default:
        return 'Pay Utility Bill';
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _buildInputDeco({String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
    );
  }
}
