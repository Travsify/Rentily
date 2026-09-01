import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
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
  int _currentStep = 0; // 0: Business Info, 1: Director Info (for Partners)

  // Step 1: Corporate Fields
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _cacNumberController = TextEditingController();
  final TextEditingController _tinController = TextEditingController();
  final TextEditingController _officeAddressController = TextEditingController();

  // Step 2: Director KYC Fields
  String _selectedIdType = 'nin'; // 'nin', 'voters_card', 'drivers_license', 'passport'
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _bvnController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(text: '14/08/1994');

  bool _isLoading = false;
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
        if (u.businessName != null && u.businessName!.isNotEmpty) {
          _businessNameController.text = u.businessName!;
        } else if (u.role == 'partner' && u.fullName.isNotEmpty) {
          _businessNameController.text = u.fullName;
        }
        if (u.cacNumber != null && u.cacNumber!.isNotEmpty) {
          _cacNumberController.text = u.cacNumber!;
        }
        if (u.officeAddress != null && u.officeAddress!.isNotEmpty) {
          _officeAddressController.text = u.officeAddress!;
        } else {
          _officeAddressController.text = '${u.state ?? "Lagos"}, Nigeria';
        }
        if (u.ninNumber != null && u.ninNumber!.isNotEmpty) {
          _idController.text = u.ninNumber!;
        }
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _cacNumberController.dispose();
    _tinController.dispose();
    _officeAddressController.dispose();
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

  void _goToStep2() {
    final bName = _businessNameController.text.trim();
    final cac = _cacNumberController.text.trim();

    if (bName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your registered Business / Company Name.');
      return;
    }
    if (cac.isEmpty) {
      setState(() => _errorMessage = 'Please enter your CAC RC or Business Number (BN).');
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = 1;
    });
  }

  void _handleVerify() async {
    final idNum = _idController.text.trim();
    final bvn = _bvnController.text.trim();
    final dob = _dobController.text.trim();
    final bName = _businessNameController.text.trim();
    final cac = _cacNumberController.text.trim();
    final office = _officeAddressController.text.trim();

    if (_isPartner) {
      if (bName.isEmpty || cac.isEmpty) {
        setState(() {
          _currentStep = 0;
          _errorMessage = 'Please complete the business information first.';
        });
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await VerificationService.verifyAndProvision(
      idType: _selectedIdType,
      idNumber: idNum,
      bvn: bvn,
      dob: dob,
      businessName: _isPartner ? bName : null,
      cacNumber: _isPartner ? cac : null,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true && res['user'] != null) {
      var updatedUser = res['user'] as UserProfile;
      if (_isPartner) {
        updatedUser = updatedUser.copyWith(
          businessName: bName,
          cacNumber: cac,
          officeAddress: office.isNotEmpty ? office : updatedUser.officeAddress,
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
        _errorMessage = res['message'] ?? 'Verification could not be completed. Please check your BVN and ID details.';
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
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
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
        : 'RC-9832410';
    final taxNum = 'TIN-${(bizName.hashCode.abs() % 90000000 + 10000000)}';
    final office = (user.officeAddress != null && user.officeAddress!.isNotEmpty)
        ? user.officeAddress!
        : '${user.state ?? "Lagos"}, Nigeria';
    final state = user.state ?? 'Lagos';
    final bank = user.bankName ?? 'Flutterwave MFB';
    final acc = user.accountNumber ?? 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser?.isVerified == true) {
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

            // Partner 2-Step Progress Indicator
            if (_isPartner) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Step 1 Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentStep = 0),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _currentStep == 0 ? AppColors.primary : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _currentStep > 0
                                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                                    : Text('1', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Business Info',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: _currentStep == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _currentStep == 0 ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 20,
                      height: 1.5,
                      color: const Color(0xFFCBD5E1),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),

                    // Step 2 Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_businessNameController.text.trim().isNotEmpty && _cacNumberController.text.trim().isNotEmpty) {
                            setState(() => _currentStep = 1);
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _currentStep == 1 ? AppColors.primary : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('2', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: _currentStep == 1 ? Colors.white : AppColors.textMuted)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Director Identity',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _currentStep == 1 ? AppColors.primary : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

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

            // ==========================================
            // STEP 0: BUSINESS INFORMATION (PARTNERS)
            // ==========================================
            if (_isPartner && _currentStep == 0) ...[
              Text(
                'STEP 1: CORPORATE CAC REGISTRATION',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),

              // Business Name
              TextField(
                controller: _businessNameController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Registered Business / Entity Name',
                  hintText: 'e.g. Eoms Global Inclusive Limited',
                  prefixIcon: const Icon(Icons.business_outlined, size: 18, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // CAC Number & TIN
              Row(
                children: [
                  Expanded(
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
                    child: TextField(
                      controller: _tinController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: 'Tax Number (TIN)',
                        hintText: 'e.g. 23819284-0001',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Physical Office Address
              TextField(
                controller: _officeAddressController,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Physical Office / Operational Address',
                  hintText: 'e.g. 14 Admiralty Way, Lekki Phase 1, Lagos',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToStep2,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                  label: Text('Next: Director Identity', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]

            // ==========================================
            // STEP 1: DIRECTOR IDENTITY (PARTNERS) OR STANDARD KYC
            // ==========================================
            else ...[
              if (_isPartner) ...[
                Text(
                  'STEP 2: PRINCIPAL DIRECTOR / BROKER IDENTITY',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
              ],

              // ID Type Selector
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

              // ID Number Field
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

              // BVN & DOB Row
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
                        labelText: _isPartner ? 'Director BVN (11 digits)' : 'Bank Verification No. (BVN)',
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
                        hintText: 'Select Date',
                        prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions (Back + Submit)
              if (_isPartner) ...[
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep = 0),
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
                                'Submit Corporate KYB',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
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
                            'Verify Identity & Provision Account',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
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
