import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/reloadly_models.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/rentilly_bottom_bar.dart';
import '../bills/bills_screen.dart';

class LifestyleHubScreen extends StatefulWidget {
  final int initialTabIndex; // 0: International Bills, 1: Gift Cards, 2: Crypto, 3: eSIM

  const LifestyleHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LifestyleHubScreen> createState() => _LifestyleHubScreenState();
}

class _LifestyleHubScreenState extends State<LifestyleHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeCategoryIndex = 0;
  UserProfile? _user;
  final NumberFormat _nairaFormat = NumberFormat('#,##0', 'en_US');
  final double _fxRate = 1549.00; // Standardized: 1510 + 39 NGN

  // --- Global 150+ Countries & Search State ---
  List<ReloadlyCountry> _countries = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- Tab 0: International Utilities & Airtime (Reloadly) ---
  String _selectedCountryCode = 'NG';
  final List<Map<String, String>> _supportedCountries = [
    {'code': 'NG', 'name': 'Nigeria (Prepaid & Postpaid DisCos)', 'flag': '🇳🇬', 'prefix': '+234'},
    {'code': 'SN', 'name': 'Senegal (Sen-Elec, Water, Toll)', 'flag': '🇸🇳', 'prefix': '+221'},
    {'code': 'ZA', 'name': 'South Africa (Prepaid Electricity)', 'flag': '🇿🇦', 'prefix': '+27'},
    {'code': 'ML', 'name': 'Mali (Canal+ TV)', 'flag': '🇲🇱', 'prefix': '+223'},
    {'code': 'ZW', 'name': 'Zimbabwe (Prepaid Electricity)', 'flag': '🇿🇼', 'prefix': '+263'},
    {'code': 'SL', 'name': 'Sierra Leone (Electricity)', 'flag': '🇸🇱', 'prefix': '+232'},
    {'code': 'MZ', 'name': 'Mozambique (Prepaid Electricity)', 'flag': '🇲🇿', 'prefix': '+258'},
    {'code': 'MW', 'name': 'Malawi (Prepaid Electricity)', 'flag': '🇲🇼', 'prefix': '+265'},
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸', 'prefix': '+1'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧', 'prefix': '+44'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦', 'prefix': '+1'},
    {'code': 'GH', 'name': 'Ghana', 'flag': '🇬🇭', 'prefix': '+233'},
    {'code': 'KE', 'name': 'Kenya', 'flag': '🇰🇪', 'prefix': '+254'},
    {'code': 'AE', 'name': 'United Arab Emirates', 'flag': '🇦🇪', 'prefix': '+971'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳', 'prefix': '+91'},
  ];

  List<ReloadlyBiller> _billers = [];
  bool _isLoadingBillers = true;
  ReloadlyBiller? _selectedBiller;
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _utilAmountController = TextEditingController();
  MeterValidationResult? _meterValidation;
  bool _isValidatingMeter = false;
  bool _isPayingBill = false;
  String? _utilError;

  // --- Tab 2: Gift Cards State ---
  List<ReloadlyProduct> _giftCardProducts = [];
  bool _isLoadingGiftCards = true;

  // --- Tab 3: Crypto Vouchers State ---
  List<ReloadlyProduct> _cryptoProducts = [];
  bool _isLoadingCrypto = true;

  // --- Tab 4: eSIM State ---
  List<ReloadlyProduct> _esimProducts = [];
  bool _isLoadingEsim = true;

  // --- User Vouchers Vault ---
  List<ReloadlyVoucherRecord> _myVouchers = [];
  bool _isLoadingVouchers = false;

  @override
  void initState() {
    super.initState();
    _activeCategoryIndex = widget.initialTabIndex.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: _activeCategoryIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _activeCategoryIndex = _tabController.index);
      }
    });

    _loadCountries();
    _loadUser();
    _loadBillersForCountry(_selectedCountryCode);
    _loadGiftCards();
    _loadCrypto();
    _loadEsim();
    _loadUserVouchers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _meterController.dispose();
    _utilAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _loadCountries() async {
    try {
      final list = await ApiService.fetchReloadlyCountries();
      if (mounted) {
        setState(() {
          _countries = list;
        });
      }
    } catch (_) {}
  }

  void _showCountryPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final activeCountries = _countries.isNotEmpty
                ? _countries
                : _supportedCountries.map((c) => ReloadlyCountry(
                    code: c['code']!,
                    name: c['name']!,
                    flag: c['flag']!,
                    prefix: c['prefix']!,
                    currencyCode: 'USD',
                  )).toList();

            final filtered = filter.trim().isEmpty
                ? activeCountries
                : activeCountries.where((c) =>
                    c.name.toLowerCase().contains(filter.toLowerCase()) ||
                    c.code.toLowerCase().contains(filter.toLowerCase()) ||
                    c.prefix.contains(filter)).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Destination Country', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => filter = val),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search 150+ countries by name, code, or dial (+1, +44)...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.backgroundDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderDark),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final isSelected = c.code == _selectedCountryCode;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                          title: Text(c.name, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                          subtitle: Text('${c.code} • ${c.prefix} • ${c.currencyCode}', style: GoogleFonts.spaceMono(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) : null,
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = c.code;
                            });
                            Navigator.pop(ctx);
                            _loadBillersForCountry(c.code);
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
      },
    );
  }

  Widget _buildBrandInitials(String brandName, String colorHex) {
    Color color;
    try {
      final hex = colorHex.replaceFirst('#', '').replaceFirst('0x', '');
      color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      color = AppColors.primary;
    }
    final initials = brandName.trim().isNotEmpty
        ? brandName.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
        : 'GC';
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.spaceMono(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }


  Future<void> _loadBillersForCountry(String code) async {
    setState(() {
      _isLoadingBillers = true;
      _billers = [];
      _selectedBiller = null;
      _meterValidation = null;
      _utilError = null;
    });

    // Also reload gift cards for the selected country
    _loadGiftCards(countryCode: code);

    try {
      final list = await ApiService.fetchReloadlyBillers(countryCode: code);
      if (mounted) {
        setState(() {
          _billers = list;
          _isLoadingBillers = false;
          if (list.isNotEmpty) {
            _selectedBiller = list.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBillers = false);
    }
  }

  Future<void> _loadGiftCards({String? countryCode}) async {
    setState(() => _isLoadingGiftCards = true);
    final list = await ApiService.fetchReloadlyProducts(
      category: 'giftcards',
      countryCode: countryCode ?? _selectedCountryCode,
    );
    if (mounted) {
      setState(() {
        _giftCardProducts = list;
        _isLoadingGiftCards = false;
      });
    }
  }

  Future<void> _loadCrypto() async {
    setState(() => _isLoadingCrypto = true);
    final list = await ApiService.fetchReloadlyProducts(category: 'crypto');
    if (mounted) {
      setState(() {
        _cryptoProducts = list;
        _isLoadingCrypto = false;
      });
    }
  }

  Future<void> _loadEsim() async {
    setState(() => _isLoadingEsim = true);
    final list = await ApiService.fetchReloadlyProducts(category: 'esim');
    if (mounted) {
      setState(() {
        _esimProducts = list;
        _isLoadingEsim = false;
      });
    }
  }

  Future<void> _loadUserVouchers() async {
    final email = _user?.email;
    if (email == null) return;
    setState(() => _isLoadingVouchers = true);
    final list = await ApiService.fetchUserReloadlyVouchers(email);
    if (mounted) {
      setState(() {
        _myVouchers = list;
        _isLoadingVouchers = false;
      });
    }
  }

  Future<void> _validateMeter() async {
    final meter = _meterController.text.trim();
    if (meter.isEmpty || _selectedBiller == null) {
      setState(() => _utilError = 'Please enter a meter number');
      return;
    }

    setState(() {
      _isValidatingMeter = true;
      _utilError = null;
      _meterValidation = null;
    });

    try {
      final res = await ApiService.validateReloadlyMeter(
        billerId: _selectedBiller!.id,
        accountNumber: meter,
      );
      if (mounted) {
        setState(() {
          _meterValidation = res;
          _isValidatingMeter = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _utilError = e.toString().replaceAll('Exception:', '').trim();
          _isValidatingMeter = false;
        });
      }
    }
  }

  Future<void> _payInternationalUtility() async {
    final user = _user;
    if (user == null) return;

    final meter = _meterController.text.trim();
    final amt = double.tryParse(_utilAmountController.text.replaceAll(',', '').trim()) ?? 0;

    if (meter.isEmpty || _selectedBiller == null) {
      setState(() => _utilError = 'Please enter a meter number');
      return;
    }
    if (amt < 500) {
      setState(() => _utilError = 'Minimum purchase amount is ₦500');
      return;
    }
    if ((user.walletBalance) < amt) {
      setState(() => _utilError = 'Insufficient wallet balance. Available: ₦${_nairaFormat.format(user.walletBalance)}');
      return;
    }

    setState(() {
      _isPayingBill = true;
      _utilError = null;
    });

    try {
      final res = await ApiService.payReloadlyBill(
        email: user.email,
        billerId: _selectedBiller!.id,
        billerName: _selectedBiller!.name,
        accountNumber: meter,
        amountNgn: amt,
        customerName: _meterValidation?.customerName,
        address: _meterValidation?.address,
      );

      final token = res['token']?.toString();
      final units = res['units']?.toString();

      await _loadUser();

      if (mounted) {
        setState(() {
          _isPayingBill = false;
        });
        _showTokenSuccessDialog(token ?? 'VERIFIED_ON_GRID', units ?? 'Calculated', meter, amt);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPayingBill = false;
          _utilError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _showTokenSuccessDialog(String token, String units, String meter, double amount) {
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
              child: const Icon(Icons.bolt_rounded, color: AppColors.mint, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Token Generated ✓',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter this 20-digit token into your meter keypad:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                token,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.mint,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Units: $units kWh', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Meter: $meter', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
            label: Text('Copy Token', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token.replaceAll(' ', '')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('20-Digit token copied to clipboard ✓'), duration: Duration(seconds: 1)),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPurchaseProductModal(ReloadlyProduct product) {
    final user = _user;
    if (user == null) return;

    double selectedAmount = product.suggestedDenominations.isNotEmpty
        ? product.suggestedDenominations.first
        : (product.minDenomination ?? 10.0);

    final TextEditingController customAmountCtrl = TextEditingController(
      text: selectedAmount.toInt().toString(),
    );

    bool isOrdering = false;
    String? orderError;

    Color brandColor;
    try {
      final hex = product.brandColorHex.replaceFirst('#', '').replaceFirst('0x', '');
      brandColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      brandColor = AppColors.primary;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final nairaCost = (selectedAmount * _fxRate).round();
          final hasBalance = (user.walletBalance) >= nairaCost;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: product.logoUrl.isNotEmpty
                            ? Image.network(
                                product.logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildBrandInitials(product.brandName, product.brandColorHex),
                              )
                            : _buildBrandInitials(product.brandName, product.brandColorHex),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.productName, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(product.categoryName, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: brandColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(product.denominationType, style: GoogleFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.bold, color: brandColor)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (product.discountPercentage > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('${product.discountPercentage}% OFF', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mint)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Denomination Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Value (USD)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text('Equivalent in NGN', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Preset Chips
                  if (product.suggestedDenominations.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.suggestedDenominations.map((denom) {
                        final isSelected = selectedAmount == denom;
                        final chipNgn = (denom * _fxRate).round();
                        return ChoiceChip(
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('\$${denom.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary)),
                              Text('₦${_nairaFormat.format(chipNgn)}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: isSelected ? Colors.white70 : AppColors.textSecondary)),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: brandColor,
                          backgroundColor: AppColors.backgroundDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? brandColor : AppColors.borderDark)),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedAmount = denom;
                                customAmountCtrl.text = denom.toInt().toString();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                  // Custom Amount for RANGE cards
                  if (product.isRange) ...[
                    const SizedBox(height: 14),
                    Text('OR ENTER CUSTOM AMOUNT (USD)', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customAmountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.spaceMono(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: GoogleFonts.spaceMono(color: brandColor, fontWeight: FontWeight.bold, fontSize: 16),
                        hintText: 'Enter amount',
                        helperText: 'Allowed Range: \$${product.minDenomination?.toInt() ?? 5} - \$${product.maxDenomination?.toInt() ?? 500} USD',
                        helperStyle: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.backgroundDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.replaceAll(',', '').trim());
                        if (parsed != null && parsed > 0) {
                          setModalState(() => selectedAmount = parsed);
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Exchange & Settlement Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Wallet Deduction', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text('₦${_nairaFormat.format(nairaCost)} NGN', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Direct FX Rate', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text('\$1 = ₦1,549', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ],
                            ),
                          ],
                        ),
                        if (product.redeemInstructions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.borderDark),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  product.redeemInstructions,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (orderError != null) ...[
                    const SizedBox(height: 10),
                    Text(orderError!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.redAccent)),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasBalance ? AppColors.primary : Colors.grey[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isOrdering || !hasBalance ? null : () async {
                        final minD = product.minDenomination ?? 5.0;
                        final maxD = product.maxDenomination ?? 1000.0;
                        if (selectedAmount < minD || selectedAmount > maxD) {
                          setModalState(() => orderError = 'Amount must be between \$${minD.toInt()} and \$${maxD.toInt()} USD');
                          return;
                        }

                        setModalState(() {
                          isOrdering = true;
                          orderError = null;
                        });

                        try {
                          final res = await ApiService.orderReloadlyGiftCard(
                            email: user.email,
                            productId: product.productId,
                            unitPriceUsd: selectedAmount,
                            recipientEmail: user.email,
                            senderName: user.fullName,
                          );

                          await _loadUser();
                          await _loadUserVouchers();

                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            _showVoucherFulfilledDialog(res['voucher'] ?? res['data'] ?? res);
                          }
                        } catch (e) {
                          setModalState(() {
                            isOrdering = false;
                            orderError = e.toString().replaceAll('Exception:', '').trim();
                          });
                        }
                      },
                      child: isOrdering
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              hasBalance ? 'Pay ₦${_nairaFormat.format(nairaCost)} & Claim Code' : 'Insufficient Wallet Balance (₦${_nairaFormat.format(user.walletBalance)})',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  void _showVoucherFulfilledDialog(dynamic voucher) {
    final v = voucher is Map ? ReloadlyVoucherRecord.fromJson(voucher as Map<String, dynamic>) : voucher as ReloadlyVoucherRecord;

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
              child: const Icon(Icons.card_giftcard_rounded, color: AppColors.mint, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Voucher Delivered! 🎁',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.productName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('Value: \$${v.amountUsd.toInt()} USD (₦${_nairaFormat.format(v.amountNgn)})', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 14),

            if (v.cardNumber != null && v.cardNumber!.isNotEmpty) ...[
              Text('Card / Claim Code:', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
                child: SelectableText(
                  v.cardNumber!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (v.pinCode != null && v.pinCode!.isNotEmpty) ...[
              Text('Security PIN:', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
                child: SelectableText(v.pinCode!, textAlign: TextAlign.center, style: GoogleFonts.spaceMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 8),
            ],

            if (v.claimUrl != null && v.claimUrl!.isNotEmpty) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open Direct Claim Link'),
                onPressed: () => launchUrl(Uri.parse(v.claimUrl!), mode: LaunchMode.externalApplication),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMyVouchersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Vouchers & Cards Vault 🎟️', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoadingVouchers
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _myVouchers.isEmpty
                        ? Center(
                            child: Text('No purchased vouchers yet.\nBuy digital gift cards or travel eSIMs to view codes here.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                          )
                        : ListView.separated(
                        controller: scrollController,
                        itemCount: _myVouchers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final v = _myVouchers[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(v.productName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    Text('\$${v.amountUsd.toInt()} USD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (v.cardNumber != null) ...[
                                  SelectableText('Code: ${v.cardNumber}', style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.mint)),
                                ],
                                if (v.pinCode != null) ...[
                                  SelectableText('PIN: ${v.pinCode}', style: GoogleFonts.spaceMono(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      bottomNavigationBar: const RentillyBottomBar(currentIndex: -1),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lifestyle & Utilities Desk',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              'Global Multi-Currency Rails (150+ Countries)',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
            tooltip: 'My Vouchers',
            onPressed: _showMyVouchersSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 2x2 Category Grid (Required by Architecture) ───
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryGridTile(
                        index: 0,
                        title: 'International Bills',
                        subtitle: 'Airtime & Utilities',
                        badge: '150+ COUNTRIES',
                        icon: Icons.public_rounded,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCategoryGridTile(
                        index: 1,
                        title: 'Gift Cards',
                        subtitle: '300+ Global Brands',
                        badge: 'GLOBAL',
                        icon: Icons.card_giftcard_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryGridTile(
                        index: 2,
                        title: 'Crypto Vouchers',
                        subtitle: 'Binance USDT & Pay',
                        badge: 'INSTANT',
                        icon: Icons.currency_bitcoin_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCategoryGridTile(
                        index: 3,
                        title: 'Travel eSIM',
                        subtitle: 'Airalo & Roaming',
                        badge: '5G FAST',
                        icon: Icons.sim_card_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Tab Content View ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInternationalBillsTab(),
                _buildGiftCardsTab(),
                _buildCryptoTab(),
                _buildEsimTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGridTile({
    required int index,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _activeCategoryIndex == index;

    return InkWell(
      onTap: () {
        _tabController.animateTo(index);
        setState(() => _activeCategoryIndex = index);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.borderDark,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. INTERNATIONAL BILLS & TOP-UPS TAB ---
  Widget _buildInternationalBillsTab() {
    final curCountry = _supportedCountries.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => _supportedCountries.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner clearly separating local from international
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.public_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Global Lifestyle Utilities',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF38BDF8)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Top up airtime, data and utilities across 150+ countries with live wallet conversion.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BillsScreen(initialCategory: 'electricity')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.electric_meter_rounded, size: 14, color: AppColors.mint),
                        const SizedBox(width: 6),
                        Text(
                          'Switch to Nigerian Local Bills →',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.mint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Destination Country', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              InkWell(
                onTap: _showCountryPickerBottomSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Browse 150+ Countries', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showCountryPickerBottomSheet,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
              child: Row(
                children: [
                  Text(curCountry['flag'] ?? '🌐', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(curCountry['name'] ?? 'Selected Country', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('Prefix: ${curCountry['prefix'] ?? '+'} • ISO: ${curCountry['code'] ?? _selectedCountryCode}', style: GoogleFonts.spaceMono(fontSize: 10.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingBillers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else ...[
            if (_billers.isNotEmpty) ...[
              Text('Select Provider / Utility', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReloadlyBiller>(
                    value: _selectedBiller,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceDark,
                    items: _billers.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBiller = val;
                          _meterValidation = null;
                          _utilError = null;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

            Text('Account / Meter / Phone Number', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _meterController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.spaceMono(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText: '${curCountry['prefix']} ',
                      prefixStyle: GoogleFonts.spaceMono(color: AppColors.textSecondary),
                      hintText: 'e.g. 5550192834',
                      hintStyle: GoogleFonts.spaceMono(fontSize: 13, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
                    ),
                  ),
                ),
                if (_billers.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isValidatingMeter ? null : _validateMeter,
                    child: _isValidatingMeter
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Verify', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ],
            ),

            if (_meterValidation != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF064E3B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.mint.withValues(alpha: 0.4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 16),
                        const SizedBox(width: 6),
                        Text('Customer Verified: ${_meterValidation!.customerName}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.mint)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Address: ${_meterValidation!.address}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            Text('Recharge Amount (₦)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _utilAmountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: '₦ ',
                hintText: '5,000',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              children: [2000, 5000, 10000, 25000, 50000].map((amt) {
                return ActionChip(
                  label: Text('₦${_nairaFormat.format(amt)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  backgroundColor: AppColors.surfaceDark,
                  onPressed: () => setState(() => _utilAmountController.text = amt.toString()),
                );
              }).toList(),
            ),

            if (_utilError != null) ...[
              const SizedBox(height: 14),
              Text(_utilError!, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.redAccent)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                label: _isPayingBill
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Dispatch Payment Instantly', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isPayingBill ? null : _payInternationalUtility,
              ),
            ),
          ] else ...[
            _buildNoBillersCard(curCountry),
          ],
        ],
      ],
    ),
  );
  }

  
  Widget _buildNoBillersCard(Map<String, String> curCountry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          const Icon(Icons.flash_off_rounded, size: 40, color: Color(0xFF38BDF8)),
          const SizedBox(height: 12),
          Text(
            'No Direct Grid Billers for ${curCountry['name'] ?? _selectedCountryCode}',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Direct electricity, water & TV utilities are currently active in 8 supported corridors. Tap any supported corridor below to recharge instantly:',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickCountryChip('🇳🇬 Nigeria', 'NG'),
              _buildQuickCountryChip('🇸🇳 Senegal', 'SN'),
              _buildQuickCountryChip('🇿🇦 South Africa', 'ZA'),
              _buildQuickCountryChip('🇲🇱 Mali', 'ML'),
              _buildQuickCountryChip('🇿🇼 Zimbabwe', 'ZW'),
              _buildQuickCountryChip('🇸🇱 Sierra Leone', 'SL'),
              _buildQuickCountryChip('🇲🇿 Mozambique', 'MZ'),
              _buildQuickCountryChip('🇲🇼 Malawi', 'MW'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard_rounded, size: 16, color: Colors.white),
              label: Text('Explore 2,300+ Digital Gift Cards & eSIM', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _tabController.animateTo(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCountryChip(String label, String code) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCountryCode = code;
        });
        _loadBillersForCountry(code);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  // --- 2. DIGITAL GIFT CARDS TAB ---
  Widget _buildGiftCardsTab() {
    if (_isLoadingGiftCards) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _buildProductGrid(_giftCardProducts);
  }

  // --- 3. CRYPTO VOUCHERS TAB ---
  Widget _buildCryptoTab() {
    if (_isLoadingCrypto) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _buildProductGrid(_cryptoProducts);
  }

  // --- 4. TRAVEL eSIM TAB ---
  Widget _buildEsimTab() {
    if (_isLoadingEsim) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _buildProductGrid(_esimProducts);
  }

  Widget _buildProductGrid(List<ReloadlyProduct> products) {
    final filtered = _searchQuery.trim().isEmpty
        ? products
        : products.where((p) =>
            p.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.brandName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.categoryName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        // Real-Time Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search products by brand, country, or keyword...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDark)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 10),
                      Text('No vouchers match "$_searchQuery"', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];

                    Color brandColor;
                    try {
                      final hex = p.brandColorHex.replaceFirst('#', '').replaceFirst('0x', '');
                      brandColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
                    } catch (_) {
                      brandColor = AppColors.primary;
                    }

                    final minPrice = p.fixedDenominations.isNotEmpty
                        ? p.fixedDenominations.first
                        : (p.minDenomination ?? 10.0);
                    final startNaira = (minPrice * _fxRate).round();

                    return InkWell(
                      onTap: () => _showPurchaseProductModal(p),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderDark),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Branded top accent bar
                            Container(
                              height: 4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: brandColor,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Contrast Logo Container
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                    ),
                                    child: p.logoUrl.isNotEmpty
                                        ? Image.network(
                                            p.logoUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => _buildBrandInitials(p.brandName, p.brandColorHex),
                                          )
                                        : _buildBrandInitials(p.brandName, p.brandColorHex),
                                  ),
                                  const SizedBox(height: 10),

                                  // Product Title
                                  Text(
                                    p.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
                                  ),
                                  const SizedBox(height: 4),

                                  // Category / Country Badge
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.categoryName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      if (p.discountPercentage > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${p.discountPercentage}% OFF', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.mint)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Denominations Pill
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundDark,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.borderDark),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.isRange
                                              ? 'Custom (\$${p.minDenomination?.toInt() ?? 5} - \$${p.maxDenomination?.toInt() ?? 500})'
                                              : (p.fixedDenominations.length > 1
                                                  ? '\$${p.fixedDenominations.first.toInt()} - \$${p.fixedDenominations.last.toInt()}'
                                                  : (p.fixedDenominations.isNotEmpty
                                                      ? '\$${p.fixedDenominations.first.toInt()} USD'
                                                      : (p.suggestedDenominations.isNotEmpty
                                                          ? '\$${p.suggestedDenominations.first.toInt()} USD'
                                                          : '\$10 USD'))),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                        Text(
                                          'From ₦${_nairaFormat.format(startNaira)}',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
