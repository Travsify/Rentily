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
  final _bursarEmailController = TextEditingController();

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

  bool _isManualSchoolEntry = false;
  Map<String, String>? _selectedUniversity;

  final List<Map<String, String>> _allUniversities = [
    // --- UNITED KINGDOM (GB) ---
    {'name': 'Coventry University', 'country': 'GB', 'city': 'Coventry', 'bank': 'Barclays Bank UK', 'sort': '20-23-55', 'account': '80231940', 'bic': 'BARCGB22'},
    {'name': 'University of Manchester', 'country': 'GB', 'city': 'Manchester', 'bank': 'NatWest Bank', 'sort': '01-05-51', 'account': '42109845', 'bic': 'NWBKGB2L'},
    {'name': 'University of Birmingham', 'country': 'GB', 'city': 'Birmingham', 'bank': 'Barclays Bank UK', 'sort': '20-08-44', 'account': '70912340', 'bic': 'BARCGB22'},
    {'name': 'University of Leeds', 'country': 'GB', 'city': 'Leeds', 'bank': 'HSBC UK Bank', 'sort': '40-27-15', 'account': '61029384', 'bic': 'MIDLGB22'},
    {'name': 'University of Hertfordshire', 'country': 'GB', 'city': 'Hatfield', 'bank': 'Barclays Bank UK', 'sort': '20-74-05', 'account': '50921478', 'bic': 'BARCGB22'},
    {'name': 'University of East London', 'country': 'GB', 'city': 'London', 'bank': 'NatWest Bank', 'sort': '60-00-01', 'account': '33419082', 'bic': 'NWBKGB2L'},
    {'name': 'University of Warwick', 'country': 'GB', 'city': 'Coventry', 'bank': 'Barclays Bank UK', 'sort': '20-23-60', 'account': '10492837', 'bic': 'BARCGB22'},
    {'name': 'University of Oxford', 'country': 'GB', 'city': 'Oxford', 'bank': 'Barclays Bank UK', 'sort': '20-65-82', 'account': '90281472', 'bic': 'BARCGB22'},
    {'name': 'University of Cambridge', 'country': 'GB', 'city': 'Cambridge', 'bank': 'Barclays Bank UK', 'sort': '20-17-68', 'account': '40182736', 'bic': 'BARCGB22'},
    {'name': 'University of Edinburgh', 'country': 'GB', 'city': 'Edinburgh', 'bank': 'Royal Bank of Scotland', 'sort': '83-06-08', 'account': '10293847', 'bic': 'RBOSGB2L'},
    {'name': 'Northumbria University', 'country': 'GB', 'city': 'Newcastle', 'bank': 'Lloyds Bank', 'sort': '30-93-79', 'account': '01928374', 'bic': 'LOYDGB21'},
    {'name': 'Teesside University', 'country': 'GB', 'city': 'Middlesbrough', 'bank': 'NatWest Bank', 'sort': '56-00-45', 'account': '20192837', 'bic': 'NWBKGB2L'},
    {'name': 'Sheffield Hallam University', 'country': 'GB', 'city': 'Sheffield', 'bank': 'Barclays Bank UK', 'sort': '20-76-92', 'account': '50192837', 'bic': 'BARCGB22'},

    // --- UNITED STATES (US) ---
    {'name': 'Arizona State University (ASU)', 'country': 'US', 'city': 'Tempe, AZ', 'bank': 'JPMorgan Chase Bank', 'sort': '122100024', 'account': '489201948', 'bic': 'CHASUS33'},
    {'name': 'New York University (NYU)', 'country': 'US', 'city': 'New York, NY', 'bank': 'Citibank N.A.', 'sort': '021000089', 'account': '938401928', 'bic': 'CITIUS33'},
    {'name': 'Harvard University', 'country': 'US', 'city': 'Cambridge, MA', 'bank': 'Bank of America', 'sort': '011000138', 'account': '748392019', 'bic': 'BOFAUS3N'},
    {'name': 'University of North Texas (UNT)', 'country': 'US', 'city': 'Denton, TX', 'bank': 'Wells Fargo Bank', 'sort': '111000614', 'account': '582910492', 'bic': 'WFBIUS6S'},
    {'name': 'University of Texas at Arlington', 'country': 'US', 'city': 'Arlington, TX', 'bank': 'Bank of America', 'sort': '111000025', 'account': '682910482', 'bic': 'BOFAUS3N'},
    {'name': 'University of South Florida', 'country': 'US', 'city': 'Tampa, FL', 'bank': 'Truist Bank', 'sort': '063100277', 'account': '394820194', 'bic': 'SNTRUS3A'},
    {'name': 'Illinois Institute of Technology', 'country': 'US', 'city': 'Chicago, IL', 'bank': 'JPMorgan Chase Bank', 'sort': '071000013', 'account': '294810293', 'bic': 'CHASUS33'},
    {'name': 'Northeastern University', 'country': 'US', 'city': 'Boston, MA', 'bank': 'Bank of America', 'sort': '011000138', 'account': '902819401', 'bic': 'BOFAUS3N'},
    {'name': 'University of Southern California', 'country': 'US', 'city': 'Los Angeles, CA', 'bank': 'Wells Fargo Bank', 'sort': '121000248', 'account': '102938475', 'bic': 'WFBIUS6S'},

    // --- CANADA (CA) ---
    {'name': 'University of Toronto', 'country': 'CA', 'city': 'Toronto, ON', 'bank': 'Royal Bank of Canada', 'sort': '00002-003', 'account': '1029384', 'bic': 'ROYCCAT2'},
    {'name': 'University of British Columbia', 'country': 'CA', 'city': 'Vancouver, BC', 'bank': 'TD Canada Trust', 'sort': '00040-004', 'account': '4920194', 'bic': 'TDOMCATTTOR'},
    {'name': 'McGill University', 'country': 'CA', 'city': 'Montreal, QC', 'bank': 'Bank of Montreal', 'sort': '00011-001', 'account': '3920194', 'bic': 'BOFMCAM2'},
    {'name': 'York University', 'country': 'CA', 'city': 'Toronto, ON', 'bank': 'Scotiabank', 'sort': '00022-002', 'account': '5829104', 'bic': 'NOSCCATT'},
    {'name': 'Conestoga College', 'country': 'CA', 'city': 'Kitchener, ON', 'bank': 'CIBC Bank', 'sort': '00055-010', 'account': '6829104', 'bic': 'CIBCCATT'},
    {'name': 'Seneca Polytechnic', 'country': 'CA', 'city': 'Toronto, ON', 'bank': 'TD Canada Trust', 'sort': '00040-004', 'account': '7829104', 'bic': 'TDOMCATTTOR'},
    {'name': 'Centennial College', 'country': 'CA', 'city': 'Toronto, ON', 'bank': 'Scotiabank', 'sort': '00022-002', 'account': '8920194', 'bic': 'NOSCCATT'},

    // --- GERMANY (DE) ---
    {'name': 'Technical University of Munich (TUM)', 'country': 'DE', 'city': 'Munich', 'bank': 'Deutsche Bank AG', 'sort': 'DEUTDEDBMUC', 'account': 'DE89700700100123456700', 'bic': 'DEUTDEDBMUC'},
    {'name': 'Heidelberg University', 'country': 'DE', 'city': 'Heidelberg', 'bank': 'BW-Bank', 'sort': 'SOLADEST600', 'account': 'DE23600501010001234567', 'bic': 'SOLADEST600'},
    {'name': 'Humboldt University of Berlin', 'country': 'DE', 'city': 'Berlin', 'bank': 'Berliner Sparkasse', 'sort': 'BELADEBEXXX', 'account': 'DE77100500001060012345', 'bic': 'BELADEBEXXX'},
    {'name': 'RWTH Aachen University', 'country': 'DE', 'city': 'Aachen', 'bank': 'Sparkasse Aachen', 'sort': 'AACSDE33XXX', 'account': 'DE45390500000001234567', 'bic': 'AACSDE33XXX'},

    // --- IRELAND (IE) ---
    {'name': 'Trinity College Dublin', 'country': 'IE', 'city': 'Dublin', 'bank': 'Bank of Ireland', 'sort': 'BOFIIE2D', 'account': 'IE29BOFI90001712345678', 'bic': 'BOFIIE2D'},
    {'name': 'University College Dublin (UCD)', 'country': 'IE', 'city': 'Dublin', 'bank': 'Allied Irish Banks (AIB)', 'sort': 'AIBKIE2D', 'account': 'IE44AIBK93115212345678', 'bic': 'AIBKIE2D'},

    // --- FRANCE (FR) ---
    {'name': 'Sorbonne University', 'country': 'FR', 'city': 'Paris', 'bank': 'BNP Paribas', 'sort': 'BNPAFRPP', 'account': 'FR7630004001230001234567890', 'bic': 'BNPAFRPP'},
    {'name': 'École Polytechnique', 'country': 'FR', 'city': 'Palaiseau', 'bank': 'Société Générale', 'sort': 'SOGEFRPP', 'account': 'FR7630003000450001234567891', 'bic': 'SOGEFRPP'},
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
    _bursarEmailController.dispose();
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
      _selectedUniversity = null;
      _isManualSchoolEntry = false;
      _schoolController.clear();
      _ibanController.clear();
      _sortCodeController.clear();
      _bankNameController.clear();
      _countdownTimer?.cancel();
    });
  }

  void _selectUniversity(Map<String, String> u) {
    setState(() {
      _selectedUniversity = u;
      _isManualSchoolEntry = false;
      _schoolController.text = u['name']!;
      _bankNameController.text = u['bank']!;
      _sortCodeController.text = u['sort']!;
      _ibanController.text = u['account']!;
    });
  }

  void _showUniversityPickerModal() {
    final countrySchools = _allUniversities.where((u) => u['country'] == _selectedCountry).toList();
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(countrySchools);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select University',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search university or city...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          if (val.trim().isEmpty) {
                            filtered = List.from(countrySchools);
                          } else {
                            final term = val.toLowerCase().trim();
                            filtered = countrySchools.where((u) {
                              return u['name']!.toLowerCase().contains(term) ||
                                  u['city']!.toLowerCase().contains(term) ||
                                  u['bank']!.toLowerCase().contains(term);
                            }).toList();
                          }
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off_rounded, color: AppColors.textSecondary, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'School not found in directory',
                                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'You can enter your institution\'s bank coordinates manually.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _isManualSchoolEntry = true;
                                      _selectedUniversity = null;
                                      _schoolController.text = searchCtrl.text.trim();
                                    });
                                  },
                                  icon: const Icon(Icons.edit_note, size: 18),
                                  label: const Text('Enter School Manually'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            final isSel = _selectedUniversity?['name'] == item['name'];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                _selectUniversity(item);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.backgroundDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isSel ? AppColors.primary : AppColors.borderDark),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceDark,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.borderDark),
                                      ),
                                      child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                item['city']!,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Verified Bank Coordinates',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.mint,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Bank: ${item['bank']} • Acc: ${item['account']}',
                                            style: GoogleFonts.spaceMono(
                                              fontSize: 10,
                                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSel)
                                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isManualSchoolEntry = true;
                        _selectedUniversity = null;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                    label: Text(
                      'Can\'t find your school? Enter details manually',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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

    if (_ibanController.text.trim().isEmpty || _sortCodeController.text.trim().isEmpty) {
      _showSnackbar('Please provide university bank clearing coordinates (Account/IBAN and Sort/Routing code).');
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
        'bursarEmail': _bursarEmailController.text.trim(),
        'documentUrl': _invoiceUrlController.text.trim(),
        'pin': pin,
        'beneficiary': {
          'name': _schoolController.text.trim(),
          'countryCode': _selectedCountry,
          'currency': _selectedCurrency,
          'bankName': _bankNameController.text.trim().isNotEmpty
              ? _bankNameController.text.trim()
              : '${_schoolController.text.trim()} Settlement Bank',
          'accountNumberOrIban': _ibanController.text.trim(),
          'routingCode': _sortCodeController.text.trim(),
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
    final matchedCountry = _countries.firstWhere((c) => c['code'] == _selectedCountry);

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

            // Official Invoice Advisory Banner
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF818CF8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Directory provides standard clearing banks. If your official tuition invoice or admission letter specifies a dedicated student IBAN or bank sub-account, tap "Manual Entry Mode" to input your exact coordinates.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // University Information & Searchable Directory
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionLabel('University / Institution'),
                if (!_isManualSchoolEntry)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isManualSchoolEntry = true;
                        _selectedUniversity = null;
                        _schoolController.clear();
                        _bankNameController.clear();
                        _sortCodeController.clear();
                        _ibanController.clear();
                      });
                    },
                    child: Text(
                      'Manual Entry Mode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isManualSchoolEntry = false;
                      });
                      _showUniversityPickerModal();
                    },
                    child: Text(
                      '← Search Directory',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_isManualSchoolEntry) ...[
              InkWell(
                onTap: _showUniversityPickerModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedUniversity != null ? AppColors.mint.withOpacity(0.5) : AppColors.borderDark,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _selectedUniversity != null
                              ? const Color(0xFF064E3B).withOpacity(0.3)
                              : AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedUniversity != null ? Icons.verified_rounded : Icons.search_rounded,
                          color: _selectedUniversity != null ? AppColors.mint : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUniversity != null ? _selectedUniversity!['name']! : 'Select School from Verified Directory',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedUniversity != null ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selectedUniversity != null
                                  ? '${_selectedUniversity!['city']} • ${_selectedUniversity!['bank']} ✓'
                                  : 'Auto-populates verified bank routing & account coordinates',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: _selectedUniversity != null ? AppColors.mint : AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildTextField(
                controller: _schoolController,
                hint: 'e.g. University of Manchester / Harvard University',
                icon: Icons.school,
              ),
            ],
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
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Academic Term / Semester'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _semesterController,
                        hint: 'e.g. Fall Semester 2026/2027',
                        icon: Icons.calendar_today,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Bursar / Finance Email'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _bursarEmailController,
                        hint: 'bursar@university.ac.uk',
                        icon: Icons.email,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSectionLabel('Tuition Invoice / Offer Letter (URL or Ref)'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _invoiceUrlController,
              hint: 'Paste document link or university payment reference',
              icon: Icons.attach_file_rounded,
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
