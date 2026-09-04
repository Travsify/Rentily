import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';

class VerificationModal extends StatefulWidget {
  final Function(UserProfile) onSuccess;

  const VerificationModal({super.key, required this.onSuccess});

  static void show(BuildContext context, {required Function(UserProfile) onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VerificationModal(onSuccess: onSuccess),
    );
  }

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal> {
  UserProfile? _currentUser;
  int _currentStep = 0; // KYB: 0=Corporate, 1=Office, 2=Director, 3=Review. KYC: 0=Profile, 1=Address, 2=Identity

  // 36 Nigerian States + FCT
  static const List<String> _nigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno',
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'Federal Capital Territory (Abuja)',
    'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara',
    'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers',
    'Sokoto', 'Taraba', 'Yobe', 'Zamfara'
  ];

  // KYC Step 0: Personal Fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // KYB Step 0: Corporate Fields
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _cacNumberController = TextEditingController();
  final TextEditingController _tinController = TextEditingController();

  // Physical Address Fields (Collation: State, LGA, City, Street, Landmark)
  String _selectedState = 'Lagos';
  final TextEditingController _lgaController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  // Identity KYC / Director Fields
  String _selectedIdType = 'nin'; // 'nin', 'voters_card', 'drivers_license', 'passport'
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _certifiedAccurate = true;

  bool _isLoading = false;
  bool _isSyncingNuban = false;
  bool _isRedoMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final u = await AuthService.getCurrentUser();
    if (mounted && u != null) {
      setState(() {
        _currentUser = u;
        _nameController.text = u.fullName;
        _phoneController.text = u.phoneNumber;
        if (u.businessName != null && u.businessName!.isNotEmpty) {
          _businessNameController.text = u.businessName!;
        } else if (u.role == 'partner' && u.fullName.isNotEmpty) {
          _businessNameController.text = u.fullName;
        }
        if (u.cacNumber != null && u.cacNumber!.isNotEmpty) {
          _cacNumberController.text = u.cacNumber!;
        }
        if (u.taxId != null && u.taxId!.isNotEmpty) {
          _tinController.text = u.taxId!;
        }
        if (u.state != null && _nigerianStates.contains(u.state)) {
          _selectedState = u.state!;
        }
        if (u.officeAddress != null && u.officeAddress!.isNotEmpty) {
          _streetController.text = u.officeAddress!;
        }
        if (u.ninNumber != null && u.ninNumber!.isNotEmpty) {
          _idController.text = u.ninNumber!;
        }
        if (u.bvn != null && u.bvn!.isNotEmpty) {
          _bvnController.text = u.bvn!;
        }
        if (u.dob != null && u.dob!.isNotEmpty) {
          _dobController.text = u.dob!.replaceAll('/', '-');
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _cacNumberController.dispose();
    _tinController.dispose();
    _lgaController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _idController.dispose();
    _bvnController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  bool get _isPartner => _currentUser?.role == 'partner';

  String get _idTypeLabel {
    switch (_selectedIdType) {
      case 'nin':
        return 'NIN (National Identity)';
      case 'voters_card':
        return "Voter's Card (VIN)";
      case 'drivers_license':
        return "Driver's License (FRSC)";
      case 'passport':
        return 'International Passport';
      default:
        return 'Identity Document';
    }
  }

  String get _idInputHint {
    switch (_selectedIdType) {
      case 'nin':
        return 'Enter 11-digit Director NIN';
      case 'voters_card':
        return "Enter Director Voter's ID Number";
      case 'drivers_license':
        return "Enter Director Driver's License";
      case 'passport':
        return 'Enter Director Passport Number';
      default:
        return 'Enter ID Number';
    }
  }

  void _nextStep() {
    setState(() => _errorMessage = null);
    if (_isPartner) {
      if (_currentStep == 0) {
        if (_businessNameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your registered Business / Corporate Name.');
          return;
        }
        if (_cacNumberController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your CAC RC or Business Number (BN).');
          return;
        }
        setState(() => _currentStep = 1);
      } else if (_currentStep == 1) {
        if (_streetController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your physical office street address.');
          return;
        }
        if (_cityController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your office city / district.');
          return;
        }
        if (_lgaController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your Local Government Area (LGA).');
          return;
        }
        setState(() => _currentStep = 2);
      } else if (_currentStep == 2) {
        if (_idController.text.trim().length < 6) {
          setState(() => _errorMessage = 'Please enter a valid $_idTypeLabel number.');
          return;
        }
        if (_bvnController.text.trim().length != 11) {
          setState(() => _errorMessage = 'Please enter a valid 11-digit Bank Verification Number (BVN).');
          return;
        }
        if (_dobController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please select your Date of Birth.');
          return;
        }
        setState(() => _currentStep = 3);
      }
    } else {
      if (_currentStep == 0) {
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your full legal name.');
          return;
        }
        if (_phoneController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your mobile phone number.');
          return;
        }
        setState(() => _currentStep = 1);
      } else if (_currentStep == 1) {
        if (_streetController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your residential street address.');
          return;
        }
        if (_cityController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Please enter your city / district.');
          return;
        }
        setState(() => _currentStep = 2);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  void _handleVerify() async {
    final idNum = _idController.text.trim();
    final bvn = _bvnController.text.trim();
    final dob = _dobController.text.trim();
    final bName = _businessNameController.text.trim();
    final cac = _cacNumberController.text.trim();
    final tin = _tinController.text.trim();
    final cleanDob = dob.replaceAll('/', '-');

    if (_isPartner) {
      if (bName.isEmpty || cac.isEmpty) {
        setState(() {
          _currentStep = 0;
          _errorMessage = 'Please complete the business information first.';
        });
        return;
      }
      if (!_certifiedAccurate) {
        setState(() => _errorMessage = 'Please confirm and certify your details before submitting.');
        return;
      }
    }

    if (idNum.isEmpty || idNum.length < 6) {
      setState(() => _errorMessage = 'Please enter a valid $_idTypeLabel number.');
      return;
    }

    if (bvn.isEmpty || bvn.length != 11) {
      setState(() => _errorMessage = 'Please enter a valid 11-digit Bank Verification Number (BVN).');
      return;
    }

    if (dob.isEmpty) {
      setState(() => _errorMessage = 'Please select your Date of Birth.');
      return;
    }

    final fullOffice = '${_streetController.text.trim()}${_landmarkController.text.trim().isNotEmpty ? " (Near ${_landmarkController.text.trim()})" : ""}, ${_cityController.text.trim()}, ${_lgaController.text.trim().isNotEmpty ? "${_lgaController.text.trim()} LGA, " : ""}$_selectedState, Nigeria';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await VerificationService.verifyAndProvision(
      idType: _selectedIdType,
      idNumber: idNum,
      bvn: bvn,
      dob: cleanDob,
      businessName: _isPartner ? bName : null,
      cacNumber: _isPartner ? cac : null,
      officeAddress: fullOffice,
      state: _selectedState,
      city: _cityController.text.trim(),
      lga: _lgaController.text.trim(),
      landmark: _landmarkController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (res['success'] == true && res['user'] != null) {
      var updatedUser = res['user'] as UserProfile;
      if (_isPartner) {
        updatedUser = updatedUser.copyWith(
          businessName: bName,
          cacNumber: cac,
          taxId: tin.isNotEmpty ? tin : updatedUser.taxId,
          officeAddress: fullOffice,
          state: _selectedState,
          isVerified: true,
          bvnVerified: true,
        );
        await AuthService.updateUser(updatedUser);
      }
      widget.onSuccess(updatedUser);

      if (!mounted) return;
      Navigator.of(context).pop();

      _showSuccessDialog(updatedUser);
    } else {
      setState(() {
        final rawMsg = res['message']?.toString() ?? 'Verification could not be completed. Please check your BVN and ID details.';
        if (rawMsg.contains('dob_format') || rawMsg.contains('TierOneCustomerUpgradeRequest.DOB') || rawMsg.toLowerCase().contains('dob')) {
          _errorMessage = 'Invalid Date of Birth format. Please select your Date of Birth in DD-MM-YYYY format (e.g. 27-06-1990).';
        } else if (rawMsg.toLowerCase().contains('could not validate bvn')) {
          _errorMessage = 'Central Banking NIBSS Registry could not validate your 11-digit BVN against your Date of Birth. Please ensure your BVN and Date of Birth match your bank records.';
        } else {
          _errorMessage = rawMsg
              .replaceAll(RegExp(r'Maplerad\s*', caseSensitive: false), 'Rentilly Settlement Rail ')
              .replaceAll(RegExp(r'VBA notice:\s*', caseSensitive: false), '')
              .replaceAll(RegExp(r'USDT notice:\s*', caseSensitive: false), '')
              .trim();
        }
      });
    }
  }

  void _showSuccessDialog(UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                _isPartner ? 'Corporate KYB Verified! 🏢✓' : 'Identity Verified! 🛡️✓',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _isPartner
                    ? '${user.businessName ?? user.fullName} is now accredited. Your dedicated settlement vault is activated.'
                    : 'Your Tier-3 biometric and BVN verification is complete. Settlement account provisioned.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              if (user.accountNumber != null && user.accountNumber!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DEDICATED ESCROW VAULT', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                            Text('${user.accountNumber} • ${user.bankName ?? "Flutterwave MFB"}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF14532D))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Continue', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _selectedDob = DateTime(1994, 8, 14);

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1940),
      lastDate: DateTime(DateTime.now().year - 18, 12, 31),
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  Widget _buildAuditItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedAuditView() {
    final user = _currentUser!;
    final isPartner = user.role == 'partner';
    final bizName = (user.businessName != null && user.businessName!.isNotEmpty)
        ? user.businessName!
        : user.fullName;
    final cac = (user.cacNumber != null && user.cacNumber!.isNotEmpty)
        ? user.cacNumber!
        : 'RC Verified';
    final taxNum = (user.taxId != null && user.taxId!.isNotEmpty)
        ? user.taxId!
        : 'TIN Verified on JTB';
    final office = (user.officeAddress != null && user.officeAddress!.isNotEmpty)
        ? user.officeAddress!
        : '${user.state ?? "Lagos"}, Nigeria';
    final state = user.state ?? 'Lagos';
    final bank = user.bankName ?? '9PSB (Rentilly)';
    final acc = user.accountNumber ?? 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.accountNumber == null || user.accountNumber!.isEmpty || user.accountNumber == 'null' || user.accountNumber!.startsWith('78') || user.dob == null || user.rekycRequired == true) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFB45309), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verification Pending / Incomplete ⚠️',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why was your account not verified?',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.kycFailureReason ?? _errorMessage ?? 'Central Banking NIBSS Registry could not validate your BVN against your Date of Birth. Please ensure your 11-digit BVN and Date of Birth match your bank records.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF78350F), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please re-verify your details or start the KYB/KYC process again to activate your live 9PSB settlement account and Dollar Card.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFB45309), height: 1.3),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isRedoMode = true;
                            _currentStep = 0;
                            if (user.fullName.isNotEmpty) {
                              _businessNameController.text = user.businessName ?? user.fullName;
                            }
                            if (user.cacNumber != null) {
                              _cacNumberController.text = user.cacNumber!;
                            }
                            if (user.ninNumber != null) {
                              _idController.text = user.ninNumber!;
                            }
                            if (user.bvn != null) {
                              _bvnController.text = user.bvn!;
                            }
                          });
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isPartner ? 'Start KYB Again ⚡' : 'Start KYC Again ⚡',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: _syncLiveNuban,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFB45309)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Quick Retry 🎂',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Verified Certificate Header (Contained & Polished)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
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
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF4ADE80)),
                      const SizedBox(width: 6),
                      Text(
                        isPartner ? 'CAC KYB ACCREDITED 🛡️' : 'TIER-3 IDENTITY VERIFIED 🛡️',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: const Color(0xFF4ADE80),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4ADE80)),
                    ),
                    child: Text(
                      'STATUS: VERIFIED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bizName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                'Principal: ${user.fullName} • ${user.email}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Corporate System Identity Audit Details Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuditItem('REGISTERED ENTITY NAME', bizName, Icons.business_rounded),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderDark),
              ),
              _buildAuditItem('CAC REGISTRATION NUMBER', cac, Icons.badge_outlined),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderDark),
              ),
              _buildAuditItem('TAX IDENTIFICATION NUMBER (TIN)', taxNum, Icons.receipt_long_rounded),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderDark),
              ),
              _buildAuditItem('REGISTERED OFFICE ADDRESS', office, Icons.location_on_outlined),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderDark),
              ),
              _buildAuditItem('STATE OF RESIDENCE & OPERATION', '$state State, Nigeria', Icons.map_outlined),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.borderDark),
              ),
              _buildAuditItem('DEDICATED COMMISSIONS ACCOUNT', '$acc ($bank)', Icons.account_balance_rounded),
              if (acc.isEmpty || acc == 'null' || acc.startsWith('78') || bank.contains('Processing') || bank.contains('Pending')) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncingNuban ? null : _syncLiveNuban,
                    icon: _isSyncingNuban
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cake_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSyncingNuban ? 'Activating Dedicated Settlement Account...' : 'Confirm Date of Birth & Activate Account ⚡',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Close / Done Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Redo Full KYC Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isRedoMode = true;
                _currentStep = 0;
                if (_currentUser?.fullName != null) {
                  _businessNameController.text = _currentUser?.businessName ?? _currentUser?.fullName ?? '';
                }
                if (_currentUser?.cacNumber != null) {
                  _cacNumberController.text = _currentUser?.cacNumber ?? '';
                }
                if (_currentUser?.ninNumber != null) {
                  _idController.text = _currentUser?.ninNumber ?? '';
                }
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Redo Full KYC / Re-Verify Details 🔄',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _syncLiveNuban() async {
    final user = _currentUser;
    if (user == null) return;

    // Show date picker if DOB is missing
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );

    if (picked == null) return;

    final formattedDob = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';

    setState(() => _isSyncingNuban = true);
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/verification/complete-maplerad-kyc');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': user.id,
          'email': user.email,
          'fullName': user.fullName,
          'businessName': user.businessName,
          'phoneNumber': user.phoneNumber,
          'dob': formattedDob,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['status'] == true && data['accountNumber'] != null) {
        final updatedUser = user.copyWith(
          accountNumber: data['accountNumber'],
          bankName: data['bankName'] ?? '9PSB (Rentilly)',
          dob: formattedDob,
          rekycRequired: false,
        );
        await AuthService.updateUser(updatedUser);
        widget.onSuccess(updatedUser);
        setState(() {
          _currentUser = updatedUser;
          _isSyncingNuban = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dedicated Rentilly Account Active: ${data['accountNumber']} (${data['bankName'] ?? '9PSB'}) 🎉',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Could not provision live account');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingNuban = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activation notice: $e', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser?.isVerified == true && !_isRedoMode) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildVerifiedAuditView(),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isRedoMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Updating / Redoing KYC Details',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isRedoMode = false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isPartner ? Icons.business_rounded : Icons.verified_user_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPartner ? 'Corporate CAC & Identity Audit (KYB)' : 'Identity & BVN Verification',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        _isPartner ? 'Accredit your corporate firm & activate commission settlements' : 'Tier-3 CBN compliance & dedicated escrow bank account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Stepper Progress Indicator (4 steps for KYB, 3 steps for KYC)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: (_isPartner
                    ? [
                        {'title': 'Corporate', 'idx': 0},
                        {'title': 'Office', 'idx': 1},
                        {'title': 'Director', 'idx': 2},
                        {'title': 'Review', 'idx': 3},
                      ]
                    : [
                        {'title': 'Profile', 'idx': 0},
                        {'title': 'Address', 'idx': 1},
                        {'title': 'Identity', 'idx': 2},
                      ]
                ).map((s) {
                  final idx = s['idx'] as int;
                  final title = s['title'] as String;
                  final totalSteps = _isPartner ? 4 : 3;
                  final isActive = _currentStep == idx;
                  final isCompleted = _currentStep > idx;

                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (idx < _currentStep) {
                                setState(() => _currentStep = idx);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? const Color(0xFF16A34A)
                                        : (isActive ? AppColors.primary : const Color(0xFFE2E8F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: isCompleted
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : Text(
                                            '${idx + 1}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? Colors.white : AppColors.textMuted,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    title,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      color: isActive ? AppColors.primary : (isCompleted ? AppColors.textPrimary : AppColors.textMuted),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (idx < totalSteps - 1)
                          Container(
                            width: 10,
                            height: 1.5,
                            color: const Color(0xFFCBD5E1),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // =================================================================
            // KYB WORKFLOW (4 NON-CLUSTERED STEPS)
            // =================================================================
            if (_isPartner) ...[
              // STEP 0: CORPORATE CAC REGISTRATION
              if (_currentStep == 0) ...[
                Text(
                  'STEP 1 OF 4: CORPORATE CAC PROFILE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _businessNameController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Registered Business / Company Name',
                    hintText: 'e.g. Ehomes Global Inclusive Limited',
                    prefixIcon: const Icon(Icons.business_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cacNumberController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'CAC RC / BN Number',
                          hintText: 'e.g. RC 1928374',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _tinController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Tax ID (TIN)',
                          hintText: 'Optional',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    label: Text('Next: Physical Office Address', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              // STEP 1: PHYSICAL OPERATIONAL OFFICE ADDRESS (COLLATED)
              if (_currentStep == 1) ...[
                Text(
                  'STEP 2 OF 4: PHYSICAL OPERATIONAL OFFICE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  decoration: InputDecoration(
                    labelText: 'Operational State (36 States + FCT)',
                    prefixIcon: const Icon(Icons.map_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _nigerianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 12.5)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedState = val);
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lgaController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'L.G.A (Local Govt Area)',
                          hintText: 'e.g. Eti-Osa / Ikeja',
                          prefixIcon: const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'City / District',
                          hintText: 'e.g. Lekki Phase 1',
                          prefixIcon: const Icon(Icons.location_city_outlined, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _streetController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Physical Street Address & Suite / Building No.',
                    hintText: 'e.g. Plot 14 Admiralty Way, Suite 2B',
                    prefixIcon: const Icon(Icons.signpost_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _landmarkController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Nearest Landmark / Bus Stop (Optional)',
                    hintText: 'e.g. Opposite Ebeano Supermarket',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: Text('Next: Director Identity', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // STEP 2: PRINCIPAL DIRECTOR / BROKER IDENTITY
              if (_currentStep == 2) ...[
                Text(
                  'STEP 3 OF 4: PRINCIPAL DIRECTOR IDENTITY',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedIdType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'nin', child: Text('National Identity Number (NIN)')),
                        DropdownMenuItem(value: 'voters_card', child: Text("Voter's Card (VIN)")),
                        DropdownMenuItem(value: 'drivers_license', child: Text("Driver's License (FRSC)")),
                        DropdownMenuItem(value: 'passport', child: Text('International Passport')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedIdType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: _idTypeLabel,
                    hintText: _idInputHint,
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _bvnController,
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Director BVN (11 digits)',
                          hintText: '22XXXXXXXXX',
                          counterText: '',
                          prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          hintText: 'DD-MM-YYYY',
                          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: Text('Next: Review & Declare', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // STEP 3: COMPLIANCE AUDIT & DECLARATION
              if (_currentStep == 3) ...[
                Text(
                  'STEP 4 OF 4: AUDIT REVIEW & DECLARATION',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAuditItem('Corporate Entity', _businessNameController.text.trim(), Icons.business_rounded),
                      const SizedBox(height: 8),
                      _buildAuditItem('Registration No.', _cacNumberController.text.trim(), Icons.badge_rounded),
                      const SizedBox(height: 8),
                      _buildAuditItem(
                        'Physical Office',
                        '${_streetController.text.trim()}, ${_cityController.text.trim()}, ${_lgaController.text.trim()} LGA, $_selectedState',
                        Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 8),
                      _buildAuditItem('Director Identity', '$_idTypeLabel: ${_idController.text.trim()}', Icons.person_rounded),
                      const SizedBox(height: 8),
                      _buildAuditItem(
                        'Banking / BVN',
                        '*******${_bvnController.text.trim().length >= 4 ? _bvnController.text.trim().substring(_bvnController.text.trim().length - 4) : ''} (DOB: ${_dobController.text.trim()})',
                        Icons.account_balance_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () => setState(() => _certifiedAccurate = !_certifiedAccurate),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _certifiedAccurate,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _certifiedAccurate = v ?? true),
                      ),
                      Expanded(
                        child: Text(
                          'I certify that I am an authorized principal of this entity and that all CAC, address, and BVN records submitted are authentic and match official regulatory databases.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Submit Corporate KYB ⚡',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ]

            // =================================================================
            // STANDARD KYC WORKFLOW (3 NON-CLUSTERED STEPS)
            // =================================================================
            else ...[
              // KYC STEP 0: PERSONAL PROFILE
              if (_currentStep == 0) ...[
                Text(
                  'STEP 1 OF 3: PERSONAL PROFILE',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _nameController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Full Legal Name (as registered with BVN)',
                    hintText: 'e.g. Anthony Chukwuma',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    hintText: 'e.g. 08012345678',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    label: Text('Next: Residential Address', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              // KYC STEP 1: RESIDENTIAL ADDRESS
              if (_currentStep == 1) ...[
                Text(
                  'STEP 2 OF 3: RESIDENTIAL ADDRESS',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  decoration: InputDecoration(
                    labelText: 'State of Residence',
                    prefixIcon: const Icon(Icons.map_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _nigerianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 12.5)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedState = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _cityController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'City / District',
                    hintText: 'e.g. Ikeja / Yaba',
                    prefixIcon: const Icon(Icons.location_city_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _streetController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Residential Street Address',
                    hintText: 'e.g. 24 Allen Avenue, Flat 4',
                    prefixIcon: const Icon(Icons.signpost_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _landmarkController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Nearest Landmark (Optional)',
                    hintText: 'e.g. Near Ikeja City Mall',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: Text('Next: Identity Verification', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // KYC STEP 2: IDENTITY & BANKING VERIFICATION
              if (_currentStep == 2) ...[
                Text(
                  'STEP 3 OF 3: IDENTITY & BVN VALIDATION',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedIdType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'nin', child: Text('National Identity Number (NIN)')),
                        DropdownMenuItem(value: 'voters_card', child: Text("Voter's Card (VIN)")),
                        DropdownMenuItem(value: 'drivers_license', child: Text("Driver's License (FRSC)")),
                        DropdownMenuItem(value: 'passport', child: Text('International Passport')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedIdType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.text,
                  maxLength: _selectedIdType == 'nin' ? 11 : 20,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: _idTypeLabel,
                    hintText: _idInputHint,
                    helperText: _selectedIdType == 'nin' ? 'NIN ≠ BVN. Check NIMC app or dial *346#' : null,
                    helperStyle: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted),
                    counterText: '',
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),


                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _bvnController,
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: '11-digit BVN',
                          hintText: 'Bank Verification No.',
                          helperText: 'From your bank app or USSD *565*0#',
                          helperStyle: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted),
                          counterText: '',
                          prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.textMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          hintText: 'DD-MM-YYYY',
                          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Back', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Verify & Provision Account ⚡',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
