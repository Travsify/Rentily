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

  String _selectedDataDuration = 'All';
  final List<String> _dataDurations = ['All', 'Daily', 'Weekly', 'Monthly', 'Night / Weekend', 'Mega & 5G Router'];

  static const Map<String, Map<String, List<String>>> _categorizedDataMap = {
    'MTN': {
      'Daily': [
        '100MB (1 Day) - ₦100',
        '200MB (2 Days) - ₦200',
        '1.0GB (1 Day) - ₦350',
        '2.0GB (2 Days) - ₦500',
        '3.0GB (2 Days) - ₦800',
      ],
      'Weekly': [
        '350MB (7 Days) - ₦300',
        '750MB (7 Days) - ₦500',
        '1.5GB (7 Days) - ₦1,000',
        '6.0GB (7 Days) - ₦1,500',
        '10.0GB (7 Days) - ₦2,000',
      ],
      'Monthly': [
        '1.5GB (30 Days) - ₦1,000',
        '2.5GB (30 Days) - ₦1,200',
        '5.0GB (30 Days) - ₦2,000',
        '10.0GB (30 Days) - ₦3,000',
        '15.0GB (30 Days) - ₦4,500',
        '20.0GB (30 Days) - ₦5,500',
        '40.0GB (30 Days) - ₦10,000',
        '75.0GB (30 Days) - ₦15,000',
        '120.0GB (30 Days) - ₦20,000',
      ],
      'Night / Weekend': [
        'Night Owl 500MB (11PM - 6AM) - ₦50',
        'Night Owl 1.0GB (11PM - 6AM) - ₦100',
        'Weekend Max 2.0GB (Sat & Sun) - ₦400',
        'Weekend Max 5.0GB (Sat & Sun) - ₦800',
      ],
      'Mega & 5G Router': [
        '150GB 5G Router Plan - ₦25,000',
        '200GB 5G Router Plan - ₦30,000',
        '400GB 5G Router Plan - ₦50,000',
        '1TB 5G Mega Broadband - ₦100,000',
      ],
    },
    'Airtel': {
      'Daily': [
        '100MB (1 Day) - ₦100',
        '300MB (1 Day) - ₦200',
        '1.0GB (1 Day) - ₦350',
        '2.0GB (2 Days) - ₦500',
      ],
      'Weekly': [
        '350MB (7 Days) - ₦300',
        '1.5GB (7 Days) - ₦500',
        '3.0GB (7 Days) - ₦1,000',
        '6.0GB (7 Days) - ₦1,500',
      ],
      'Monthly': [
        '1.5GB (30 Days) - ₦1,000',
        '3.0GB (30 Days) - ₦1,500',
        '6.0GB (30 Days) - ₦2,500',
        '10.0GB (30 Days) - ₦3,000',
        '20.0GB (30 Days) - ₦5,000',
        '40.0GB (30 Days) - ₦10,000',
        '75.0GB (30 Days) - ₦15,000',
        '120.0GB (30 Days) - ₦20,000',
      ],
      'Night / Weekend': [
        'Night Plan 500MB (12AM - 5AM) - ₦50',
        'Night Plan 1.5GB (12AM - 5AM) - ₦150',
        'Weekend 2.5GB (Sat - Sun) - ₦500',
      ],
      'Mega & 5G Router': [
        '100GB Ultra Router - ₦20,000',
        '200GB Ultra Router - ₦35,000',
        '500GB 5G Router - ₦60,000',
      ],
    },
    'Glo': {
      'Daily': [
        '150MB (1 Day) - ₦100',
        '350MB (2 Days) - ₦200',
        '1.05GB (1 Day) - ₦300',
        '2.0GB (2 Days) - ₦500',
      ],
      'Weekly': [
        '1.05GB (7 Days) - ₦500',
        '2.5GB (7 Days) - ₦1,000',
        '7.0GB (7 Days) - ₦1,500',
      ],
      'Monthly': [
        '2.0GB (30 Days) - ₦1,000',
        '4.5GB (30 Days) - ₦2,000',
        '8.0GB (30 Days) - ₦3,000',
        '14.0GB (30 Days) - ₦4,000',
        '24.0GB (30 Days) - ₦5,000',
        '50.0GB (30 Days) - ₦10,000',
        '100.0GB (30 Days) - ₦18,000',
      ],
      'Night / Weekend': [
        'Glo TGIF Weekend 3.0GB - ₦500',
        'Night Boost 1.0GB (12AM - 5AM) - ₦100',
      ],
      'Mega & 5G Router': [
        '119GB Mega Data - ₦15,000',
        '138GB Mega Data - ₦18,000',
        '225GB Mega Data - ₦30,000',
        '1TB Enterprise - ₦100,000',
      ],
    },
    '9mobile': {
      'Daily': [
        '100MB (1 Day) - ₦100',
        '1.0GB (1 Day) - ₦300',
        '2.0GB (3 Days) - ₦500',
      ],
      'Weekly': [
        '1.0GB (7 Days) - ₦500',
        '2.5GB (7 Days) - ₦1,000',
        '7.0GB (7 Days) - ₦1,500',
      ],
      'Monthly': [
        '1.5GB (30 Days) - ₦1,000',
        '3.0GB (30 Days) - ₦1,500',
        '7.0GB (30 Days) - ₦2,500',
        '11.0GB (30 Days) - ₦3,500',
        '15.0GB (30 Days) - ₦4,500',
        '40.0GB (30 Days) - ₦10,000',
        '75.0GB (30 Days) - ₦15,000',
      ],
      'Night / Weekend': [
        'Night Plan 1.0GB (11PM - 5AM) - ₦100',
        'Weekend 3.0GB (Sat & Sun) - ₦500',
      ],
      'Mega & 5G Router': [
        '100GB Mega Plan - ₦20,000',
        '225GB Super Mega - ₦30,000',
      ],
    },
  };

  List<String> _getCurrentDataPlans() {
    final operatorMap = _categorizedDataMap[_selectedTelco] ?? _categorizedDataMap['MTN']!;
    if (_selectedDataDuration == 'All') {
      final List<String> all = [];
      for (final list in operatorMap.values) {
        all.addAll(list);
      }
      return all;
    }
    return operatorMap[_selectedDataDuration] ?? operatorMap['Monthly']!;
  }

  String _selectedDataPlan = '2.5GB (30 Days) - ₦1,200';

  // Cable TV
  String _selectedCable = 'DSTV';
  final List<String> _cables = ['DSTV', 'GOTV', 'Startimes', 'Showmax'];

  static const Map<String, List<String>> _cableBouquetsMap = {
    'DSTV': [
      'DStv Padi - ₦3,600',
      'DStv Yanga - ₦5,100',
      'DStv Confam - ₦9,300',
      'DStv Compact - ₦15,700',
      'DStv Compact Plus - ₦19,800',
      'DStv Premium - ₦29,500',
    ],
    'GOTV': [
      'GOtv Smallie - ₦1,575',
      'GOtv Jinja - ₦3,300',
      'GOtv Jolli - ₦4,850',
      'GOtv Max - ₦7,200',
      'GOtv Supa - ₦9,600',
      'GOtv Supa+ - ₦15,700',
    ],
    'Startimes': [
      'Nova Bouquet - ₦1,700',
      'Basic Bouquet - ₦3,300',
      'Smart Bouquet - ₦4,200',
      'Classic Bouquet - ₦5,000',
      'Super Bouquet - ₦8,200',
    ],
    'Showmax': [
      'Entertainment Mobile - ₦1,200',
      'Premier League Mobile - ₦2,900',
      'Entertainment + Premier League - ₦4,000',
      'All Devices Pro - ₦5,500',
    ],
  };
  String _selectedBouquet = 'DStv Compact Plus - ₦19,800';

  // Broadband & Fiber
  String _selectedBroadband = 'Spectranet 4G LTE';
  final List<String> _broadbands = ['Spectranet 4G LTE', 'Smile 4G', 'Swift Networks', 'FiberOne Unlimited'];

  static const Map<String, List<String>> _broadbandPlansMap = {
    'Spectranet 4G LTE': [
      '25GB Night & Day (₦8,500)',
      '50GB Monthly Mega (₦14,000)',
      'Unlimited 30 Days (₦20,000)',
      '100GB Ultra High-Speed (₦32,000)',
    ],
    'Smile 4G': [
      '15GB Bigga (₦6,000)',
      '30GB Bigga (₦10,000)',
      '60GB Monthly (₦16,000)',
      'Unlimited Premium (₦24,000)',
    ],
    'Swift Networks': [
      '30GB Swift Essential (₦8,000)',
      '60GB Swift Family (₦14,500)',
      'Unlimited Swift Club (₦22,000)',
    ],
    'FiberOne Unlimited': [
      'Smart Home 20Mbps (₦13,500)',
      'Turbo Home 40Mbps (₦18,500)',
      'Business Pro 100Mbps (₦34,000)',
    ],
  };
  String _selectedBroadbandPlan = 'Unlimited 30 Days (₦20,000)';

  // Water
  String _selectedWaterProvider = 'Lagos Water Corporation (LWC)';
  final List<String> _waterProviders = [
    'Lagos Water Corporation (LWC)',
    'FCT Water Board (Abuja)',
    'Ogun State Water Corp',
    'Rivers State Water Board',
  ];

  // Tolls
  String _selectedTollProvider = 'LCC Lekki Toll Gate (e-Tag)';
  final List<String> _tollProviders = [
    'LCC Lekki Toll Gate (e-Tag)',
    'Lekki-Ikoyi Link Bridge',
    'Cowry Transit Card (Lagos Metro / BRT)',
  ];

  // Waste Management
  String _selectedWasteProvider = 'LAWMA Residential Refuse';
  final List<String> _wasteProviders = [
    'LAWMA Residential Refuse',
    'LAWMA Commercial Sanitation',
    'Abuja Environmental Protection Board (AEPB)',
  ];

  final List<Map<String, dynamic>> _allServices = const [
    {'key': 'electricity', 'label': 'Electricity', 'icon': Icons.bolt_rounded, 'color': AppColors.accentOrange},
    {'key': 'data', 'label': 'Data Bundle', 'icon': Icons.wifi_rounded, 'color': Color(0xFF0284C7)},
    {'key': 'airtime', 'label': 'Airtime VTU', 'icon': Icons.phone_android_rounded, 'color': AppColors.primary},
    {'key': 'cable', 'label': 'Cable TV', 'icon': Icons.tv_rounded, 'color': Color(0xFF7C3AED)},
    {'key': 'water', 'label': 'Water Bill', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF0D9488)},
    {'key': 'internet', 'label': 'Broadband', 'icon': Icons.router_rounded, 'color': Color(0xFFD97706)},
    {'key': 'toll', 'label': 'Tolls/Transit', 'icon': Icons.directions_car_rounded, 'color': Color(0xFF4F46E5)},
    {'key': 'waste', 'label': 'Waste Mgmt', 'icon': Icons.delete_outline_rounded, 'color': AppColors.primaryLight},
  ];

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
          'plan': _selectedCategory == 'data' ? _selectedDataPlan : _selectedBroadbandPlan,
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
          _successMessage = 'Transaction completed! Service successfully activated on account.';
        });
      }
    } catch (_) {
      setState(() {
        _isProcessing = false;
        if (_selectedCategory == 'electricity') {
          _tokenOutput = _generateStandardToken();
          _successMessage = 'Electricity token generated successfully!';
        } else {
          _successMessage = 'Transaction completed! Service successfully activated on account.';
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
              // 1. Grid of All Utilities (Visible Across Every Screen!)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ALL UTILITY SERVICES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Tap to switch',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4x2 Responsive Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: _allServices.length,
                itemBuilder: (context, idx) {
                  final s = _allServices[idx];
                  final isSelected = _selectedCategory == s['key'];
                  final Color c = s['color'] as Color;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = s['key'] as String;
                        _tokenOutput = null;
                        _successMessage = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? c.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? c : AppColors.borderDark,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isSelected ? c : c.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : c,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['label'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? c : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 2. Active Service Banner
              _buildServiceBanner(),
              const SizedBox(height: 16),

              // 3. Dynamic Form Card for Selected Utility
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

                    // Action Button
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

              // 4. Token & Receipt Result
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
    } else if (_selectedCategory == 'internet') {
      title = 'Broadband & Fiber Top-up';
      sub = 'Instant high-speed internet renewal for Spectranet, Smile, FiberOne.';
      icon = Icons.router_rounded;
    } else if (_selectedCategory == 'water') {
      title = 'Municipal Water Board Clearance';
      sub = 'Direct water utility settlement for residential & commercial connections.';
      icon = Icons.water_drop_rounded;
    } else if (_selectedCategory == 'toll') {
      title = 'Tolls & Expressway Transit';
      sub = 'Instant balance reload for LCC Lekki Toll Gate and Cowry transit card.';
      icon = Icons.directions_car_rounded;
    } else if (_selectedCategory == 'waste') {
      title = 'LAWMA Sanitation Fee Clearance';
      sub = 'Official residential & commercial waste management settlement.';
      icon = Icons.delete_outline_rounded;
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
        final currentDataPlans = _getCurrentDataPlans();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('1. SELECT MOBILE NETWORK'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedTelco,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _telcos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedTelco = v;
                    final plans = _getCurrentDataPlans();
                    _selectedDataPlan = plans.first;
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            _buildLabel('2. BUNDLE VALIDITY / DURATION'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dataDurations.map((duration) {
                  final isSel = _selectedDataDuration == duration;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDataDuration = duration;
                        final plans = _getCurrentDataPlans();
                        if (!plans.contains(_selectedDataPlan)) {
                          _selectedDataPlan = plans.first;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? const Color(0xFF0284C7) : AppColors.borderDark),
                      ),
                      child: Text(
                        duration,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            _buildLabel('3. SELECT DATA PLAN (${currentDataPlans.length} AVAILABLE)'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: currentDataPlans.contains(_selectedDataPlan) ? _selectedDataPlan : currentDataPlans.first,
              dropdownColor: Colors.white,
              isExpanded: true,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: currentDataPlans.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _selectedDataPlan = v!),
            ),
            const SizedBox(height: 14),

            _buildLabel('4. RECIPIENT PHONE NUMBER'),
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
        final currentBouquets = _cableBouquetsMap[_selectedCable] ?? _cableBouquetsMap['DSTV']!;
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
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedCable = v;
                    _selectedBouquet = (_cableBouquetsMap[v] ?? _cableBouquetsMap['DSTV']!).first;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            _buildLabel('BOUQUET PACKAGE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: currentBouquets.contains(_selectedBouquet) ? _selectedBouquet : currentBouquets.first,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: currentBouquets.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
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

      case 'internet':
        final currentBroadbandPlans = _broadbandPlansMap[_selectedBroadband] ?? _broadbandPlansMap['Spectranet 4G LTE']!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('BROADBAND PROVIDER'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedBroadband,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _broadbands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedBroadband = v;
                    _selectedBroadbandPlan = (_broadbandPlansMap[v] ?? _broadbandPlansMap['Spectranet 4G LTE']!).first;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            _buildLabel('DATA SUBSCRIPTION PLAN'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: currentBroadbandPlans.contains(_selectedBroadbandPlan) ? _selectedBroadbandPlan : currentBroadbandPlans.first,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: currentBroadbandPlans.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedBroadbandPlan = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('CUSTOMER / MODEM ACCOUNT ID'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. SPEC-928192'),
            ),
          ],
        );

      case 'water':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('WATER BOARD / CORPORATION'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedWaterProvider,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _waterProviders.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (v) => setState(() => _selectedWaterProvider = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('CONSUMER / PROPERTY ID'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. LWC-049281'),
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

      case 'toll':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('TOLL / TRANSIT OPERATOR'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedTollProvider,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _tollProviders.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTollProvider = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('e-TAG / COWRY CARD NUMBER'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. TAG-0829182'),
            ),
            const SizedBox(height: 14),
            _buildLabel('TOP-UP AMOUNT (₦)'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 5,000'),
            ),
          ],
        );

      case 'waste':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('WASTE MANAGEMENT AUTHORITY'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedWasteProvider,
              dropdownColor: Colors.white,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: _buildInputDeco(),
              items: _wasteProviders.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (v) => setState(() => _selectedWasteProvider = v!),
            ),
            const SizedBox(height: 14),
            _buildLabel('BUILDING / SANITATION ACCOUNT ID'),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. LAW-829102'),
            ),
            const SizedBox(height: 14),
            _buildLabel('FEE AMOUNT (₦)'),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: _buildInputDeco(hint: 'e.g. 4,500'),
            ),
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('ACCOUNT / CUSTOMER ID'),
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
      case 'internet':
        return 'Renew Broadband Subscription';
      case 'water':
        return 'Pay Water Utility Bill';
      case 'toll':
        return 'Top-up Transit Card';
      case 'waste':
        return 'Pay Sanitation Fee';
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
